-- LSP Support
return {
	-- LSP Configuration
	-- https://github.com/neovim/nvim-lspconfig
	"neovim/nvim-lspconfig",
	event = "VeryLazy",
	dependencies = {
		-- LSP Management
		-- https://github.com/williamboman/mason.nvim
		{ "williamboman/mason.nvim" },
		-- https://github.com/williamboman/mason-lspconfig.nvim
		{ "williamboman/mason-lspconfig.nvim" },

		-- Auto-Install LSPs, linters, formatters, debuggers
		-- https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim
		{ "WhoIsSethDaniel/mason-tool-installer.nvim" },

		-- Useful status updates for LSP
		-- https://github.com/j-hui/fidget.nvim
		{ "j-hui/fidget.nvim", opts = {} },

		-- Additional lua configuration, makes nvim stuff amazing!
		-- https://github.com/folke/neodev.nvim
		{ "folke/neodev.nvim", opts = {} },

		-- Autocomplete
		{ "saghen/blink.cmp" },
	},
	config = function()
		require("mason").setup()
		require("mason-lspconfig").setup({
			-- Install these LSPs automatically
			ensure_installed = {
				"bashls",
				"cssls",
				"html",
				"gradle_ls",
				"groovyls",
				"lua_ls",
				"jdtls", -- Installed, but NOT auto-enabled. See automatic_enable below.
				"jsonls",
				"lemminx",
				"marksman",
				-- 'quick_lint_js',
				"ts_ls",
				"yamlls",
				"pyright",
			},
			-- Prevent jdtls from being auto-attached. Only ftplugin/java.lua should start it.
			automatic_enable = {
				exclude = { "jdtls" },
			},
		})

		require("mason-tool-installer").setup({
			-- Install these linters, formatters, debuggers automatically
			ensure_installed = {
				"java-debug-adapter",
				"java-test",
				"black",
				"debugpy",
				"flake8",
				"isort",
				"mypy",
				"pylint",
			},
		})

		-- There is an issue with mason-tools-installer running with VeryLazy, since it triggers on VimEnter which has already occurred prior to this plugin loading so we need to call install explicitly
		-- https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim/issues/39
		vim.api.nvim_command("MasonToolsInstall")

		-- local lspconfig = require('lspconfig')
		local capabilities = require("blink.cmp").get_lsp_capabilities()

		-- Call setup on each LSP server
		for _, server in ipairs(require("mason-lspconfig").get_installed_servers()) do
			-- Don't call setup for JDTLS Java LSP because it will be setup from a separate config
			if server ~= "jdtls" then
				vim.lsp.config(server, {
					capabilities = capabilities,
				})
			end
		end

		-- Lua LSP settings
		vim.lsp.config("lua_ls", {
			settings = {
				Lua = {
					diagnostics = {
						globals = { "vim" },
					},
				},
			},
			capabilities = capabilities,
		})

		-- Disable default JDTLS so that ftplugin/java.lua will be the only jdtls instance
		vim.lsp.enable("jdtls", false)

		-- Globally configure all LSP floating preview popups (like hover, signature help, etc)
		local open_floating_preview = vim.lsp.util.open_floating_preview
		function vim.lsp.util.open_floating_preview(contents, syntax, opts, ...)
			opts = opts or {}
			opts.border = opts.border or "rounded" -- Set border to rounded
			return open_floating_preview(contents, syntax, opts, ...)
		end
	end,
}
