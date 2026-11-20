-- Sinh code C# từ khai báo đã có trong repo. Dùng bởi snippet trong lua/snippets/cs.lua:
--   internalvalidator → validator từ <Command>, độ dài lấy từ EF Configuration của entity
--   internalhandler   → command handler (repository, NotFound, value object, unique, method domain)
--                       hoặc query handler (Dapper SELECT/JOIN từ <Response>)
--   recordevent       → domain event record từ lời gọi Raise(new <Event>(...))
-- Mỗi hàm trả về text (placeholder đánh dấu bằng S.ph) hoặc nil để snippet dùng khung cũ.
local S = require("core.csharp-source")
local ph = S.ph

local M = {}

local find = S.find_type

local function has_repo(entity)
	return entity ~= nil and entity ~= "" and find("I" .. entity .. "Repository") ~= nil
end

local function has_config(entity)
	return entity ~= nil and entity ~= "" and S.configuration(entity) ~= nil
end

-- ": ICommand<Guid>" → "Guid"
local function generic_of(base, interface)
	local args = base:match(interface .. "%s*(%b<>)")
	return args and vim.trim(args:sub(2, -2)) or nil
end

local function is_identity(type)
	return type == "Guid" or type == "int" or type == "long"
end

local function indent(lines, pad)
	local out = {}
	for _, line in ipairs(lines) do
		table.insert(out, line == "" and "" or pad .. line)
	end
	return out
end

local function call(expression, args)
	if #args <= 2 then
		return { expression .. "(" .. table.concat(args, ", ") .. ")" }
	end
	local lines = { expression .. "(" }
	for index, arg in ipairs(args) do
		table.insert(lines, "    " .. arg .. (index < #args and "," or ""))
	end
	table.insert(lines, ")")
	return lines
end

-- Ghép dòng đầu của call() với tiền tố, dòng cuối với hậu tố
local function statement(prefix, lines, suffix)
	local out = vim.deepcopy(lines)
	out[1] = prefix .. out[1]
	out[#out] = out[#out] .. suffix
	return out
end

local function file_text(usings, namespace, body)
	local lines = vim.deepcopy(usings)
	if #lines > 0 then
		table.insert(lines, "")
	end
	table.insert(lines, ("namespace %s;"):format(namespace))
	table.insert(lines, "")
	vim.list_extend(lines, body)
	return table.concat(lines, "\n")
end

-- Validator -----------------------------------------------------------------

function M.validator(class, namespace)
	S.reset_cache()
	local command = class:match("^(.-)Validator$")
	local info = command and find(command)
	if not info then
		return nil
	end
	local entity = S.entity_for(command, has_config)
	local config = entity and S.configuration(entity)
	local namespaces = { "FluentValidation", info.namespace }

	local rules = {}
	for _, prop in ipairs(S.settable_properties(info)) do
		local base, nullable = S.strip_nullable(prop.type)
		local chain = {}
		local max = config and config.max[prop.name]
		if base == "string" then
			if not nullable then
				table.insert(chain, "NotEmpty()")
			end
			if max then
				table.insert(chain, ("MaximumLength(%s)"):format(max))
				-- MaximumLength(AssetTag.MaxLength) cần using namespace của AssetTag
				local owner = find(max:match("^([%a_][%w_]*)%."))
				table.insert(namespaces, owner and owner.namespace or false)
			end
		elseif base == "Guid" then
			table.insert(chain, nullable and "NotEqual(Guid.Empty)" or "NotEmpty()")
		elseif base == "int" and prop.name == "Page" then
			table.insert(chain, "GreaterThanOrEqualTo(1)")
		elseif base == "int" and prop.name == "PageSize" then
			table.insert(chain, ("InclusiveBetween(1, %s)"):format(ph("100")))
		elseif base:match("^%u[%w_]*$") then
			local type = find(base)
			if type and type.kind == "enum_declaration" then
				table.insert(chain, "IsInEnum()")
				table.insert(namespaces, type.namespace)
			end
		end
		if #chain > 0 then
			table.insert(rules, ("RuleFor(c => c.%s).%s;"):format(prop.name, table.concat(chain, ".")))
		end
	end
	if #rules == 0 then
		rules = { ph() }
	end

	local body = {
		("internal sealed class %s : AbstractValidator<%s>"):format(class, command),
		"{",
		("    public %s()"):format(class),
		"    {",
	}
	vim.list_extend(body, indent(rules, "        "))
	vim.list_extend(body, { "    }", "}" })
	return file_text(S.usings(namespaces, namespace), namespace, body)
end

-- Command handler -----------------------------------------------------------

function M.command_handler(class, namespace)
	S.reset_cache()
	local command = class:gsub("Handler$", "")
	local info = find(command)
	if not info then
		return nil
	end
	local params = S.primary_parameters(info)
	local result_type = generic_of(S.base_list(info), "ICommand")

	local by_name = {}
	for _, param in ipairs(params) do
		by_name[param.name:lower()] = param
	end

	-- Aggregate chính: theo tên command, nếu không có repository thì lấy tham số <X>Id đầu tiên có repository
	local entity = S.entity_for(command, has_repo)
	if not entity then
		for _, param in ipairs(params) do
			local prefix = param.name:match("^(.-)Id$")
			if has_repo(prefix) then
				entity = prefix
				break
			end
		end
	end
	if not entity then
		return nil
	end
	local entity_info = find(entity)
	local id_param = by_name[(entity .. "Id"):lower()]
	local mode = id_param and "update" or "create"

	local namespaces = { info.namespace }
	local function use(name)
		local type = find(name)
		table.insert(namespaces, type and type.namespace or false)
		return type
	end
	for _, name in ipairs({ "IUnitOfWork", "ICommandHandler", "Result", entity }) do
		use(name)
	end

	local function fail(error)
		return result_type and ("Result.Failure<%s>(%s)"):format(result_type, error)
			or ("Result.Failure(%s)"):format(error)
	end
	-- `return serialResult;` khi handler trả Result, Result.Failure<T>(x.Error) khi trả Result<T>
	local function fail_from(variable)
		return result_type and fail(variable .. ".Error") or variable
	end

	local repositories = {}
	local function repository(type)
		if not repositories[type] then
			repositories[type] = true
			table.insert(repositories, type)
			use("I" .. type .. "Repository")
		end
		return S.camel(type) .. "Repository"
	end
	repository(entity)

	local body = {}
	local function emit(lines)
		vim.list_extend(body, lines)
	end

	local loaded, loaded_order, consumed = {}, {}, {}
	local function mark(type, variable)
		loaded[type] = variable
		table.insert(loaded_order, { type = type, variable = variable })
	end

	local function load_required(type, id)
		local variable = S.camel(type)
		use(type .. "Errors")
		emit(
			statement(
				("%s? %s = await "):format(type, variable),
				call(repository(type) .. ".GetAsync", { id, "cancellationToken" }),
				";"
			)
		)
		emit({
			("if (%s is null)"):format(variable),
			"{",
			("    return %s;"):format(fail(("%sErrors.NotFound(%s)"):format(type, id))),
			"}",
			"",
		})
		mark(type, variable)
	end

	-- check = true: id lấy từ request nên phải báo NotFound; false: id lấy từ entity đã nạp
	local function load_optional(type, id, id_type, check)
		local variable = S.camel(type)
		local id_variable = variable .. "Id"
		if check then
			use(type .. "Errors")
			emit({
				("%s? %s = null;"):format(type, variable),
				("if (%s is %s %s)"):format(id, id_type, id_variable),
				"{",
				("    %s = await %s.GetAsync(%s, cancellationToken);"):format(variable, repository(type), id_variable),
				("    if (%s is null)"):format(variable),
				"    {",
				("        return %s;"):format(fail(("%sErrors.NotFound(%s)"):format(type, id_variable))),
				"    }",
				"}",
				"",
			})
		else
			emit({
				("%s? %s = %s is %s %s"):format(type, variable, id, id_type, id_variable),
				("    ? await %s.GetAsync(%s, cancellationToken)"):format(repository(type), id_variable),
				"    : null;",
				"",
			})
		end
		mark(type, variable)
	end

	-- Method domain: Create (tĩnh) khi tạo mới; khi sửa thì theo tên command bỏ tên entity
	local target
	local methods = S.methods(entity_info)
	if mode == "create" then
		for _, method in ipairs(methods) do
			if method.static and method.name == "Create" then
				target = method
			end
		end
		for _, method in ipairs(methods) do
			local returns = method.returns
			if
				not target
				and method.static
				and (returns == entity or S.generic_argument(returns, "Result") == entity)
			then
				target = method
			end
		end
	else
		local wanted = command:gsub("Command$", ""):gsub(entity, "", 1)
		local verb = command:match("^%u%l*")
		for _, method in ipairs(methods) do
			if not method.static and method.name == wanted then
				target = method
			end
		end
		for _, method in ipairs(methods) do
			if not target and not method.static and method.public and vim.startswith(method.name, verb) then
				target = method
			end
		end
	end
	local target_params = target and target.params or {}

	-- 1. Value object: tham số kiểu V có V.Create(...) và request có property string cùng tên
	local args = {}
	for index, param in ipairs(target_params) do
		local base, nullable = S.strip_nullable(param.type)
		local source = by_name[param.name:lower()]
		local source_type = source and S.strip_nullable(source.type)
		local value_type = source_type == "string" and base ~= "string" and not has_repo(base) and find(base)
		local create
		for _, method in ipairs(value_type and S.methods(value_type) or {}) do
			if method.static and method.name == "Create" then
				create = method
			end
		end
		if create then
			use(base)
			consumed[source.name] = true
			local variable = param.name
			local result_variable = variable .. "Result"
			local returns_result = S.generic_argument(create.returns, "Result") ~= nil
			local request = "request." .. source.name
			if not returns_result then
				emit({ ("%s %s = %s.Create(%s);"):format(param.type, variable, base, request), "" })
			elseif nullable then
				emit({
					("%s? %s = null;"):format(base, variable),
					("if (!string.IsNullOrWhiteSpace(%s))"):format(request),
					"{",
					("    Result<%s> %s = %s.Create(%s);"):format(base, result_variable, base, request),
					("    if (%s.IsFailure)"):format(result_variable),
					"    {",
					("        return %s;"):format(fail_from(result_variable)),
					"    }",
					"",
					("    %s = %s.Value;"):format(variable, result_variable),
					"}",
					"",
				})
			else
				emit({
					("Result<%s> %s = %s.Create(%s);"):format(base, result_variable, base, request),
					("if (%s.IsFailure)"):format(result_variable),
					"{",
					("    return %s;"):format(fail_from(result_variable)),
					"}",
					"",
					("%s %s = %s.Value;"):format(base, variable, result_variable),
					"",
				})
			end
			args[index] = variable
		end
	end

	-- 2. Aggregate chính (khi sửa) và entity khác tham chiếu bằng <X>Id trong request
	if id_param then
		consumed[id_param.name] = true
		load_required(entity, "request." .. id_param.name)
	end
	for _, param in ipairs(params) do
		local prefix = param.name:match("^(.-)Id$")
		local base, nullable = S.strip_nullable(param.type)
		if param ~= id_param and prefix ~= entity and is_identity(base) and has_repo(prefix) then
			consumed[param.name] = true
			if nullable then
				load_optional(prefix, "request." .. param.name, base, true)
			else
				load_required(prefix, "request." .. param.name)
			end
		end
	end

	-- 3. Entity mà method domain cần nhưng request không có id: lấy <X>Id từ entity đã nạp
	local progress = true
	while progress do
		progress = false
		for _, param in ipairs(target_params) do
			local base = S.strip_nullable(param.type)
			if not loaded[base] and has_repo(base) then
				for _, owner in ipairs(loaded_order) do
					local id_type = S.members(find(owner.type))[base .. "Id"]
					if id_type then
						local id = owner.variable .. "." .. base .. "Id"
						local id_base, nullable = S.strip_nullable(id_type)
						if nullable then
							load_optional(base, id, id_base, false)
						else
							load_required(base, id)
						end
						progress = true
						break
					end
				end
			end
		end
	end

	-- 4. Unique index trong EF Configuration → kiểm tra trước khi tạo
	local config = mode == "create" and S.configuration(entity)
	local repository_methods = S.methods(find("I" .. entity .. "Repository"))
	local errors = find(entity .. "Errors")
	local error_names = vim.tbl_keys(S.members(errors))
	for _, method in ipairs(S.methods(errors)) do
		table.insert(error_names, method.name)
	end
	table.sort(error_names)

	local function source_of(name)
		for index, param in ipairs(target_params) do
			if args[index] and param.name:lower() == name:lower() then
				return args[index]
			end
		end
		local referenced = name:match("^(.-)Id$")
		if referenced and loaded[referenced] then
			return loaded[referenced] .. ".Id"
		end
		local param = by_name[name:lower()]
		return param and ("request." .. param.name) or nil
	end

	for _, columns in ipairs(config and config.unique or {}) do
		local sources, complete = {}, true
		for _, column in ipairs(columns) do
			sources[column:lower()] = source_of(column)
			complete = complete and sources[column:lower()] ~= nil
		end
		if complete then
			local wanted = {}
			for _, column in ipairs(columns) do
				wanted[column:lower()] = true
			end
			local check_name, check_args, negate
			for _, method in ipairs(repository_methods) do
				local names, matches = {}, method.returns == "Task<bool>"
				for _, param in ipairs(method.params) do
					if param.type ~= "CancellationToken" then
						table.insert(names, param.name:lower())
						matches = matches and wanted[param.name:lower()] == true
					end
				end
				if matches and #names == #columns then
					check_name, check_args = method.name, {}
					for _, name in ipairs(names) do
						table.insert(check_args, sources[name])
					end
					negate = method.name:match("Unique") ~= nil
				end
			end
			if not check_name then
				check_name, check_args = ph("ExistsBy" .. table.concat(columns) .. "Async"), {}
				for _, column in ipairs(columns) do
					table.insert(check_args, sources[column:lower()])
				end
			end
			table.insert(check_args, "cancellationToken")

			local last = columns[#columns]
			local error
			for _, name in ipairs(error_names) do
				if not error and name:match(last) and (name:match("NotUnique") or name:match("Duplicate")) then
					error = entity .. "Errors." .. name
				end
			end
			error = error or ph(entity .. "Errors." .. last .. "NotUnique")

			local lines = call(repository(entity) .. "." .. check_name, check_args)
			emit(statement(negate and "if (!await " or "if (await ", lines, ")"))
			emit({ "{", ("    return %s;"):format(fail(error)), "}", "" })
		end
	end

	-- 5. Tham số method domain: entity đã nạp → value object → request cùng tên → request cùng kiểu
	for index, param in ipairs(target_params) do
		if not args[index] then
			local base = S.strip_nullable(param.type)
			local source = by_name[param.name:lower()]
			if loaded[base] then
				args[index] = loaded[base]
			elseif source and not consumed[source.name] then
				args[index] = "request." .. source.name
				consumed[source.name] = true
			else
				local match
				for _, candidate in ipairs(params) do
					if not match and not consumed[candidate.name] and candidate.type == param.type then
						match = candidate
					end
				end
				if match then
					consumed[match.name] = true
					args[index] = "request." .. match.name
				else
					args[index] = ph(param.name)
				end
			end
		end
	end

	-- 6. Gọi domain, lưu, trả kết quả
	local variable = S.camel(entity)
	local insert = "Insert"
	for _, method in ipairs(repository_methods) do
		if method.name == "Add" then
			insert = "Add"
		end
	end
	local id_type = S.id_type(entity_info)
	local save = "await unitOfWork.SaveChangesAsync(cancellationToken);"
	local function check_result(result_variable)
		return {
			("if (%s.IsFailure)"):format(result_variable),
			"{",
			("    return %s;"):format(fail_from(result_variable)),
			"}",
			"",
		}
	end
	local function returning(value)
		if not result_type then
			return "return Result.Success();"
		end
		return "return " .. (value or ph("default")) .. ";"
	end

	if mode == "create" then
		local factory = entity .. "." .. (target and target.name or ph("Create"))
		local returns = target and target.returns or entity
		if S.generic_argument(returns, "Result") then
			emit(statement(("Result<%s> result = "):format(entity), call(factory, args), ";"))
			emit({ "" })
			emit(check_result("result"))
			emit({
				("%s.%s(result.Value);"):format(repository(entity), insert),
				"",
				save,
				"",
				returning(result_type == id_type and "result.Value.Id" or nil),
			})
		else
			emit(statement(("var %s = "):format(variable), call(factory, args), ";"))
			emit({
				"",
				("%s.%s(%s);"):format(repository(entity), insert, variable),
				"",
				save,
				"",
				returning(result_type == id_type and (variable .. ".Id") or nil),
			})
		end
	else
		local method = variable .. "." .. (target and target.name or ph("Method"))
		local returns = target and target.returns or "Result"
		local inner = S.generic_argument(returns, "Result")
		local value
		if returns == "Result" then
			emit(statement("Result result = ", call(method, args), ";"))
			emit({ "" })
			emit(check_result("result"))
		elseif inner then
			emit(statement(("Result<%s> result = "):format(inner), call(method, args), ";"))
			emit({ "" })
			emit(check_result("result"))
			local inner_id = S.id_type(find(inner) or {}) or S.members(find(inner)).Id
			value = (inner_id and inner_id == result_type) and "result.Value.Id"
				or (inner == result_type and "result.Value" or nil)
		else
			emit(statement("", call(method, args), ";"))
			emit({ "" })
		end
		emit({ save, "", returning(value) })
	end

	local constructor = {}
	for _, type in ipairs(repositories) do
		table.insert(constructor, ("    I%sRepository %s,"):format(type, repository(type)))
	end
	table.insert(constructor, "    IUnitOfWork unitOfWork")

	local result = result_type and ("Result<%s>"):format(result_type) or "Result"
	local interface = result_type and ("ICommandHandler<%s, %s>"):format(command, result_type)
		or ("ICommandHandler<%s>"):format(command)
	local lines = { ("internal sealed class %s("):format(class) }
	vim.list_extend(lines, constructor)
	vim.list_extend(lines, {
		(") : %s"):format(interface),
		"{",
		("    public async Task<%s> Handle("):format(result),
		("        %s request,"):format(command),
		"        CancellationToken cancellationToken",
		"    )",
		"    {",
	})
	vim.list_extend(lines, indent(body, "        "))
	vim.list_extend(lines, { "    }", "}" })
	return file_text(S.usings(namespaces, namespace), namespace, lines)
end

-- Query handler -------------------------------------------------------------

local collection_types = { "IReadOnlyCollection", "IReadOnlyList", "IEnumerable", "List" }

-- SELECT ... FROM ... JOIN từ property của Response. Cột không có trên bảng chính được tìm qua khóa ngoại
-- <X>Id (tối đa 2 bước): AssetModelName → JOIN asset_models am → am.name; tên cột lấy từ EF Configuration.
-- opts.alias / opts.table ghi đè alias / bảng chính. Dùng chung cho query handler và :SqlSelect.
function M.select_sql(response_info, entity, opts)
	opts = opts or {}
	local schema = (S.module_name() or ""):lower()
	local function table_of(type)
		local config = S.configuration(type)
		local name = config and config.table or S.plural(S.snake_case(type))
		return schema ~= "" and (schema .. "." .. name) or name
	end
	local function column_of(type, property)
		local config = S.configuration(type)
		return config and config.column_of[property] or S.snake_case(property)
	end
	local function member(type, property)
		return S.members(find(type))[property]
	end

	local used_aliases = {}
	local function alias_for(type)
		local alias = S.initials(type)
		local base, count = alias, 2
		while used_aliases[alias] do
			alias, count = base .. count, count + 1
		end
		used_aliases[alias] = true
		return alias
	end

	local main = { type = entity }
	if opts.alias then
		used_aliases[opts.alias] = true
		main.alias = opts.alias
	else
		main.alias = alias_for(entity)
	end
	local joins, joined = {}, {}
	-- JOIN theo khóa ngoại <X>Id của bảng đã có; mỗi đường đi chỉ JOIN một lần
	local function join(from, type, fk)
		local key = from.alias .. "." .. fk
		if not joined[key] then
			local fk_type = member(from.type, fk)
			local _, nullable = S.strip_nullable(fk_type)
			local node = { type = type, alias = alias_for(type) }
			table.insert(
				joins,
				("%s %s %s ON %s.id = %s.%s"):format(
					nullable and "LEFT JOIN" or "JOIN",
					table_of(type),
					node.alias,
					node.alias,
					from.alias,
					column_of(from.type, fk)
				)
			)
			joined[key] = node
		end
		return joined[key]
	end

	local function foreign_keys(type)
		local out = {}
		for name in pairs(S.members(find(type))) do
			local prefix = name:match("^(.-)Id$")
			if has_config(prefix) then
				table.insert(out, { fk = name, type = prefix })
			end
		end
		-- Tiền tố dài trước: AssetModelName ưu tiên AssetModel hơn Asset
		table.sort(out, function(a, b)
			return #a.type > #b.type
		end)
		return out
	end

	-- AssetModelName → JOIN asset_models am → am.name; ManufacturerName qua 2 bước JOIN
	local function resolve(property, from, depth)
		if member(from.type, property) then
			return from, property
		end
		if depth == 0 then
			return nil
		end
		for _, fk in ipairs(foreign_keys(from.type)) do
			if vim.startswith(property, fk.type) and #property > #fk.type then
				local rest = property:sub(#fk.type + 1)
				if member(fk.type, rest) then
					return join(from, fk.type, fk.fk), rest
				end
			end
		end
		for _, fk in ipairs(foreign_keys(from.type)) do
			for _, next_fk in ipairs(foreign_keys(fk.type)) do
				if vim.startswith(property, next_fk.type) and #property > #next_fk.type then
					local rest = property:sub(#next_fk.type + 1)
					if member(next_fk.type, rest) then
						local middle = join(from, fk.type, fk.fk)
						return join(middle, next_fk.type, next_fk.fk), rest
					end
				end
			end
		end
	end

	local columns = {}
	for _, prop in ipairs(S.settable_properties(response_info)) do
		local base = S.strip_nullable(prop.type)
		-- Property lồng (FieldSetResponse, List<...>) phải nạp riêng
		if not base:match("Response") and not base:match("<") then
			local node, property = resolve(prop.name, main, 2)
			local expression
			if node then
				local column = column_of(node.type, property)
				local config = S.configuration(node.type)
				expression = node.alias .. "." .. column
				if base == "string" and config and config.jsonb[column] then
					expression = expression .. "::text"
				end
			else
				expression = ph(main.alias .. "." .. S.snake_case(prop.name))
			end
			table.insert(columns, ("    %s AS {nameof(%s.%s)}"):format(expression, response_info.name, prop.name))
		end
	end
	for index = 1, #columns - 1 do
		columns[index] = columns[index] .. ","
	end

	local lines = { "SELECT" }
	vim.list_extend(lines, columns)
	table.insert(lines, ("FROM %s %s"):format(opts.table or table_of(entity), main.alias))
	vim.list_extend(lines, joins)
	return { lines = lines, joins = joins, main = main, column_of = column_of, member = member }
end

-- Kiểu C# → kiểu PostgreSQL để ép tham số `@X::uuid IS NULL` (Npgsql không suy ra kiểu của NULL)
local pg_types = {
	string = "text",
	Guid = "uuid",
	int = "int",
	long = "bigint",
	bool = "boolean",
	decimal = "numeric",
	DateTime = "timestamp",
	DateTimeOffset = "timestamptz",
	DateOnly = "date",
}

-- { items, item_info, count, count_type } khi Query có Page + PageSize và Response có một collection Response
local function paged_shape(query_params, response_info)
	local names = {}
	for _, param in ipairs(query_params) do
		names[param.name] = true
	end
	if not (names.Page and names.PageSize) then
		return nil
	end
	local shape = {}
	for _, prop in ipairs(S.settable_properties(response_info)) do
		for _, collection in ipairs(collection_types) do
			local element = S.generic_argument(prop.type, collection)
			local element_info = element and find(element)
			if element_info then
				shape.items, shape.item_info = prop.name, element_info
			end
		end
		if (prop.type == "int" or prop.type == "long") and (prop.name:match("Total") or prop.name:match("Count")) then
			shape.count, shape.count_type = prop.name, prop.type
		end
	end
	if not shape.items then
		return nil
	end
	shape.count_type = shape.count_type or "int"
	return shape
end

-- WHERE theo tham số Query. Tham số nullable là bộ lọc tùy chọn: `(@State::text IS NULL OR a.state = @State)`
local function filter_conditions(query_params, entity, select, paged)
	local main, member, column_of = select.main, select.member, select.column_of
	local conditions = {}
	for _, param in ipairs(query_params) do
		if not (paged and (param.name == "Page" or param.name == "PageSize")) then
			local column
			if param.name == entity .. "Id" then
				column = main.alias .. ".id"
			elseif member(entity, param.name) then
				column = main.alias .. "." .. column_of(entity, param.name)
			else
				column = ph(main.alias .. "." .. S.snake_case(param.name))
			end
			local base, nullable = S.strip_nullable(param.type)
			if nullable then
				local cast = pg_types[base] or ph("text")
				table.insert(conditions, ("(@%s::%s IS NULL OR %s = @%s)"):format(param.name, cast, column, param.name))
			else
				table.insert(conditions, ("%s = @%s"):format(column, param.name))
			end
		end
	end
	return conditions
end

-- Thêm WHERE / ORDER BY / OFFSET-LIMIT và câu COUNT(*) vào `sql` (QueryMultiple đọc 2 kết quả).
-- ORDER BY mặc định theo cột unique đầu tiên trong EF Configuration (Tag), không có thì id.
function M.paged_sql(sql, conditions, from, entity, select)
	local function where()
		if #conditions == 0 then
			return {}
		end
		local out = { "WHERE" }
		for index, condition in ipairs(conditions) do
			table.insert(out, "    " .. (index > 1 and "AND " or "") .. condition)
		end
		return out
	end
	local config = S.configuration(entity)
	local unique = config and config.unique[1] and config.unique[1][1]
	local order = select.main.alias .. "." .. (unique and select.column_of(entity, unique) or "id")
	vim.list_extend(sql, where())
	vim.list_extend(
		sql,
		{ "ORDER BY", "    " .. ph(order), "OFFSET @Skip", "LIMIT @Take;", "", "SELECT", "    COUNT(*)" }
	)
	table.insert(sql, from)
	vim.list_extend(sql, where())
end

function M.query_handler(class, namespace)
	S.reset_cache()
	local query = class:gsub("Handler$", "")
	local info = find(query)
	if not info then
		return nil
	end
	local response_full = generic_of(S.base_list(info), "IQuery")
	if not response_full then
		return nil
	end
	local response = response_full
	local is_list = false
	for _, collection in ipairs(collection_types) do
		local element = S.generic_argument(response_full, collection)
		if element then
			response, is_list = element, true
		end
	end
	local response_info = find(response)
	if not response_info then
		return nil
	end
	local query_params = S.primary_parameters(info)
	-- Phân trang: Query có Page + PageSize, Response bọc một collection item (GetAssetsResponse.Items)
	local paged = paged_shape(query_params, response_info)
	local row = paged and paged.item_info or response_info
	local entity = S.entity_for(row.name, has_config, true) or S.entity_for(query, has_config)
	if not entity then
		return nil
	end

	local select = M.select_sql(row, entity)
	local conditions = filter_conditions(query_params, entity, select, paged)

	local sql = select.lines
	local from = sql[#select.lines - #select.joins]
	if paged then
		M.paged_sql(sql, conditions, from, entity, select)
	elseif #conditions > 0 then
		table.insert(sql, "WHERE " .. table.concat(conditions, " AND "))
	end

	local namespaces = { info.namespace, response_info.namespace, "System.Data.Common", "Dapper" }
	if paged then
		table.insert(namespaces, paged.item_info.namespace)
	end
	for _, name in ipairs({ "IQueryHandler", "IDbConnectionFactory", "Result" }) do
		local type = find(name)
		table.insert(namespaces, type and type.namespace or false)
	end

	local body = {
		"await using DbConnection connection = await dbConnectionFactory.OpenConnectionAsync();",
		"",
	}
	if paged then
		-- Dapper chỉ nhận tham số có tên; Skip/Take tính từ Page/PageSize
		table.insert(body, "var parameters = new")
		table.insert(body, "{")
		for _, param in ipairs(query_params) do
			if param.name ~= "Page" and param.name ~= "PageSize" then
				table.insert(body, ("    request.%s,"):format(param.name))
			end
		end
		vim.list_extend(body, {
			"    Take = request.PageSize,",
			"    Skip = (request.Page - 1) * request.PageSize,",
			"};",
			"",
		})
	end
	vim.list_extend(body, {
		"const string sql =",
		"        //language=sql",
		'        $"""',
	})
	vim.list_extend(body, indent(sql, "        "))
	vim.list_extend(body, { '        """;', "" })

	local variable = S.camel(is_list and S.plural(entity) or entity)
	if paged then
		vim.list_extend(body, {
			"await using SqlMapper.GridReader grid = await connection.QueryMultipleAsync(sql, parameters);",
		})
		vim.list_extend(body, {
			"",
			("var items = (await grid.ReadAsync<%s>()).AsList();"):format(paged.item_info.name),
			("%s totalCount = await grid.ReadSingleAsync<%s>();"):format(paged.count_type, paged.count_type),
			"",
		})
		-- Gán từng tham số của Response: Items → items, Total*/Count → totalCount, trùng tên Query → request.X
		local args = {}
		for _, prop in ipairs(S.settable_properties(response_info)) do
			if prop.name == paged.items then
				table.insert(args, "items")
			elseif prop.name == paged.count then
				table.insert(args, "totalCount")
			elseif vim.iter(query_params):any(function(param)
				return param.name == prop.name
			end) then
				table.insert(args, "request." .. prop.name)
			else
				table.insert(args, ph(S.camel(prop.name)))
			end
		end
		vim.list_extend(body, statement("return ", call("new " .. response_info.name, args), ";"))
	elseif is_list then
		vim.list_extend(body, {
			("List<%s> %s = (await connection.QueryAsync<%s>(sql, request)).AsList();"):format(
				response,
				variable,
				response
			),
			"",
			("return %s;"):format(variable),
		})
	else
		local errors = find(entity .. "Errors")
		table.insert(namespaces, errors and errors.namespace or false)
		local id = query_params[1] and ("request." .. query_params[1].name) or ""
		vim.list_extend(body, {
			("%s? %s = await connection.QuerySingleOrDefaultAsync<%s>(sql, request);"):format(
				response,
				variable,
				response
			),
			"",
			("if (%s is null)"):format(variable),
			"{",
			("    return Result.Failure<%s>(%sErrors.NotFound(%s));"):format(response, entity, id),
			"}",
			"",
			("return %s;"):format(variable),
		})
	end

	local lines = {
		("internal sealed class %s(IDbConnectionFactory dbConnectionFactory)"):format(class),
		("    : IQueryHandler<%s, %s>"):format(query, response_full),
		"{",
		("    public async Task<Result<%s>> Handle("):format(response_full),
		("        %s request,"):format(query),
		"        CancellationToken cancellationToken",
		"    )",
		"    {",
	}
	vim.list_extend(lines, indent(body, "        "))
	vim.list_extend(lines, { "    }", "}" })
	return file_text(S.usings(namespaces, namespace), namespace, lines)
end

function M.handler(class, namespace)
	if class:match("CommandHandler$") then
		return M.command_handler(class, namespace)
	elseif class:match("QueryHandler$") then
		return M.query_handler(class, namespace)
	end
end

-- Domain event --------------------------------------------------------------

local literal_types = {
	string_literal = "string",
	verbatim_string_literal = "string",
	raw_string_literal = "string",
	interpolated_string_expression = "string",
	integer_literal = "int",
	real_literal = "double",
	boolean_literal = "bool",
	character_literal = "char",
}

local function nullable(type)
	if type and type:sub(-1) ~= "?" then
		return type .. "?"
	end
	return type
end

local function member_type(type, name)
	if not type then
		return nil
	end
	local base = S.strip_nullable(type)
	local inner = S.generic_argument(base, "Result")
	if inner and name == "Value" then
		return inner
	end
	if name == "Count" or name == "Length" then
		return "int"
	end
	return S.members(find(base))[name]
end

local function named_children(node)
	local out = {}
	for child in node:iter_children() do
		if child:named() then
			table.insert(out, child)
		end
	end
	return out
end

-- Kiểu của biểu thức trong method: tham số, biến cục bộ, member của class, chuỗi member access
local function expression_type(node, context)
	local kind = node:type()
	local src = context.src
	if literal_types[kind] then
		return literal_types[kind]
	elseif kind == "identifier" then
		local name = S.text(node, src)
		return context.locals[name] or S.members(context.class)[name]
	elseif kind == "member_access_expression" then
		local base = expression_type(node:field("expression")[1], context)
		return member_type(base, S.text(node:field("name")[1], src))
	elseif kind == "conditional_access_expression" then
		local base = expression_type(node:field("condition")[1], context)
		local binding = S.find_node(node, function(n)
			return n:type() == "member_binding_expression"
		end)
		local name = binding and S.text(binding:field("name")[1], src)
		return nullable(member_type(base, name))
	elseif kind == "object_creation_expression" then
		return S.text(node:field("type")[1], src)
	elseif kind == "invocation_expression" then
		-- X.Create(...) → kiểu trả về của method tĩnh
		local fn = node:field("function")[1]
		if fn and fn:type() == "member_access_expression" then
			local owner = S.text(fn:field("expression")[1], src)
			local name = S.text(fn:field("name")[1], src)
			for _, method in ipairs(S.methods(find(owner))) do
				if method.name == name then
					return method.returns
				end
			end
		end
	end
end

local function argument_name(node, context)
	local kind = node:type()
	local src = context.src
	if kind == "identifier" then
		local name = S.text(node, src)
		return name == "Id" and (context.class.name .. "Id") or S.pascal(name)
	elseif kind == "member_access_expression" or kind == "conditional_access_expression" then
		local expression, name
		if kind == "member_access_expression" then
			expression, name = node:field("expression")[1], S.text(node:field("name")[1], src)
		else
			expression = node:field("condition")[1]
			local binding = S.find_node(node, function(n)
				return n:type() == "member_binding_expression"
			end)
			name = binding and S.text(binding:field("name")[1], src)
		end
		if name == "Value" then
			return argument_name(expression, context)
		elseif name == "Id" then
			local owner = S.strip_nullable(expression_type(expression, context) or "")
			owner = S.generic_argument(owner, "Result") or owner
			return owner:match("^[%a_][%w_]*$") and (owner .. "Id") or "Id"
		end
		return name
	end
	return nil
end

local function collect_locals(method, src)
	local locals = {}
	for _, param in ipairs(S.parameters(method:field("parameters")[1], src)) do
		locals[param.name] = param.type
	end
	for _, declaration in
		ipairs(S.find_all(method, function(n)
			return n:type() == "variable_declaration"
		end))
	do
		local type = S.text(declaration:field("type")[1], src)
		for declarator in declaration:iter_children() do
			if declarator:type() == "variable_declarator" then
				local name = S.text(declarator:field("name")[1], src)
				locals[name] = type ~= "var" and type or false
				if type == "var" then
					-- Gán sau khi đã có context đầy đủ
					locals[name] = { pending = named_children(declarator)[2] }
				end
			end
		end
	end
	for _, pattern in
		ipairs(S.find_all(method, function(n)
			return n:type() == "declaration_pattern"
		end))
	do
		locals[S.text(pattern:field("name")[1], src)] = S.text(pattern:field("type")[1], src)
	end
	return locals
end

function M.domain_event(class, namespace)
	S.reset_cache()
	local base_type = find("DomainEvent")
	local namespaces = { base_type and base_type.namespace or false }

	local creation, src, file
	for _, candidate in ipairs(S.rg_files("new\\s+" .. class .. "\\s*\\(")) do
		local root, text = S.parse_file(candidate)
		creation = root
			and S.find_node(root, function(n)
				return n:type() == "object_creation_expression" and S.text(n:field("type")[1], text) == class
			end)
		if creation then
			src, file = text, candidate
			break
		end
	end

	local params = {}
	if creation then
		local method = S.ancestor(creation, {
			method_declaration = true,
			constructor_declaration = true,
			local_function_statement = true,
		})
		local owner = S.ancestor(creation, S.type_kinds)
		local context = {
			src = src,
			class = { node = owner, src = src, file = file, name = S.text(owner:field("name")[1], src) },
			locals = method and collect_locals(method, src) or {},
		}
		for name, value in pairs(context.locals) do
			if type(value) == "table" then
				context.locals[name] = value.pending and expression_type(value.pending, context) or nil
			end
		end

		local arguments = S.find_node(creation, function(n)
			return n:type() == "argument_list"
		end)
		for argument in arguments and arguments:iter_children() or function() end do
			if argument:type() == "argument" then
				local children = named_children(argument)
				local expression = children[#children]
				local label = argument:field("name")[1]
				local name = label and S.pascal(S.text(label, src)) or argument_name(expression, context)
				local arg_type = expression_type(expression, context)
				if arg_type then
					local type_info = find((S.strip_nullable(arg_type)))
					table.insert(namespaces, type_info and type_info.namespace or false)
				end
				table.insert(params, ("%s %s"):format(arg_type or ph("object"), name or ph("Value")))
			end
		end
	end

	local declaration = #params > 0 and table.concat(params, ", ") or ph()
	return file_text(S.usings(namespaces, namespace), namespace, {
		("public sealed record %s(%s) : DomainEvent;"):format(class, declaration),
	})
end

return M
