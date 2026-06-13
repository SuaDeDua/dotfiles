return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main", -- Bắt buộc trỏ sang nhánh main cho Neovim 0.12+
	lazy = false,
	build = ":TSUpdate",
	config = function()
		-- 1. Setup cơ bản (không còn dùng nvim-treesitter.configs nữa)
		require("nvim-treesitter").setup({
			install_dir = vim.fn.stdpath("data") .. "/site",
		})

		-- 2. Cài đặt các parser bạn cần
		require("nvim-treesitter").install({
			"c_sharp",
			"http",
			"json",
			"lua",
			"hurl",
			"markdown",
			"markdown_inline",
		})

		-- 3. Kích hoạt Highlight thông qua tính năng có sẵn của Neovim 0.12
		vim.api.nvim_create_autocmd("FileType", {
			pattern = "*",
			callback = function()
				pcall(vim.treesitter.start)
			end,
		})

		-- 4. Kích hoạt Indent (Thụt lề)
		vim.api.nvim_create_autocmd("FileType", {
			pattern = "*",
			callback = function()
				vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
			end,
		})
	end,
}
