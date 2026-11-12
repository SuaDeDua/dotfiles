return {
	"mfussenegger/nvim-dap-python",
	ft = "python",
	dependencies = { "mfussenegger/nvim-dap" },
	config = function()
		-- Debugger runtime is separate from the project's Python/virtualenv.
		local python = vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python"
		if vim.fn.executable(python) == 1 then
			require("dap-python").setup(python)
		elseif vim.fn.executable("debugpy-adapter") == 1 then
			require("dap-python").setup("debugpy-adapter")
		else
			vim.notify(
				"Python debugger unavailable. Run :MasonInstall debugpy, then reopen Neovim.",
				vim.log.levels.WARN
			)
		end
	end,
}
