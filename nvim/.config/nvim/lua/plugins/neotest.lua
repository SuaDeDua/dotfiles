return {
	{
		"rcasia/neotest-java",
		ft = "java",
		dependencies = {
			"mfussenegger/nvim-jdtls",
			"mfussenegger/nvim-dap", -- for debugging (optional)
			"rcarriga/nvim-dap-ui", -- recommended
			"theHamsta/nvim-dap-virtual-text", -- recommended
		},
	},
	{
		"nvim-neotest/neotest",
		dependencies = {
			"nvim-neotest/nvim-nio",
			"nvim-lua/plenary.nvim",
			"nvim-treesitter/nvim-treesitter",
		},
		config = function()
			require("neotest").setup({
				adapters = {
					require("neotest-java")({
						ignore_statements = { "public static void main" },
					}),
				},
				floating = {
					border = "rounded",
					max_height = 0.8,
					max_width = 0.8,
					options = {
						wrap = true,
					},
				},
				summary = {
					animated = true,
				},
				output = { open_on_run = true },
			})
		end,
	},
}
