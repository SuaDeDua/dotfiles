return {
	{
		"mistweaverco/kulala.nvim",
		keys = {
			{ "<leader>Rs", desc = "Send request" },
			{ "<leader>Ra", desc = "Send all requests" },
			{ "<leader>Rb", desc = "Open scratchpad" },
		},
		ft = { "http", "rest" },
		opts = {
			-- your configuration comes here
			debug = true,
			global_keymaps = true,
			global_keymaps_prefix = "<leader>R",
			kulala_keymaps_prefix = "",
			additional_curl_options = { "--insecure", "-A", "Mozilla/5.0" },
			display_mode = "float",
			contenttypes = {
				["application/vnd.dev-habit.hateoas+json"] = "application/json",
				["application/vnd.dev-habit.hateoas.1+json"] = "application/json",
				["application/vnd.dev-habit.hateoas.2+json"] = "application/json",
			},
		},
	},
}
