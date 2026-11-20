-- :CsRegister — thêm dòng đăng ký cho class trong buffer hiện tại vào file tổng hợp của module:
--   endpoint (có MapEndpoint)          → `X.MapEndpoint(app);` trong *Endpoints.cs cùng thư mục
--                                          + `const string X = "X";` trong Tags.cs nếu chưa có
--   file gom (có MapEndpoints)          → `XEndpoints.MapEndpoints(app);` trong *Module.cs
--   repository (XRepository : IXRepository) → `services.AddScoped<IXRepository, XRepository>();` trong *Module.cs
--                                          + `DbSet<X>` trong DbContext
--   EF configuration (IEntityTypeConfiguration<X>) → `DbSet<X>` trong DbContext
-- Dòng đã có thì bỏ qua; thêm `using` khi khác namespace. File đích được mở, sửa và lưu.
local S = require("core.csharp-source")

local M = {}

local function lines_of(file)
	local buf = vim.fn.bufadd(file)
	vim.fn.bufload(buf)
	return buf, vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

local function last_index(lines, pattern)
	local found
	for index, line in ipairs(lines) do
		if line:match(pattern) then
			found = index
		end
	end
	return found
end

local function contains(lines, text)
	for _, line in ipairs(lines) do
		if line:find(text, 1, true) then
			return true
		end
	end
	return false
end

local function namespace_of(lines)
	for _, line in ipairs(lines) do
		local namespace = line:match("^%s*namespace%s+([%w_.]+)")
		if namespace then
			return namespace
		end
	end
end

-- Thêm `using ns;` theo thứ tự chữ cái (System.* trước); trả số dòng đã chèn
function M.ensure_using(buf, namespace)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local current = namespace_of(lines)
	if not namespace or namespace == current or (current and vim.startswith(current, namespace .. ".")) then
		return 0
	end
	local wanted = "using " .. namespace .. ";"
	local function key(name)
		return (name:match("^System") and "0" or "1") .. name
	end
	local at, last
	for index, line in ipairs(lines) do
		-- Bỏ BOM ở dòng đầu khi so sánh
		local used = line:gsub("^\239\187\191", ""):match("^using%s+([%w_.]+)%s*;")
		if used then
			if used == namespace then
				return 0
			end
			last = index
			if not at and key(used) > key(namespace) then
				at = index
			end
		end
	end
	if at then
		-- Giữ BOM ở dòng đầu file
		local bom = lines[at]:match("^\239\187\191") or ""
		if bom ~= "" then
			vim.api.nvim_buf_set_lines(buf, at - 1, at, false, { bom .. wanted, lines[at]:sub(4) })
		else
			vim.api.nvim_buf_set_lines(buf, at - 1, at - 1, false, { wanted })
		end
	elseif last then
		vim.api.nvim_buf_set_lines(buf, last, last, false, { wanted })
	else
		vim.api.nvim_buf_set_lines(buf, 0, 0, false, { wanted, "" })
		return 2
	end
	return 1
end

local function save(buf)
	vim.api.nvim_buf_call(buf, function()
		vim.cmd("silent noautocmd write")
	end)
end

local function short(file)
	return vim.fn.fnamemodify(file, ":~:.")
end

-- Chèn `text` sau dòng cuối khớp `after`; nếu không có thì trước `}` đóng của block chứa dòng khớp `block`
local function insert(file, text, after, block, namespaces)
	local buf, lines = lines_of(file)
	if contains(lines, vim.trim(text)) then
		return ("đã có trong %s"):format(short(file))
	end
	local row = last_index(lines, after)
	local pad
	if row then
		pad = lines[row]:match("^%s*")
	else
		local start = block and last_index(lines, block)
		if not start then
			return nil, ("không tìm thấy chỗ chèn trong %s"):format(short(file))
		end
		-- Tìm `{` mở của block rồi `}` khớp với nó
		local depth, close = 0, nil
		for index = start, #lines do
			for ch in lines[index]:gmatch("[{}]") do
				depth = depth + (ch == "{" and 1 or -1)
				if depth == 0 and ch == "}" then
					close = index
					break
				end
			end
			if close then
				break
			end
		end
		if not close then
			return nil, ("block không đóng trong %s"):format(short(file))
		end
		pad = lines[close]:match("^%s*") .. "    "
		row = close - 1
	end
	vim.api.nvim_buf_set_lines(buf, row, row, false, { pad .. vim.trim(text) })
	for _, namespace in ipairs(namespaces or {}) do
		M.ensure_using(buf, namespace)
	end
	save(buf)
	return ("đã thêm vào %s"):format(short(file))
end

local function module_file(pattern)
	return S.rg_first(pattern, S.module_dir())
end

local function register_dbset(entity, entity_namespace)
	local context = module_file("DbSet<")
	if not context then
		return nil, "không tìm thấy DbContext có DbSet<> trong module"
	end
	local _, lines = lines_of(context)
	local row = last_index(lines, "DbSet<")
	local modifier = row and lines[row]:match("^%s*(.-)%s*DbSet<") or "public"
	local text = ("%s DbSet<%s> %s { get; set; }"):format(modifier, entity, S.plural(entity))
	if contains(lines, ("DbSet<%s>"):format(entity)) then
		return ("DbSet<%s> đã có trong %s"):format(entity, short(context))
	end
	return insert(context, text, "DbSet<", nil, { entity_namespace })
end

local function run()
	S.reset_cache()
	local buf_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local source = table.concat(buf_lines, "\n")
	local namespace = namespace_of(buf_lines)
	local results = {}
	local function report(message, err)
		table.insert(results, message or err)
	end

	local endpoint = source:match("class%s+([%w_]+)[^{]*{.-MapEndpoint%s*%(%s*IEndpointRouteBuilder")
	local aggregate = source:match("class%s+([%w_]+)[^{]*{.-MapEndpoints%s*%(%s*IEndpointRouteBuilder")
	local repository, interface = source:match("class%s+([%w_]+Repository)%s*%b()%s*:%s*(I[%w_]+Repository)")
	if not repository then
		repository, interface = source:match("class%s+([%w_]+Repository)%s*:%s*(I[%w_]+Repository)")
	end
	local configured = source:match("IEntityTypeConfiguration%s*<%s*([%w_]+)%s*>")

	if aggregate then
		-- XxxEndpoints.MapEndpoints(app) trong file *Module.cs (file gọi các *Endpoints.MapEndpoints)
		local target = module_file("Endpoints\\.MapEndpoints\\s*\\(\\s*app")
		if target == vim.api.nvim_buf_get_name(0) then
			report(nil, "đây là file gọi các *Endpoints, không có gì để đăng ký")
		elseif not target then
			report(nil, "không tìm thấy file gọi *Endpoints.MapEndpoints(app)")
		else
			report(
				insert(target, aggregate .. ".MapEndpoints(app);", "Endpoints%.MapEndpoints%(app%)", nil, { namespace })
			)
		end
	elseif endpoint then
		-- *Endpoints.cs cùng thư mục (trừ chính nó), nếu không có thì tìm trong module
		local file = vim.api.nvim_buf_get_name(0)
		local dir = vim.fs.dirname(file)
		local target
		for _, candidate in ipairs(S.rg_files("MapEndpoints\\s*\\(", dir)) do
			if not target and vim.fs.dirname(candidate) == dir then
				target = candidate
			end
		end
		if not target then
			report(nil, "thư mục chưa có file *Endpoints.cs (tạo file rồi gõ snippet publicendpoints)")
		else
			report(insert(target, endpoint .. ".MapEndpoint(app);", "%.MapEndpoint%(app%)", "MapEndpoints%s*%(", {
				namespace,
			}))
		end
		-- Hằng Tags.<Thư mục> mà endpoint dùng trong .WithTags(...)
		local tag = source:match("WithTags%(%s*Tags%.([%w_]+)%s*%)")
		local tags_file = tag and module_file("class\\s+Tags\\b")
		if tags_file then
			local _, tag_lines = lines_of(tags_file)
			if last_index(tag_lines, "const%s+string%s+" .. tag .. "%s*=") then
				report(("Tags.%s đã có"):format(tag))
			else
				report(
					insert(tags_file, ('internal const string %s = "%s";'):format(tag, tag), "const string", nil, {})
				)
			end
		end
	elseif repository then
		local target = module_file("AddScoped<I\\w+Repository")
		if not target then
			report(nil, "không tìm thấy file đăng ký repository (AddScoped<I...Repository>)")
		else
			local interface_info = S.find_type(interface)
			report(
				insert(
					target,
					("services.AddScoped<%s, %s>();"):format(interface, repository),
					"AddScoped<I[%w_]+Repository",
					nil,
					{ interface_info and interface_info.namespace, namespace }
				)
			)
		end
		local entity = repository:gsub("Repository$", "")
		local entity_info = S.find_type(entity)
		if entity_info then
			report(register_dbset(entity, entity_info.namespace))
		end
	elseif configured then
		local entity_info = S.find_type(configured)
		report(register_dbset(configured, entity_info and entity_info.namespace))
	else
		report(nil, "buffer không phải endpoint, file *Endpoints, repository hay EF configuration")
	end

	vim.notify("CsRegister: " .. table.concat(results, "; "))
end

vim.api.nvim_create_user_command("CsRegister", run, {
	desc = "Register current endpoint/endpoints/repository/EF configuration in the module's Endpoints, Tags, Module and DbContext",
})

return M
