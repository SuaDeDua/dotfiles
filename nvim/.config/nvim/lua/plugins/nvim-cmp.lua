return {
	"saghen/blink.cmp",
	version = "*",

	dependencies = {
		"rafamadriz/friendly-snippets",
		"olimorris/codecompanion.nvim",
		{
			"L3MON4D3/LuaSnip",
			version = "v2.*",
			config = function()
				require("luasnip.loaders.from_vscode").lazy_load()
				require("luasnip.loaders.from_lua").lazy_load({
					paths = { vim.fn.stdpath("config") .. "/lua/snippets" },
				})
			end,
		},
	},
	opts = {
		snippets = {
			preset = "luasnip",
		},
		cmdline = {

			enabled = true,
			-- use 'inherit' to inherit mappings from top level `keymap` config
			keymap = {
				preset = "cmdline",
				-- Insert the selected preview as well as opening the menu.
				["<Tab>"] = { "show_and_insert_or_accept_single", "select_next", "fallback" },
				["<S-Tab>"] = {
					function(cmp)
						return cmp.show_and_insert_or_accept_single({ initial_selected_item_idx = -1 })
					end,
					"select_prev",
					"fallback",
				},
				["<C-e>"] = { "show_and_insert_or_accept_single", "select_next", "fallback" },
				["<C-i>"] = {
					function(cmp)
						return cmp.show_and_insert_or_accept_single({ initial_selected_item_idx = -1 })
					end,
					"select_prev",
					"fallback",
				},
			},
			-- sources = { "buffer", "cmdline" },

			-- OR explicitly configure per cmd type
			-- This ends up being equivalent to above since the sources disable themselves automatically
			-- when not available. You may override their `enabled` functions via
			-- `sources.providers.cmdline.override.enabled = function() return your_logic end,

			sources = function()
				local type = vim.fn.getcmdtype()
				-- Search forward and backward
				if type == "/" or type == "?" then
					return { "buffer" }
				end
				-- Commands
				if type == ":" or type == "@" then
					return { "cmdline", "buffer" }
				end
				return {}
			end,

			completion = {
				trigger = {
					show_on_blocked_trigger_characters = {},
					show_on_x_blocked_trigger_characters = {},
				},
				list = {
					selection = {
						-- When `true`, will automatically select the first item in the completion list
						preselect = true,
						-- When `true`, inserts the completion item automatically when selecting it
						auto_insert = true,
					},
				},
				-- Whether to automatically show the window when new completion items are available
				-- Default is false for cmdline, true for cmdwin (command-line window)
				menu = {
					auto_show = function(ctx, _)
						return ctx.mode == "cmdwin"
					end,
				},
				-- Displays a preview of the selected item on the current line
				ghost_text = { enabled = true },
			},
		},
		keymap = {
			preset = "none",
			["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
			["<CR>"] = { "accept", "fallback" },

			-- Menu navigation first; jump snippet arguments when the menu is closed.
			["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
			["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },

			-- Colemak D-H: e = down, i = up (requires extended terminal keys for C-i).
			["<C-e>"] = { "select_next", "snippet_forward", "fallback" },
			["<C-i>"] = { "select_prev", "snippet_backward", "fallback" },

			-- C-j và C-k để di chuyển lên xuống
			["<C-j>"] = { "select_next", "fallback" },
			["<C-k>"] = { "select_prev", "fallback" },

			-- C-b và C-f để cuộn cửa sổ đọc document
			["<C-b>"] = { "scroll_documentation_up", "fallback" },
			["<C-f>"] = { "scroll_documentation_down", "fallback" },
		},

		signature = { enabled = true, window = { border = "rounded" } },

		completion = {
			menu = {
				border = "rounded",
				direction_priority = function()
					local ctx = require("blink.cmp").get_context()
					local item = require("blink.cmp").get_selected_item()
					if ctx == nil or item == nil then
						return { "s", "n" }
					end

					local item_text = item.textEdit ~= nil and item.textEdit.newText or item.insertText or item.label
					local is_multi_line = item_text:find("\n") ~= nil

					-- after showing the menu upwards, we want to maintain that direction
					-- until we re-open the menu, so store the context id in a global variable
					if is_multi_line or vim.g.blink_cmp_upwards_ctx_id == ctx.id then
						vim.g.blink_cmp_upwards_ctx_id = ctx.id
						return { "n", "s" }
					end
					return { "s", "n" }
				end,
			},
			documentation = { auto_show = true, window = { border = "rounded" } },
		},

		sources = {
			default = { "lsp", "path", "snippets", "buffer", "codecompanion" },
			providers = {
				lsp = {
					transform_items = function(ctx, items)
						return require("core.csharp-completion").transform_items(ctx, items)
					end,
				},
				codecompanion = {
					name = "CodeCompanion",
					module = "codecompanion.providers.completion.blink",
					enabled = true,
				},
			},
		},
	},

	opts_extend = { "sources.default" },
}
