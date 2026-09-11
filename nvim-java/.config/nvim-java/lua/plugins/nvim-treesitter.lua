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
	config = function()
		require("nvim-treesitter.config").setup({
			ensure_installed = {
				"java",
				"lua",
				"markdown",
				"bash",
			},

			-- Tự động cài parser nếu bạn mở một file ngôn ngữ mới chưa có sẵn
			auto_install = true,

			-- ĐÂY LÀ PHẦN QUAN TRỌNG NHẤT: Bật tự động highlight bằng Treesitter cho mọi file
			highlight = {
				enable = true,

				-- Tắt hệ thống highlight regex cũ kĩ mặc định của Vim để nhường chỗ cho Treesitter
				additional_vim_regex_highlighting = false,
			},

			-- Bật tính năng thụt lề (indent) thông minh
			indent = { enable = true },
		})
	end,
	-- main = "nvim-treesitter.config",
	-- opts = {
	-- 	highlight = {
	-- 		enable = true,
	-- 		additional_vim_regex_highlighting = false,
	-- 	},
	-- 	indent = { enable = true },
	-- 	auto_install = true, -- automatically install syntax support when entering new file type buffer
	-- 	ensure_installed = {
	-- 		"lua",
	-- 		"comment",
	-- 		"yaml",
	-- 		"java",
	-- 	},
	-- 	ignore_install = { "csv" }, -- Using cameron-wags/rainbow_csv.nvim for CSV highlighting
	-- },
}
