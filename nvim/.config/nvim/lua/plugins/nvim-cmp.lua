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
		-- 1. Cấu hình Phím tắt (Keymaps) y hệt thói quen cũ của bạn
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
			menu = { border = "rounded" },
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
