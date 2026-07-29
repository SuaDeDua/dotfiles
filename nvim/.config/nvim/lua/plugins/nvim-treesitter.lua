-- Code Tree Support / Syntax Highlighting
return {
	-- https://github.com/nvim-treesitter/nvim-treesitter
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	lazy = false,
	dependencies = {
		-- https://github.com/nvim-treesitter/nvim-treesitter-textobjects
		"nvim-treesitter/nvim-treesitter-textobjects",
	},
	build = ":TSUpdate",
	main = "nvim-treesitter.config",
	opts = {
		highlight = {
			enable = true,
		},
		indent = { enable = true },
		auto_install = true, -- automatically install syntax support when entering new file type buffer
		ensure_installed = {
			"lua",
			"comment",
		},
		ignore_install = { "csv" }, -- Using cameron-wags/rainbow_csv.nvim for CSV highlighting
	},
}
