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
      "json",
      "javascript",
      "typescript",
      "tsx",
      "go",
      "yaml",
      "html",
      "css",
      "python",
      "http",
      "prisma",
      "markdown",
      "markdown_inline",
      "svelte",
      "graphql",
      "bash",
      "lua",
      "vim",
      "dockerfile",
      "gitignore",
      "query",
      "vimdoc",
      "c",
      "java",
      "rust",
      "ron",
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
},
	-- NOTE: js,ts,jsx,tsx Auto Close Tags
	{
		"windwp/nvim-ts-autotag",
		enabled = true,
		ft = { "html", "xml", "javascript", "typescript", "javascriptreact", "typescriptreact", "svelte" },
		config = function()
			-- Independent nvim-ts-autotag setup
			require("nvim-ts-autotag").setup({
				opts = {
					enable_close = true, -- Auto-close tags
					enable_rename = true, -- Auto-rename pairs
					enable_close_on_slash = false, -- Disable auto-close on trailing `</`
				},
				per_filetype = {
					["html"] = {
						enable_close = true, -- Disable auto-closing for HTML
					},
					["typescriptreact"] = {
						enable_close = true, -- Explicitly enable auto-closing (optional, defaults to `true`)
					},
				},
			})
		end,
	},
}
