return {
	"saghen/blink.cmp",
	-- BẮT BUỘC: Sử dụng version = '*' để Blink tự động tải lõi Rust đã biên dịch sẵn
	-- (Bạn sẽ không cần phải tự cài Rust trên máy Mac)
	version = "*",

	dependencies = {
		-- Vẫn cần gói này để lấy bộ dữ liệu Snippets có sẵn
		"rafamadriz/friendly-snippets",
		"olimorris/codecompanion.nvim",
	},
	opts = {
		cmdline = {
			enabled = true,
			-- use 'inherit' to inherit mappings from top level `keymap` config
			keymap = { preset = "cmdline" },
			sources = { "buffer", "cmdline" },

			-- OR explicitly configure per cmd type
			-- This ends up being equivalent to above since the sources disable themselves automatically
			-- when not available. You may override their `enabled` functions via
			-- `sources.providers.cmdline.override.enabled = function() return your_logic end`

			-- sources = function()
			--   local type = vim.fn.getcmdtype()
			--   -- Search forward and backward
			--   if type == '/' or type == '?' then return { 'buffer' } end
			--   -- Commands
			--   if type == ':' or type == '@' then return { 'cmdline', 'buffer' } end
			--   return {}
			-- end,

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
					min_width = 120,
					max_width = 120,
					auto_show = function(ctx, _)
						return ctx.mode == "cmdwin"
					end,
				},
				-- Displays a preview of the selected item on the current line
				ghost_text = { enabled = true },
			},
		},
		keymap = {
			preset = "none", -- Tắt phím tắt mặc định để tự set

			["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
			["<CR>"] = { "accept", "fallback" },

			-- Tab/S-Tab để chọn item và nhảy qua lại giữa các tham số (arguments) của Snippet
			["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
			["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },

			-- C-j và C-k để di chuyển lên xuống
			["<C-j>"] = { "select_next", "fallback" },
			["<C-k>"] = { "select_prev", "fallback" },

			-- C-b và C-f để cuộn cửa sổ đọc document
			["<C-b>"] = { "scroll_documentation_up", "fallback" },
			["<C-f>"] = { "scroll_documentation_down", "fallback" },
		},

		-- 2. Cấu hình Giao diện có viền (Bordered) giống cấu hình cũ
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

		-- 3. Cấu hình Nguồn dữ liệu (Sources)
		-- Blink tích hợp sẵn lsp, path, snippets, buffer ở bên trong, không cần cài thêm plugin ngoài
		sources = {
			default = { "lsp", "path", "snippets", "buffer", "codecompanion" },
			providers = {
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
