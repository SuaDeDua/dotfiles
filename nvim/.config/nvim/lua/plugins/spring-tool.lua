return {
	{
		"jkeresman01/spring-initializr.nvim",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"MunifTanjim/nui.nvim",
			"nvim-telescope/telescope.nvim",
		},
		config = function()
			require("spring-initializr").setup()
		end,
	},
	{
		"DevDad-Main/spring-tools.nvim",
		-- Telescope is optional — falls back to vim.ui.select
		dependencies = {
			"nvim-telescope/telescope.nvim",
		},
		config = function()
			require("spring-tools").setup({
				sidebar = {
					position = "right",
					keymaps = {
						move_down = "e",
						move_up = "i",
					},
				},
				output = {
					keymaps = {
						filter_error = "j",
						filter_warn = "k",
					},
				},
			})
		end,
	},
}
