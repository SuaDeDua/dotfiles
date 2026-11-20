-- Đọc mã nguồn C# trong repo (rg tìm file, Tree-sitter đọc khai báo) cho các snippet/lệnh sinh code:
-- csharp-endpoint, csharp-scaffold, csharp-register, sql-format.
local M = {}

-- Cache theo từng lần sinh code; gọi reset_cache() ở đầu mỗi generator
local cache = {}

function M.reset_cache()
	cache = {}
end

local function cached(key, compute)
	if cache[key] == nil then
		cache[key] = { compute() }
	end
	return unpack(cache[key])
end

function M.repo_root()
	return vim.fs.root(0, ".git") or vim.fn.getcwd()
end

-- src/Modules/<Module> của buffer hiện tại; file cùng module được ưu tiên khi tìm kiếm
function M.module_dir()
	return vim.api.nvim_buf_get_name(0):match("^(.*/Modules/[%w_]+)/")
end

function M.module_name()
	return vim.api.nvim_buf_get_name(0):match("/Modules/([%w_]+)/")
end

function M.rg_files(pattern, path)
	local found = vim.system({ "rg", "-l", "--glob", "*.cs", pattern, path or M.repo_root() }):wait()
	local files = vim.split(vim.trim(found.stdout or ""), "\n", { trimempty = true })
	local module = M.module_dir()
	-- rg trả file theo thứ tự không cố định: sắp lại, file cùng module lên trước
	table.sort(files, function(a, b)
		local am = module ~= nil and vim.startswith(a, module .. "/")
		local bm = module ~= nil and vim.startswith(b, module .. "/")
		if am ~= bm then
			return am
		end
		return a < b
	end)
	return files
end

function M.rg_first(pattern, path)
	return M.rg_files(pattern, path)[1]
end

function M.parse_file(file)
	local src = table.concat(vim.fn.readfile(file), "\n")
	local ok, parser = pcall(vim.treesitter.get_string_parser, src, "c_sharp")
	if not ok then
		return nil
	end
	return parser:parse()[1]:root(), src
end

function M.text(node, src)
	return node and vim.treesitter.get_node_text(node, src) or nil
end

function M.find_all(node, predicate, out)
	out = out or {}
	if predicate(node) then
		table.insert(out, node)
	end
	for child in node:iter_children() do
		M.find_all(child, predicate, out)
	end
	return out
end

function M.find_node(node, predicate)
	return M.find_all(node, predicate)[1]
end

function M.ancestor(node, kinds)
	node = node:parent()
	while node and not kinds[node:type()] do
		node = node:parent()
	end
	return node
end

function M.namespace(root, src)
	for node in root:iter_children() do
		local kind = node:type()
		if kind == "file_scoped_namespace_declaration" or kind == "namespace_declaration" then
			return M.text(node:field("name")[1], src)
		end
	end
end

M.type_kinds = {
	class_declaration = true,
	record_declaration = true,
	struct_declaration = true,
	interface_declaration = true,
	enum_declaration = true,
}

-- Khai báo kiểu theo tên: { node, src, file, kind, name, namespace }
function M.find_type(name, path)
	if not name or not name:match("^[%a_][%w_]*$") then
		return nil
	end
	return cached("type:" .. name .. ":" .. (path or ""), function()
		return M.find_type_uncached(name, path)
	end)
end

function M.find_type_uncached(name, path)
	local files = M.rg_files(("\\b(class|record|struct|interface|enum)\\s+%s\\b"):format(name), path)
	for index = 1, math.min(#files, 5) do
		local root, src = M.parse_file(files[index])
		if root then
			local node = M.find_node(root, function(n)
				return M.type_kinds[n:type()] and M.text(n:field("name")[1], src) == name
			end)
			if node then
				return {
					node = node,
					src = src,
					file = files[index],
					kind = node:type(),
					name = name,
					namespace = M.namespace(root, src),
				}
			end
		end
	end
end

function M.parameters(list, src)
	local out = {}
	for param in list:iter_children() do
		if param:type() == "parameter" then
			table.insert(out, {
				type = M.text(param:field("type")[1], src) or "object",
				name = M.text(param:field("name")[1], src),
			})
		end
	end
	return out
end

-- Tham số primary constructor của record/class
function M.primary_parameters(info)
	for child in info.node:iter_children() do
		if child:type() == "parameter_list" then
			return M.parameters(child, info.src)
		end
	end
	return {}
end

function M.base_list(info)
	for child in info.node:iter_children() do
		if child:type() == "base_list" then
			return M.text(child, info.src)
		end
	end
	return ""
end

-- AggregateRoot<Guid> / Entity<Guid> → Guid
function M.id_type(info)
	local base = M.base_list(info)
	return base:match("AggregateRoot%s*<%s*([%w_.]+)%s*>") or base:match("Entity%s*<%s*([%w_.]+)%s*>")
end

-- Property, field và tham số primary constructor: tên → kiểu
function M.members(info)
	if not info then
		return {}
	end
	return cached("members:" .. info.file .. ":" .. info.name, function()
		return M.members_uncached(info)
	end)
end

function M.members_uncached(info)
	local members = {}
	for _, param in ipairs(M.primary_parameters(info)) do
		members[param.name] = param.type
	end
	local body = info.node:field("body")[1]
	if not body then
		return members
	end
	for member in body:iter_children() do
		if member:type() == "property_declaration" then
			members[M.text(member:field("name")[1], info.src)] = M.text(member:field("type")[1], info.src)
		elseif member:type() == "field_declaration" then
			for declaration in member:iter_children() do
				if declaration:type() == "variable_declaration" then
					local type = M.text(declaration:field("type")[1], info.src)
					for declarator in declaration:iter_children() do
						if declarator:type() == "variable_declarator" then
							members[M.text(declarator:field("name")[1], info.src)] = type
						end
					end
				end
			end
		end
	end
	if not members.Id then
		members.Id = M.id_type(info)
	end
	return members
end

-- Property có thể gán (primary constructor, `init`, `set`) theo thứ tự khai báo: { name, type }
function M.settable_properties(info)
	local out = M.primary_parameters(info)
	local body = info.node:field("body")[1]
	if not body then
		return out
	end
	for member in body:iter_children() do
		if member:type() == "property_declaration" then
			local accessors = M.text(member:field("accessors")[1], info.src) or ""
			if accessors:match("init") or accessors:match("set") then
				table.insert(out, {
					name = M.text(member:field("name")[1], info.src),
					type = M.text(member:field("type")[1], info.src),
				})
			end
		end
	end
	return out
end

-- Method: { name, returns, params, static, public }
function M.methods(info)
	local out = {}
	if not info then
		return out
	end
	local body = info.node:field("body")[1]
	if not body then
		return out
	end
	for member in body:iter_children() do
		if member:type() == "method_declaration" then
			local method = {
				name = M.text(member:field("name")[1], info.src),
				returns = M.text(member:field("returns")[1], info.src),
				params = M.parameters(member:field("parameters")[1], info.src),
			}
			for child in member:iter_children() do
				local modifier = child:type() == "modifier" and M.text(child, info.src)
				if modifier == "static" then
					method.static = true
				elseif modifier == "public" or modifier == "internal" then
					method.public = true
				end
			end
			table.insert(out, method)
		end
	end
	return out
end

-- string? → string, true
function M.strip_nullable(type)
	if type and type:sub(-1) == "?" then
		return type:sub(1, -2), true
	end
	return type, false
end

-- Result<Asset> → Asset
function M.generic_argument(type, name)
	return type and type:match("^" .. name .. "%s*<%s*(.-)%s*>$")
end

function M.camel(name)
	return (name:gsub("^%u", string.lower))
end

function M.pascal(name)
	return (name:gsub("^%l", string.upper))
end

function M.words(name)
	local words = {}
	for word in name:gmatch("%u[%l%d]*") do
		table.insert(words, word)
	end
	return words
end

function M.snake_case(name)
	return (name:gsub("(%u)(%u%l)", "%1_%2"):gsub("([%l%d])(%u)", "%1_%2"):lower())
end

-- Category → categories, Asset → assets, Status → statuses
function M.plural(word)
	if word:match("[^aeiouAEIOU]y$") then
		return word:sub(1, -2) .. "ies"
	elseif word:match("s$") or word:match("x$") or word:match("ch$") or word:match("sh$") then
		return word .. "es"
	end
	return word .. "s"
end

-- Categories → Category, Assets → Asset, Statuses → Status
function M.singular(word)
	if word:match("ies$") then
		return word:sub(1, -4) .. "y"
	elseif word:match("[sx]es$") or word:match("[cs]hes$") then
		return word:sub(1, -3)
	elseif word:match("[^s]s$") then
		return word:sub(1, -2)
	end
	return word
end

-- AssetModel → am
function M.initials(name)
	return (name:gsub("[^%u]", ""):lower())
end

-- EF Core configuration của entity:
-- { file, table, max = {Prop = expr}, unique = {{Prop, ...}}, column_of = {Prop = col}, jsonb = {col = true} }
function M.configuration(entity)
	if not entity then
		return nil
	end
	return cached("config:" .. entity, function()
		return M.configuration_uncached(entity)
	end)
end

function M.configuration_uncached(entity)
	local file = M.rg_first("IEntityTypeConfiguration<\\s*" .. entity .. "\\s*>")
	if not file then
		return nil
	end
	local src = table.concat(vim.fn.readfile(file), "\n")
	local config = {
		file = file,
		max = {},
		unique = {},
		column_of = {},
		jsonb = {},
		table = src:match('ToTable%(%s*"([^"]+)"'),
	}
	-- Mỗi câu lệnh builder kết thúc bằng `;`, kể cả khi xuống dòng giữa chừng
	for statement in src:gmatch("[^;]+") do
		local property = statement:match("%.Property%(%s*[%w_]+%s*=>%s*[%w_]+%.([%w_]+)%s*%)")
		local max = statement:match("%.HasMaxLength(%b())")
		if property and max then
			config.max[property] = vim.trim(max:sub(2, -2))
		end
		-- Property(x => x.Prop) hoặc Property<T>("_field") đổi tên cột / kiểu cột
		local column = statement:match('%.HasColumnName%(%s*"([^"]+)"')
		local field = statement:match('%.Property%b<>%(%s*"([^"]+)"')
		if column and (property or field) then
			config.column_of[property or field] = column
		end
		if statement:match('%.HasColumnType%(%s*"jsonb"') then
			config.jsonb[column or (property and M.snake_case(property)) or ""] = true
		end
		local index = statement:match("%.HasIndex(%b())")
		if index and statement:match("%.IsUnique%(") then
			local columns = {}
			for column in index:gmatch("[%w_]+%.([%w_]+)") do
				table.insert(columns, column)
			end
			table.insert(config.unique, columns)
		end
	end
	return config
end

-- CreateAssetModelCommand → AssetModel; UpdateAssetDetailsCommand → Asset (thử từ dài đến ngắn, cả dạng số ít).
-- keep_first = true khi tên không bắt đầu bằng động từ (AssetModelResponse, AssetCreatedDomainEvent)
function M.entity_for(name, accept, keep_first)
	local rest = (name:gsub("Command$", ""):gsub("Query$", ""):gsub("Response$", ""))
	if not keep_first then
		rest = (rest:gsub("^%u%l*", "", 1))
	end
	local words = M.words(rest)
	for count = #words, 1, -1 do
		local candidate = table.concat(words, "", 1, count)
		if accept(candidate) then
			return candidate
		end
		-- GetAssetsQuery → Asset
		local single = M.singular(candidate)
		if single ~= candidate and accept(single) then
			return single
		end
	end
end

-- Danh sách using đã lọc trùng, bỏ namespace hiện tại, System.* lên đầu
function M.usings(namespaces, current)
	local seen, out = {}, {}
	for _, namespace in pairs(namespaces) do
		-- Namespace hiện tại và namespace cha đã thấy được, không cần using
		local visible = namespace and current and (namespace == current or vim.startswith(current, namespace .. "."))
		if namespace and not visible and not seen[namespace] then
			seen[namespace] = true
			table.insert(out, namespace)
		end
	end
	table.sort(out, function(a, b)
		local as, bs = a:match("^System") ~= nil, b:match("^System") ~= nil
		if as ~= bs then
			return as
		end
		return a < b
	end)
	for index, namespace in ipairs(out) do
		out[index] = "using " .. namespace .. ";"
	end
	return out
end

-- Placeholder trong code sinh ra; to_snippet() đổi thành ${n:default} theo thứ tự xuất hiện
function M.ph(default)
	return "\1" .. (default or "") .. "\2"
end

local function escape(text)
	return (text:gsub("\\", "\\\\"):gsub("%$", "\\$"):gsub("}", "\\}"))
end

function M.to_snippet(text)
	local out, index, position = {}, 0, 1
	while true do
		local first, last, default = text:find("\1(.-)\2", position)
		if not first then
			table.insert(out, escape(text:sub(position)))
			break
		end
		index = index + 1
		table.insert(out, escape(text:sub(position, first - 1)))
		table.insert(out, ("${%d:%s}"):format(index, escape(default)))
		position = last + 1
	end
	return table.concat(out)
end

return M
