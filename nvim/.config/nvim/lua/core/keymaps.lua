SSE_SERVER_ID = 0
JOB_ID = 0
-- Set leader key to space
vim.g.mapleader = " "

local keymap = vim.keymap

-- Keymap colemak D-H
keymap.set({ "n", "x", "o" }, "j", "i")
keymap.set({ "n", "x", "o" }, "J", "I")
keymap.set({ "n", "x", "o" }, ";", "o")

-- motion keys (left, down, up, right)
keymap.set({ "n", "x", "o" }, "n", "h")
keymap.set({ "n", "x", "o" }, "e", "j")
keymap.set({ "n", "x", "o" }, "i", "k")
keymap.set({ "n", "x", "o" }, "o", "l")

-- General keymaps
keymap.set("n", "<leader>wq", ":wq<CR>") -- save and quit
keymap.set("n", "<leader>qq", ":q!<CR>") -- quit without saving
keymap.set("n", "<leader>ww", ":w<CR>") -- save
keymap.set("n", "gx", ":!open <c-r><c-a><CR>") -- open URL under cursor
keymap.set("v", "E", ":m '>+1<CR>gv=gv") -- moves lines down in visual selection
keymap.set("v", "I", ":m '<-2<CR>gv=gv") -- moves lines up in visual selection
keymap.set("n", "l", "nzzzv") -- jump to next search
keymap.set("n", "L", "Nzzzv") -- jump to prev search

-- Split window management
keymap.set("n", "<leader>sv", "<C-w>v") -- split window vertically
keymap.set("n", "<leader>sh", "<C-w>s") -- split window horizontally
keymap.set("n", "<leader>se", "<C-w>=") -- make split windows equal width
keymap.set("n", "<leader>sx", ":close<CR>") -- close split window
keymap.set("n", "<leader>sj", "<C-w>-") -- make split window height shorter
keymap.set("n", "<leader>sk", "<C-w>+") -- make split windows height taller
keymap.set("n", "<leader>sl", "<C-w>>5") -- make split windows width bigger
keymap.set("n", "<leader>sh", "<C-w><5") -- make split windows width smaller

-- Tab management
keymap.set("n", "<leader>to", ":tabnew<CR>") -- open a new tab
keymap.set("n", "<leader>tx", ":tabclose<CR>") -- close a tab
keymap.set("n", "<leader>tn", ":tabn<CR>") -- next tab
keymap.set("n", "<leader>tp", ":tabp<CR>") -- previous tab

-- Folding keymaps (quality-of-life)
keymap.set("n", "zO", "zR", { desc = "Open all folds" })
keymap.set("n", "zC", "zM", { desc = "Close all folds" })
keymap.set("n", "za", "za", { desc = "Toggle fold under cursor" })
keymap.set("n", "zc", "zc", { desc = "Close fold under cursor" })
keymap.set("n", "zo", "zo", { desc = "Open fold under cursor" })
keymap.set("n", "[z", "zp", { desc = "Jump to previous fold" })
keymap.set("n", "]z", "zn", { desc = "Jump to next fold" })

-- Diff keymaps
keymap.set("n", "<leader>vo", ":DiffviewOpen<CR>") -- open diffview
keymap.set("n", "<leader>vc", ":DiffviewClose<CR>") -- close diffview
keymap.set("n", "<leader>cc", ":diffput<CR>") -- put diff from current to other during diff
keymap.set("n", "<leader>cj", ":diffget 1<CR>") -- get diff from left (local) during merge
keymap.set("n", "<leader>ck", ":diffget 3<CR>") -- get diff from right (remote) during merge
keymap.set("n", "<leader>cn", "]c") -- next diff hunk
keymap.set("n", "<leader>cp", "[c") -- previous diff hunk

-- Quickfix keymaps
keymap.set("n", "<leader>qo", ":copen<CR>") -- open quickfix list
keymap.set("n", "<leader>qf", ":cfirst<CR>") -- jump to first quickfix list item
keymap.set("n", "<leader>qn", ":cnext<CR>") -- jump to next quickfix list item
keymap.set("n", "<leader>qp", ":cprev<CR>") -- jump to prev quickfix list item
keymap.set("n", "<leader>ql", ":clast<CR>") -- jump to last quickfix list item
keymap.set("n", "<leader>qc", ":cclose<CR>") -- close quickfix list

-- Vim-maximizer
keymap.set("n", "<leader>sm", ":MaximizerToggle<CR>") -- toggle maximize tab

-- Telescope
keymap.set("n", "<leader>ff", function()
	require("telescope.builtin").find_files({ file_ignore_patterns = { "Test.java$", "spec.ts$" } })
end) -- fuzzy find files in project
keymap.set("n", "<leader>fF", require("telescope.builtin").find_files, {}) -- fuzzy find files in project
keymap.set("n", "<leader>fg", function()
	require("telescope.builtin").live_grep({ file_ignore_patterns = { "Test.java$", "spec.ts$" } })
end) -- grep file contents in project
keymap.set("n", "<leader>fG", require("telescope.builtin").live_grep, {}) -- grep file contents in project
keymap.set("n", "<leader>fb", require("telescope.builtin").buffers, {}) -- fuzzy find open buffers
keymap.set("n", "<leader>fh", require("telescope.builtin").help_tags, {}) -- fuzzy find help tags
keymap.set("n", "<leader>fs", require("telescope.builtin").current_buffer_fuzzy_find, {}) -- fuzzy find in current file buffer
keymap.set("n", "<leader>fo", require("telescope.builtin").lsp_document_symbols, {}) -- fuzzy find LSP/class symbols
keymap.set("n", "<leader>fi", function()
	require("telescope.builtin").lsp_incoming_calls({ file_ignore_patterns = { "Test.java$", "spec.ts$" } })
end)
keymap.set("n", "<leader>fI", require("telescope.builtin").lsp_incoming_calls, {}) -- fuzzy find LSP/incoming calls
-- Fuzzy find jumplist (and filter duplicate files)
keymap.set("n", "<leader>fj", function()
	local jumplist = vim.fn.getjumplist()[1]
	local jumps = {}
	local seen = {}
	local cwd = vim.fn.getcwd()

	-- Collect unique jumps (iterate backward, most recent duplicates win)
	for idx = #jumplist, 1, -1 do
		local jump = jumplist[idx]
		if jump.bufnr and jump.bufnr ~= 0 then
			local fname = vim.api.nvim_buf_get_name(jump.bufnr)
			if fname ~= "" and fname:sub(1, #cwd) == cwd and not fname:find("NvimTree_1") and not seen[fname] then
				seen[fname] = true
				table.insert(jumps, {
					filename = fname,
					bufnr = jump.bufnr,
					lnum = jump.lnum or 1,
					col = jump.col or 1,
				})
			end
		end
	end

	local entry_display = require("telescope.pickers.entry_display")
	local displayer = entry_display.create({
		separator = " ",
		items = { { remaining = true }, { hl = "Comment" } },
	})

	require("telescope.pickers")
		.new({}, {
			prompt_title = "Jumplist",
			finder = require("telescope.finders").new_table({
				results = jumps,
				entry_maker = function(entry)
					local basename = vim.fn.fnamemodify(entry.filename, ":t")
					local dirname = vim.fn.fnamemodify(entry.filename, ":h")
					-- Reverse directory path
					local parts = {}
					for part in string.gmatch(dirname, "[^/]+") do
						table.insert(parts, 1, part)
					end
					local reversed_path = "/" .. table.concat(parts, "/")

					return {
						value = entry,
						display = function()
							return displayer({ basename, { reversed_path, "Comment" } })
						end,
						ordinal = basename .. reversed_path,
						filename = entry.filename,
						bufnr = entry.bufnr,
						lnum = entry.lnum,
						col = entry.col,
					}
				end,
			}),
			previewer = require("telescope.previewers").vim_buffer_cat.new({
				get_buffer_by_name = function(entry)
					return entry.bufnr
				end,
				get_line = function(entry)
					return entry.lnum
				end,
			}),
			sorter = require("telescope.config").values.generic_sorter({}),
			attach_mappings = function(_, map)
				map("i", "<CR>", function(prompt_bufnr)
					local selection = require("telescope.actions.state").get_selected_entry()
					require("telescope.actions").close(prompt_bufnr)
					vim.api.nvim_set_current_buf(selection.bufnr)
					vim.api.nvim_win_set_cursor(0, { selection.lnum, selection.col })
				end)
				return true
			end,
		})
		:find()
end)
keymap.set("n", "<leader>fJ", require("telescope.builtin").jumplist, {}) -- fuzzy find jumplist

keymap.set("n", "<leader>fm", function()
	require("telescope.builtin").treesitter({ symbols = { "function", "method" } })
end) -- fuzzy find methods in current class
keymap.set("n", "<leader>ft", function() -- grep file contents in current nvim-tree node
	local success, node = pcall(function()
		return require("nvim-tree.lib").get_node_at_cursor()
	end)
	if not success or not node then
		return
	end
	require("telescope.builtin").live_grep({ search_dirs = { node.absolute_path } })
end)

-- Git-blame
keymap.set("n", "<leader>gb", ":GitBlameToggle<CR>") -- toggle git blame

-- LLM
keymap.set({ "n", "v" }, "<leader>cc", ":CodeCompanionChat<CR>") -- chat
keymap.set({ "n", "v" }, "<leader>ci", ":CodeCompanion<CR>") -- inline edit
keymap.set({ "n", "v" }, "<leader>ca", ":CodeCompanionActions<CR>") -- actions palette

-- Harpoon
-- keymap.set("n", "<leader>ha", require("harpoon.mark").add_file)
-- keymap.set("n", "<leader>hh", require("harpoon.ui").toggle_quick_menu)
-- keymap.set("n", "<leader>h1", function() require("harpoon.ui").nav_file(1) end)
-- keymap.set("n", "<leader>h2", function() require("harpoon.ui").nav_file(2) end)
-- keymap.set("n", "<leader>h3", function() require("harpoon.ui").nav_file(3) end)
-- keymap.set("n", "<leader>h4", function() require("harpoon.ui").nav_file(4) end)
-- keymap.set("n", "<leader>h5", function() require("harpoon.ui").nav_file(5) end)
-- keymap.set("n", "<leader>h6", function() require("harpoon.ui").nav_file(6) end)
-- keymap.set("n", "<leader>h7", function() require("harpoon.ui").nav_file(7) end)
-- keymap.set("n", "<leader>h8", function() require("harpoon.ui").nav_file(8) end)
-- keymap.set("n", "<leader>h9", function() require("harpoon.ui").nav_file(9) end)

-- Vim REST Console
keymap.set("n", "<leader>xr", ":call VrcQuery()<CR>") -- Run REST query

-- LSP
keymap.set("n", "<leader>gg", "<cmd>lua vim.lsp.buf.hover()<CR>")
keymap.set("n", "<leader>gd", "<cmd>lua vim.lsp.buf.definition()<CR>")
keymap.set("n", "<leader>gD", "<cmd>lua vim.lsp.buf.declaration()<CR>")
keymap.set("n", "<leader>gi", "<cmd>lua vim.lsp.buf.implementation()<CR>")
keymap.set("n", "<leader>gt", "<cmd>lua vim.lsp.buf.type_definition()<CR>")
keymap.set("n", "<leader>gr", "<cmd>lua vim.lsp.buf.references()<CR>")
keymap.set("n", "<leader>gs", "<cmd>lua vim.lsp.buf.signature_help()<CR>")
keymap.set("n", "<leader>rr", "<cmd>lua vim.lsp.buf.rename()<CR>")
keymap.set("n", "<leader>gf", "<cmd>lua vim.lsp.buf.format({async = true})<CR>")
keymap.set("v", "<leader>gf", "<cmd>lua vim.lsp.buf.format({async = true})<CR>")
keymap.set("n", "<leader>ga", "<cmd>lua vim.lsp.buf.code_action()<CR>")
keymap.set("n", "<leader>gl", "<cmd>lua vim.diagnostic.open_float()<CR>")
keymap.set("n", "<leader>gp", "<cmd>lua vim.diagnostic.goto_prev()<CR>")
keymap.set("n", "<leader>gn", "<cmd>lua vim.diagnostic.goto_next()<CR>")
keymap.set("n", "<leader>tr", "<cmd>lua vim.lsp.buf.document_symbol()<CR>")
keymap.set("i", "<C-Space>", "<cmd>lua vim.lsp.buf.completion()<CR>")

-- Filetype-specific keymaps (these can be done in the ftplugin directory instead if you prefer)
keymap.set("n", "<leader>go", function()
	if vim.bo.filetype == "java" then
		require("jdtls").organize_imports()
	elseif vim.bo.filetype == "python" then
		vim.api.nvim_command("PyrightOrganizeImports")
	end
end)

keymap.set("n", "<leader>gu", function()
	if vim.bo.filetype == "java" then
		require("jdtls").update_projects_config()
	end
end)

keymap.set("n", "<leader>tc", function()
	if vim.bo.filetype == "java" then
		require("jdtls").test_class()
	elseif vim.bo.filetype == "python" then
		require("dap-python").test_class()
	end
end)

keymap.set("n", "<leader>tm", function()
	if vim.bo.filetype == "java" then
		require("jdtls").test_nearest_method()
	elseif vim.bo.filetype == "python" then
		require("dap-python").test_method()
	end
end)

-- Debugging
keymap.set("n", "<leader>bb", "<cmd>lua require'dap'.toggle_breakpoint()<cr>")
keymap.set("n", "<leader>bc", "<cmd>lua require'dap'.set_breakpoint(vim.fn.input('Breakpoint condition: '))<cr>")
keymap.set("n", "<leader>bl", "<cmd>lua require'dap'.set_breakpoint(nil, nil, vim.fn.input('Log point message: '))<cr>")
keymap.set("n", "<leader>br", "<cmd>lua require'dap'.clear_breakpoints()<cr>")
keymap.set("n", "<leader>ba", "<cmd>Telescope dap list_breakpoints<cr>")
keymap.set("n", "<leader>dc", "<cmd>lua require'dap'.continue()<cr>")
keymap.set("n", "<leader>dj", "<cmd>lua require'dap'.step_over()<cr>")
keymap.set("n", "<leader>dk", "<cmd>lua require'dap'.step_into()<cr>")
keymap.set("n", "<leader>do", "<cmd>lua require'dap'.step_out()<cr>")
keymap.set("n", "<leader>dd", function()
	require("dap").disconnect()
	require("dapui").close()
end)
keymap.set("n", "<leader>dt", function()
	require("dap").terminate()
	require("dapui").close()
end)
keymap.set("n", "<leader>dr", "<cmd>lua require'dap'.repl.toggle()<cr>")
keymap.set("n", "<leader>dl", "<cmd>lua require'dap'.run_last()<cr>")
keymap.set("n", "<leader>di", function()
	require("dap.ui.widgets").hover()
end)
keymap.set("n", "<leader>d?", function()
	local widgets = require("dap.ui.widgets")
	widgets.centered_float(widgets.scopes)
end)
keymap.set("n", "<leader>df", "<cmd>Telescope dap frames<cr>")
keymap.set("n", "<leader>dh", "<cmd>Telescope dap commands<cr>")
keymap.set("n", "<leader>de", function()
	require("telescope.builtin").diagnostics({ default_text = ":E:" })
end)

-- ctrl c as escape cuz Im lazy to reach up to the esc key
-- vim.keymap.set("i", "<C-c>", "<Esc>")
vim.keymap.set("n", "<Esc>", ":nohl<CR>", {
	desc = "Clear search hl",
	silent = true,
})

-- java run
vim.keymap.set("n", "<F5>", ":!java %<CR>", { desc = "Run Java file", silent = false })
