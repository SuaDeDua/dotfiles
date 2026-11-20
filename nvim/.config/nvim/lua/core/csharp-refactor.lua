-- Gọi thẳng code action có sẵn của Roslyn (không qua menu <leader>ga):
--   :CsOrganizeUsings / <leader>go   → Remove unnecessary usings + Sort Usings
--   :CsSyncNamespace [thư mục]       → "Change namespace to '<theo thư mục>'" cho file hiện tại / mọi file .cs
--   <leader>gm                          trong thư mục; sau đó sửa `using` ở file tham chiếu (Roslyn chỉ sửa chính file)
--   :CsMoveType (Visual <leader>gx)  → "Move type to X.cs" cho type trong vùng chọn (con trỏ khi ở Normal)
-- File bị sửa bởi action được lưu lại, kể cả file khác buffer hiện tại.
local M = {}

local function client(buf)
	return vim.lsp.get_clients({ bufnr = buf, name = "easy_dotnet" })[1]
end

-- Diagnostic LSP gốc trên dòng `row`: quickfix (IDE0005 …) chỉ xuất hiện khi gửi kèm diagnostic
local function diagnostics_at(buf, row)
	local out = {}
	for _, d in ipairs(vim.diagnostic.get(buf)) do
		if d.lnum <= row and (d.end_lnum or d.lnum) >= row and d.user_data and d.user_data.lsp then
			table.insert(out, d.user_data.lsp)
		end
	end
	return out
end

local function first_match(actions, patterns)
	for _, pattern in ipairs(patterns) do
		for _, action in ipairs(actions or {}) do
			if action.title:match(pattern) and not action.title:match("^Fix All") then
				return action
			end
		end
	end
end

-- Lưu mọi buffer có trong WorkspaceEdit (Roslyn có thể sửa nhiều file hoặc tạo file mới)
local function save_edited(edit)
	local uris = {}
	for uri in pairs(edit.changes or {}) do
		uris[uri] = true
	end
	for _, change in ipairs(edit.documentChanges or {}) do
		local uri = change.textDocument and change.textDocument.uri or change.uri or change.newUri
		if uri then
			uris[uri] = true
		end
	end
	for uri in pairs(uris) do
		local buf = vim.uri_to_bufnr(uri)
		if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].modified then
			vim.api.nvim_buf_call(buf, function()
				vim.cmd("silent noautocmd write")
			end)
		end
	end
end

-- Tìm action theo `patterns` (thứ tự ưu tiên) tại `range`, resolve rồi áp dụng. done(title | nil, err)
function M.apply(buf, range, patterns, done)
	local c = client(buf)
	if not c then
		return done(nil, "Roslyn chưa attach vào buffer")
	end
	local params = {
		textDocument = { uri = vim.uri_from_bufnr(buf) },
		range = range,
		context = { diagnostics = diagnostics_at(buf, range.start.line), triggerKind = 1 },
	}
	c:request("textDocument/codeAction", params, function(err, actions)
		if err then
			return done(nil, err.message)
		end
		local action = first_match(actions, patterns)
		if not action then
			return done(nil)
		end
		local function apply(resolved)
			if resolved.edit then
				vim.lsp.util.apply_workspace_edit(resolved.edit, c.offset_encoding)
				save_edited(resolved.edit)
			end
			if resolved.command then
				c:exec_cmd(resolved.command, { bufnr = buf })
			end
			done(resolved.title)
		end
		if action.edit or not action.data then
			return apply(action)
		end
		c:request("codeAction/resolve", action, function(resolve_err, resolved)
			if resolve_err or not resolved then
				return done(nil, resolve_err and resolve_err.message or "resolve rỗng")
			end
			apply(resolved)
		end, buf)
	end, buf)
end

local function line_range(row, col)
	return { start = { line = row, character = col or 0 }, ["end"] = { line = row, character = col or 0 } }
end

-- Dòng đầu khớp `pattern` (0-based) và cột của capture đầu tiên nếu có (Roslyn cần con trỏ nằm trên tên)
local function first_line(buf, pattern)
	for index, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
		local position = line:match(pattern)
		if position then
			return index - 1, type(position) == "number" and position - 1 or 0
		end
	end
end

function M.organize_usings(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	local results = {}
	local function step(patterns, next)
		local row = first_line(buf, "^\239?\187?\191?using%s")
		if not row then
			return next()
		end
		M.apply(buf, line_range(row), patterns, function(title, err)
			table.insert(results, title or err)
			next()
		end)
	end
	-- Xóa trước, sắp xếp sau: sau khi xóa vị trí các dòng đã đổi nên phải hỏi lại Roslyn
	step({ "^Remove unnecessary usings" }, function()
		step({ "^Sort Usings" }, function()
			vim.notify(
				"CsOrganizeUsings: " .. (#results > 0 and table.concat(results, ", ") or "không có gì để sửa")
			)
		end)
	end)
end

-- Chạy lần lượt (Roslyn sửa cả file tham chiếu, chạy song song dễ đè lên nhau)
local function each_file(files, fn, finish)
	local index = 0
	local function next()
		index = index + 1
		if index > #files then
			return finish()
		end
		fn(files[index], next)
	end
	next()
end

-- Mở file để Roslyn attach; gọi fn(buf) khi client sẵn sàng
local function with_buffer(file, fn)
	local buf = vim.fn.bufadd(file)
	vim.fn.bufload(buf)
	vim.bo[buf].buflisted = true
	if client(buf) then
		return fn(buf)
	end
	local id
	id = vim.api.nvim_create_autocmd("LspAttach", {
		buffer = buf,
		callback = function(args)
			local attached = vim.lsp.get_client_by_id(args.data.client_id)
			if attached and attached.name == "easy_dotnet" then
				vim.api.nvim_del_autocmd(id)
				vim.schedule(function()
					fn(buf)
				end)
			end
		end,
	})
	vim.api.nvim_buf_call(buf, function()
		vim.cmd("filetype detect")
	end)
end

local function read(file)
	local buf = vim.fn.bufnr(file)
	if buf ~= -1 and vim.api.nvim_buf_is_loaded(buf) then
		return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	end
	return vim.fn.readfile(file)
end

-- Tên type khai báo trong file (class/record/struct/interface/enum)
local function declared_types(file)
	local names = {}
	for _, line in ipairs(read(file)) do
		local name = line:match("[%s^]class%s+([%w_]+)")
			or line:match("record%s+([%w_]+)")
			or line:match("struct%s+([%w_]+)")
			or line:match("interface%s+([%w_]+)")
			or line:match("enum%s+([%w_]+)")
		if name then
			names[name] = true
		end
	end
	return names
end

local function rg_list(args)
	local result = vim.system(vim.list_extend({ "rg", "-l", "--glob", "*.cs" }, args)):wait()
	return result.stdout ~= "" and vim.split(vim.trim(result.stdout), "\n") or {}
end

-- Roslyn chỉ sửa chính file khi đổi namespace. Ở các file có `using <cũ>;` và dùng type vừa chuyển:
-- thêm `using <mới>;`; bỏ `using <cũ>;` khi không còn file nào khai báo namespace cũ.
local function fix_references(moves)
	local register = require("core.csharp-register")
	local root = vim.fs.root(0, ".git") or vim.fn.getcwd()
	local touched = {}
	for _, move in ipairs(moves) do
		local escaped = vim.pesc(move.old):gsub("%%", "\\")
		local old_alive = #rg_list({ "^namespace\\s+" .. escaped .. "\\s*;", root }) > 0
		for _, file in ipairs(rg_list({ "^using\\s+" .. escaped .. "\\s*;", root })) do
			local lines = read(file)
			local text = table.concat(lines, "\n")
			local uses = false
			for name in pairs(move.types) do
				if text:find("%f[%w_]" .. name .. "%f[^%w_]") then
					uses = true
				end
			end
			if uses or not old_alive then
				local buf = vim.fn.bufadd(file)
				vim.fn.bufload(buf)
				if uses then
					register.ensure_using(buf, move.new)
				end
				if not old_alive then
					for index, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
						local bom = line:match("^\239\187\191") or ""
						if line:sub(#bom + 1) == "using " .. move.old .. ";" then
							local next_line = vim.api.nvim_buf_get_lines(buf, index, index + 1, false)[1]
							vim.api.nvim_buf_set_lines(buf, index - 1, index, false, {})
							if bom ~= "" and next_line then
								vim.api.nvim_buf_set_lines(buf, index - 1, index, false, { bom .. next_line })
							end
							break
						end
					end
				end
				if vim.bo[buf].modified then
					vim.api.nvim_buf_call(buf, function()
						vim.cmd("silent noautocmd write")
					end)
					touched[vim.fn.fnamemodify(file, ":.")] = true
				end
			end
		end
	end
	return vim.tbl_keys(touched)
end

function M.sync_namespace(path)
	local files
	if path and path ~= "" then
		local dir = vim.fn.fnamemodify(path, ":p")
		files = vim.fs.find(function(name, parent)
			return name:match("%.cs$") and not parent:match("/bin/") and not parent:match("/obj/")
		end, { path = dir, type = "file", limit = math.huge })
		table.sort(files)
	else
		files = { vim.api.nvim_buf_get_name(0) }
	end
	local changed, moves = {}, {}
	each_file(files, function(file, next)
		with_buffer(file, function(buf)
			local row, col = first_line(buf, "^\239?\187?\191?namespace%s+()")
			if not row then
				return next()
			end
			local old = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]:match("namespace%s+([%w_.]+)")
			M.apply(buf, line_range(row, col), { "^Change namespace to" }, function(title)
				if title then
					local new = title:match("'(.-)'")
					table.insert(changed, vim.fn.fnamemodify(file, ":t") .. " → " .. new)
					table.insert(moves, { old = old, new = new, types = declared_types(file) })
				end
				next()
			end)
		end)
	end, function()
		local references = fix_references(moves)
		vim.notify(
			("CsSyncNamespace: %d/%d file đổi namespace%s%s"):format(
				#changed,
				#files,
				#changed > 0 and ("\n" .. table.concat(changed, "\n")) or "",
				#references > 0 and ("\nsửa using: " .. table.concat(references, ", ")) or ""
			)
		)
	end)
end

local type_nodes = {
	class_declaration = true,
	record_declaration = true,
	struct_declaration = true,
	interface_declaration = true,
	enum_declaration = true,
}

-- Type đầu tiên nằm trong dòng [first, last] (0-based); nil nếu không có
local function type_in(buf, first, last)
	local ok, parser = pcall(vim.treesitter.get_parser, buf, "c_sharp")
	if not ok or not parser then
		return nil
	end
	local found
	local function visit(node)
		if found then
			return
		end
		local start_row, _, end_row = node:range()
		if end_row < first or start_row > last then
			return
		end
		if type_nodes[node:type()] and start_row >= first then
			found = node
			return
		end
		for child in node:iter_children() do
			visit(child)
		end
	end
	visit(parser:parse()[1]:root())
	return found
end

function M.move_type(first, last)
	local buf = vim.api.nvim_get_current_buf()
	local node = type_in(buf, first, last)
	if not node then
		return vim.notify(
			"CsMoveType: vùng chọn không có class/record/interface/enum. Với câu lệnh, dùng <leader>ga → Extract method",
			vim.log.levels.WARN
		)
	end
	local name = node:field("name")[1]
	local row, col = name:range()
	local range = { start = { line = row, character = col }, ["end"] = { line = row, character = col } }
	M.apply(buf, range, { "^Move type to ", "^Extract '.-' to a new file" }, function(title, err)
		if title then
			vim.notify("CsMoveType: " .. title)
		else
			vim.notify(
				"CsMoveType: Roslyn không có action chuyển type này"
					.. (
						err and (" (" .. err .. ")")
						or " (type trùng tên file, hoặc là type lồng trong class khác)"
					),
				vim.log.levels.WARN
			)
		end
	end)
end

vim.api.nvim_create_user_command("CsOrganizeUsings", function()
	M.organize_usings()
end, { desc = "Roslyn: remove unnecessary usings + sort usings" })

vim.api.nvim_create_user_command("CsSyncNamespace", function(opts)
	M.sync_namespace(opts.args)
end, { nargs = "?", complete = "dir", desc = "Roslyn: change namespace to match folder (file or every .cs in dir)" })

vim.api.nvim_create_user_command("CsMoveType", function(opts)
	M.move_type(opts.line1 - 1, opts.line2 - 1)
end, { range = true, desc = "Roslyn: move type in selection to its own file" })

return M
