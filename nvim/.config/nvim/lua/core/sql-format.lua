-- Format SQL nằm trong raw string C# ($""" ... """) bằng pg_format (Mason).
-- Chọn các dòng SQL (không gồm $""" và """;) rồi gõ :SqlFormat hoặc <leader>fq.
vim.api.nvim_create_user_command("SqlFormat", function(opts)
	local lines = vim.api.nvim_buf_get_lines(0, opts.line1 - 1, opts.line2, false)

	-- Giữ thụt lề hiện tại của khối SQL (raw string bắt buộc mọi dòng thụt bằng dòng """ đóng)
	local indent = math.huge
	for _, l in ipairs(lines) do
		if l:match("%S") then
			indent = math.min(indent, #l:match("^%s*"))
		end
	end
	if indent == math.huge then
		return
	end

	-- Mason nạp lazy (VeryLazy) nên PATH có thể chưa có mason/bin; tìm trực tiếp trong đó
	local cmd = vim.fn.exepath("pg_format")
	if cmd == "" then
		cmd = vim.fn.stdpath("data") .. "/mason/bin/pg_format"
	end
	if vim.fn.executable(cmd) == 0 then
		vim.notify("pg_format not found (install via :MasonInstall pgformatter)", vim.log.levels.ERROR)
		return
	end

	-- -s 4: thụt 4 dấu cách; -u 2: keyword viết HOA
	local result = vim.system({ cmd, "-s", "4", "-u", "2", "-" }, { stdin = table.concat(lines, "\n") }):wait()
	if result.code ~= 0 then
		vim.notify(result.stderr, vim.log.levels.ERROR)
		return
	end

	local pad = string.rep(" ", indent)
	local out = {}
	for _, l in ipairs(vim.split(vim.trim(result.stdout), "\n")) do
		table.insert(out, l == "" and "" or pad .. l)
	end
	vim.api.nvim_buf_set_lines(0, opts.line1 - 1, opts.line2, false, out)
end, { range = true, desc = "Format SQL in selection with pg_format" })

vim.keymap.set("x", "<leader>fq", ":SqlFormat<CR>", { silent = true, desc = "Format selected SQL" })

-- Sinh danh sách cột SELECT cho Dapper từ primary constructor của record C#.
-- :SqlSelect CustomFieldResponse  →  SELECT cf.is_required AS {nameof(CustomFieldResponse.IsRequired)}, ... FROM assets.custom_fields cf
-- Alias/bảng suy từ tên record, schema từ thư mục module; truyền [alias] [schema.table] để ghi đè.
local function record_parameters(record)
	local root = vim.fs.root(0, ".git") or vim.fn.getcwd()
	local found = vim.system({ "rg", "-l", "--glob", "*.cs", "record\\s+" .. record .. "\\s*\\(", root }):wait()
	local file = vim.split(vim.trim(found.stdout or ""), "\n")[1]
	if not file or file == "" then
		return nil, "record " .. record .. " not found"
	end
	local source = table.concat(vim.fn.readfile(file), "\n")
	local start = source:find("record%s+" .. record .. "%s*%(")
	local params = source:sub(start):match("%b()")
	local names, depth, current = {}, 0, ""
	-- Tách theo dấu phẩy ở mức ngoài cùng (generic/tuple có thể chứa dấu phẩy)
	for ch in params:sub(2, -2):gmatch(".") do
		if ch == "<" or ch == "(" or ch == "[" then
			depth = depth + 1
		elseif ch == ">" or ch == ")" or ch == "]" then
			depth = depth - 1
		end
		if ch == "," and depth == 0 then
			table.insert(names, current)
			current = ""
		else
			current = current .. ch
		end
	end
	table.insert(names, current)
	local result = {}
	for _, param in ipairs(names) do
		param = param:gsub("=.*$", "")
		local name = vim.trim(param):match("([%a_][%w_]*)%s*$")
		if name then
			table.insert(result, name)
		end
	end
	return result
end

local function snake_case(name)
	return (name:gsub("(%u)(%u%l)", "%1_%2"):gsub("([%l%d])(%u)", "%1_%2"):lower())
end

-- Category → categories, Asset → assets, Status → statuses
local function plural(word)
	if word:match("[^aeiou]y$") then
		return word:sub(1, -2) .. "ies"
	elseif word:match("s$") or word:match("x$") or word:match("ch$") or word:match("sh$") then
		return word .. "es"
	end
	return word .. "s"
end

-- SELECT + JOIN dựng bởi core.csharp-scaffold (dùng chung với query handler); nil khi thiếu entity/Configuration
local function joined_select(record, alias, table_name)
	local ok, result = pcall(function()
		local S = require("core.csharp-source")
		S.reset_cache()
		local info = S.find_type(record)
		local entity = info
			and S.entity_for(record, function(candidate)
				return S.configuration(candidate) ~= nil
			end, true)
		if not entity then
			return nil
		end
		return require("core.csharp-scaffold").select_sql(info, entity, { alias = alias, table = table_name }).lines
	end)
	return ok and result or nil
end

vim.api.nvim_create_user_command("SqlSelect", function(opts)
	local record, alias, table_name = opts.fargs[1], opts.fargs[2], opts.fargs[3]
	local names, err = record_parameters(record)
	if not names then
		-- Record khai báo bằng property `{ get; init; }` thay vì primary constructor
		local ok, info = pcall(function()
			local S = require("core.csharp-source")
			S.reset_cache()
			return S.find_type(record)
		end)
		if ok and info then
			names = {}
			for _, prop in ipairs(require("core.csharp-source").settable_properties(info)) do
				table.insert(names, prop.name)
			end
		end
	end
	if not names or #names == 0 then
		vim.notify(err or ("record " .. record .. " has no properties"), vim.log.levels.ERROR)
		return
	end
	-- Mặc định suy từ tên record: CustomFieldResponse → bảng custom_fields, alias cf
	local entity = record:gsub("Response$", "")
	alias = alias or entity:gsub("%l", ""):lower()
	table_name = table_name or plural(snake_case(entity))
	if not table_name:find("%.") then
		-- Schema = tên module trong đường dẫn file (src/Modules/Assets/... → assets)
		local module = vim.api.nvim_buf_get_name(0):match("/Modules/([%w_]+)/")
		table_name = module and (module:lower() .. "." .. table_name) or table_name
	end

	local row = vim.api.nvim_win_get_cursor(0)[1]
	local current = vim.api.nvim_get_current_line()
	local pad = current:match("^%s*")
	local unit = "    " -- 4 dấu cách, khớp pg_format -s 4 của :SqlFormat

	-- Dòng phía trên đã là SELECT thì chỉ sinh cột + FROM, không lặp SELECT
	local above = row > 1 and vim.api.nvim_buf_get_lines(0, row - 2, row - 1, false)[1] or ""
	local has_select = vim.trim(above):upper() == "SELECT"
	local select_pad = has_select and above:match("^%s*") or pad
	local column_pad = select_pad .. unit

	-- Có entity + EF Configuration: tự JOIN bảng của cột ngoài bảng chính (AssetModelName → am.name)
	local sql = joined_select(record, opts.fargs[2], opts.fargs[3])
	if not sql then
		sql = { "SELECT" }
		for index, name in ipairs(names) do
			local comma = index < #names and "," or ""
			table.insert(sql, ("    %s.%s AS {nameof(%s.%s)}%s"):format(alias, snake_case(name), record, name, comma))
		end
		table.insert(sql, ("FROM %s %s"):format(table_name, alias))
	end

	local out = {}
	for index, line in ipairs(sql) do
		if index > 1 or not has_select then
			-- Cột thụt thêm một cấp so với SELECT/FROM/JOIN
			table.insert(out, (line:match("^    ") and column_pad .. line:sub(5) or select_pad .. line))
		end
	end

	-- Dòng hiện tại trống thì thay luôn, có nội dung thì chèn bên dưới
	local replace = current:match("^%s*$") and 1 or 0
	vim.api.nvim_buf_set_lines(0, row - replace, row, false, out)
end, {
	nargs = "+",
	desc = "Insert Dapper SELECT ... FROM from a C# record: :SqlSelect <Record> [alias] [schema.table]",
	complete = function(arg_lead, cmdline)
		if #vim.split(cmdline, "%s+") > 2 then
			return {}
		end
		local root = vim.fs.root(0, ".git") or vim.fn.getcwd()
		local found = vim.system({ "rg", "-o", "--no-filename", "--glob", "*.cs", "record\\s+\\w+Response\\b", root })
			:wait()
		local items = {}
		for line in (found.stdout or ""):gmatch("[^\n]+") do
			local name = line:match("record%s+(%w+)")
			if name and name:find("^" .. vim.pesc(arg_lead)) and not vim.tbl_contains(items, name) then
				table.insert(items, name)
			end
		end
		return items
	end,
})
