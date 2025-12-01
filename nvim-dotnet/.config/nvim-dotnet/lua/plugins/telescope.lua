return {
	{
		"nvim-telescope/telescope.nvim",
		event = "VeryLazy",
		config = function()
			local builtin = require("telescope.builtin")
			vim.keymap.set("n", "<leader>fw", builtin.live_grep, {})
			vim.keymap.set("n", "<leader><leader>", builtin.find_files, {})
			vim.keymap.set("n", "<leader>fz", builtin.current_buffer_fuzzy_find, {})
			vim.keymap.set("n", "<leader>pr", "<cmd>Telescope oldfiles<CR>", { desc = "Fuzzy find recent files" })
			vim.keymap.set(
				"n",
				"<leader>ths",
				"<cmd>Telescope themes<CR>",
				{ noremap = true, silent = true, desc = "Theme Switcher" }
			)
		end,
		dependencies = { "nvim-lua/plenary.nvim" },
	},
}
