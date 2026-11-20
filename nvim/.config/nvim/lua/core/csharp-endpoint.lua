-- Sinh endpoint Minimal API (MapEndpoint + Request) từ record <TênFile>Command / <TênFile>Query.
-- Dùng bởi snippet `internalendpoint` trong lua/snippets/cs.lua.
local S = require("core.csharp-source")

local M = {}

local function repo_root()
	return vim.fs.root(0, ".git") or vim.fn.getcwd()
end

local function rg_first(pattern, path)
	local found = vim.system({ "rg", "-l", "--glob", "*.cs", pattern, path }):wait()
	local file = vim.split(vim.trim(found.stdout or ""), "\n")[1]
	return file ~= "" and file or nil
end

local function namespace_of(root, src)
	for node in root:iter_children() do
		local kind = node:type()
		if kind == "file_scoped_namespace_declaration" or kind == "namespace_declaration" then
			return vim.treesitter.get_node_text(node:field("name")[1], src)
		end
	end
end

-- Đọc record bằng Tree-sitter: namespace, tham số primary constructor, base list
local function read_record(name)
	local file = rg_first("record\\s+" .. name .. "(Command|Query)\\b", repo_root())
	if not file then
		return nil
	end
	local src = table.concat(vim.fn.readfile(file), "\n")
	local ok, parser = pcall(vim.treesitter.get_string_parser, src, "c_sharp")
	if not ok then
		return nil
	end
	local root = parser:parse()[1]:root()
	local query = vim.treesitter.query.parse("c_sharp", "(record_declaration) @record")
	for _, node in query:iter_captures(root, src) do
		local record = vim.treesitter.get_node_text(node:field("name")[1], src)
		if record == name .. "Command" or record == name .. "Query" then
			local info = { record = record, namespace = namespace_of(root, src), params = {}, base = "" }
			for child in node:iter_children() do
				if child:type() == "parameter_list" then
					for param in child:iter_children() do
						if param:type() == "parameter" then
							table.insert(info.params, {
								type = vim.treesitter.get_node_text(param:field("type")[1], src),
								name = vim.treesitter.get_node_text(param:field("name")[1], src),
							})
						end
					end
				elseif child:type() == "base_list" then
					info.base = vim.treesitter.get_node_text(child, src)
				end
			end
			return info
		end
	end
end

local function namespace_of_class(class, path)
	local file = rg_first("class\\s+" .. class .. "\\b", path)
	if not file then
		return nil
	end
	return table.concat(vim.fn.readfile(file), "\n"):match("namespace%s+([%w_.]+)")
end

local verbs = {
	{ "^Create", "Post" },
	{ "^Add", "Post" },
	{ "^Register", "Post" },
	{ "^Get", "Get" },
	{ "^List", "Get" },
	{ "^Search", "Get" },
	{ "^Update", "Put" },
	{ "^Change", "Put" },
	{ "^Rename", "Put" },
	{ "^Delete", "Delete" },
	{ "^Remove", "Delete" },
}

local page_defaults = { Page = "1", PageSize = "20" }

-- IReadOnlyDictionary<K, V> → Dictionary<K, V>? (truyền `?? []`), giống Request của CreateAsset
local function request_type(type)
	local dict = type:match("^IReadOnlyDictionary(%b<>)$")
	if dict then
		return "Dictionary" .. dict .. "?", true
	end
	local list = type:match("^IReadOnlyList(%b<>)$")
		or type:match("^IReadOnlyCollection(%b<>)$")
		or type:match("^IEnumerable(%b<>)$")
	if list then
		return "List" .. list .. "?", true
	end
	return type, false
end

-- Trả về danh sách phần {text} hoặc {insert = n, default}
function M.parts(class, namespace)
	local file = vim.api.nvim_buf_get_name(0)
	local module = file:match("/Modules/([%w_]+)/")
	local info = read_record(class)
	local verb = "Post"
	for _, rule in ipairs(verbs) do
		if class:match(rule[1]) then
			verb = rule[2]
			break
		end
	end

	local params = info and info.params or {}
	-- Tham số đầu `<X>Id` của command/query → route `{id:guid}`, kể cả POST
	-- (AddCustomField(FieldSetId, ...) → POST field-sets/{id:guid}/...)
	local constraints = { Guid = "guid", int = "int", long = "long" }
	local first = params[1]
	local route_id = first and constraints[first.type] and first.name:match("Id$") and first
	-- Gốc route theo thư mục chứa file: Presentation/AssetModels/X.cs → asset-models
	local folder = vim.fs.basename(vim.fs.dirname(file))
	if folder:match("%.Presentation$") or folder == "" then
		folder = module or "resource"
	end
	local route = S.snake_case(folder):gsub("_", "-")
		.. (route_id and ("/{id:%s}"):format(constraints[route_id.type]) or "/")

	local result_type, ok_result = "Result", "Results.NoContent"
	local generic = info and (info.base:match("ICommand(%b<>)") or info.base:match("IQuery(%b<>)"))
	if generic then
		result_type, ok_result = "Result" .. generic, "Results.Ok"
	end

	-- Tham số lambda, thuộc tính Request, đối số truyền vào command
	local lambda, props, args, type_namespaces = {}, {}, {}, {}
	-- Page/PageSize của query phân trang: tham số có giá trị mặc định, phải đứng cuối lambda
	local optional = {}
	if route_id then
		table.insert(lambda, route_id.type .. " id")
	end
	for index, param in ipairs(params) do
		if index == 1 and route_id then
			table.insert(args, "id")
		elseif verb == "Get" then
			-- Query string: ?state=...&assetModelId=...
			local name = S.camel(param.name)
			local default = param.type == "int" and page_defaults[param.name]
			if default then
				table.insert(optional, ("%s %s = %s"):format(param.type, name, default))
			else
				table.insert(lambda, param.type .. " " .. name)
			end
			table.insert(args, name)
		else
			local type, collection = request_type(param.type)
			table.insert(props, ("        public %s %s { get; init; }"):format(type, param.name))
			table.insert(args, "request." .. param.name .. (collection and " ?? []" or ""))
			-- Kiểu riêng của project trong Request (enum, value object) cần using
			for name in type:gmatch("[%a_][%w_]*") do
				local found = name:match("^%u") and S.find_type(name)
				if found then
					table.insert(type_namespaces, found.namespace or false)
				end
			end
		end
	end
	if #props > 0 then
		table.insert(lambda, "Request request")
	end
	table.insert(lambda, "ISender sender")
	vim.list_extend(lambda, optional)

	local presentation = vim.fs.dirname(vim.fs.find(function(name)
		return name:match("%.csproj$")
	end, { upward = true, path = vim.fs.dirname(file) })[1] or file)

	local namespaces = {
		info and info.namespace or false,
		namespace_of_class("ApiResults", presentation) or false,
		namespace_of_class("Result", repo_root()) or false,
		"MediatR",
		"Microsoft.AspNetCore.Builder",
		"Microsoft.AspNetCore.Http",
		"Microsoft.AspNetCore.Routing",
	}
	vim.list_extend(namespaces, type_namespaces)
	local usings = S.usings(namespaces, namespace)

	local send
	local record = info and info.record or (class .. "Command")
	if #args <= 1 then
		send = ("await sender.Send(new %s(%s));"):format(record, args[1] or "")
	else
		send = ("await sender.Send(\n                        new %s(\n                            %s\n                        )\n                    );"):format(
			record,
			table.concat(args, ",\n                            ")
		)
	end

	local head = table.concat(usings, "\n")
		.. (#usings > 0 and "\n\n" or "")
		.. ("namespace %s;\n\ninternal static class %s\n{\n"):format(namespace, class)
		.. "    public static void MapEndpoint(IEndpointRouteBuilder app)\n    {\n        app.Map"
	local body = ('",\n                async (%s) =>\n                {\n                    %s result = %s\n\n'):format(
		table.concat(lambda, ", "),
		result_type,
		send
	) .. ("                    return result.Match(%s, ApiResults.ApiResults.Problem);\n"):format(ok_result)
	body = body .. "                }\n            )\n            .WithTags(Tags." .. S.pascal(folder) .. ");\n    }\n"
	if #props > 0 then
		body = body .. "\n    internal sealed class Request\n    {\n" .. table.concat(props, "\n") .. "\n    }\n"
	end
	body = body .. "}"

	-- Nhảy: (1) ngay sau route để gõ tiếp đường dẫn → (2) verb
	return {
		{ text = head },
		{ insert = 2, default = verb },
		{ text = '(\n                "' .. route },
		{ insert = 1, default = "" },
		{ text = body },
	}
end

-- Các class endpoint (có MapEndpoint(IEndpointRouteBuilder)) trong thư mục, theo thứ tự chữ cái
function M.endpoints_in(dir, except)
	local out = {}
	for name, kind in vim.fs.dir(dir) do
		if kind == "file" and name:match("%.cs$") and name ~= except then
			local source = table.concat(vim.fn.readfile(dir .. "/" .. name), "\n")
			local class = source:match("class%s+([%w_]+)[^{]*{.-MapEndpoint%s*%(%s*IEndpointRouteBuilder")
			if class then
				table.insert(out, class)
			end
		end
	end
	table.sort(out)
	return out
end

-- File gom endpoint của thư mục: AssetModels/AssetModelEndpoints.cs → MapEndpoints gọi từng X.MapEndpoint(app)
function M.aggregate(class, namespace)
	local file = vim.api.nvim_buf_get_name(0)
	local endpoints = M.endpoints_in(vim.fs.dirname(file), vim.fs.basename(file))
	local calls = {}
	for _, endpoint in ipairs(endpoints) do
		table.insert(calls, ("        %s.MapEndpoint(app);"):format(endpoint))
	end
	if #calls == 0 then
		calls = { "        " .. S.ph() }
	end
	return table.concat({
		"using Microsoft.AspNetCore.Routing;",
		"",
		("namespace %s;"):format(namespace),
		"",
		("public static class %s"):format(class),
		"{",
		"    public static void MapEndpoints(IEndpointRouteBuilder app)",
		"    {",
		table.concat(calls, "\n"),
		"    }",
		"}",
	}, "\n")
end

return M
