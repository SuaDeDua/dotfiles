-- Treesitter main uses the new API (Neovim 0.12+).
return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	lazy = false,
	dependencies = { "nvim-treesitter/nvim-treesitter-textobjects" },
	build = ":TSUpdate",
	config = function()
		local ts = require("nvim-treesitter")
		ts.setup({})
		ts.install({ "java", "lua", "markdown", "markdown_inline", "bash", "hurl", "c_sharp" })

		local group = vim.api.nvim_create_augroup("UserTreesitter", { clear = true })
		vim.api.nvim_create_autocmd("FileType", {
			group = group,
			callback = function(ev)
				-- Apply after the built-in ftplugin/indent scripts finish.
				vim.schedule(function()
					if not vim.api.nvim_buf_is_valid(ev.buf) or vim.bo[ev.buf].filetype ~= ev.match then
						return
					end
					local lang = vim.treesitter.language.get_lang(ev.match)
					if not lang then
						return
					end
					-- Keep the filetype's own indent rules when no parser/query is available.
					local ok = pcall(vim.treesitter.start, ev.buf, lang)
					if ok and vim.treesitter.query.get(lang, "indents") then
						vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
					end
				end)
			end,
		})
	end,
}
