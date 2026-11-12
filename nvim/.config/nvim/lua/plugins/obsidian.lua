return {
	"obsidian-nvim/obsidian.nvim",
	branch = "main",
	commit = "eb28dd537e930de0c2a7ea4827aaced80d37d006",
	lazy = true,
	ft = "markdown",
	event = {
		"BufReadPre " .. vim.fn.expand("~") .. "/Documents/my-second-brain/**.md",
		"BufNewFile " .. vim.fn.expand("~") .. "/Documents/my-second-brain/**.md",
	},
	cmd = { "Obsidian" },
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-telescope/telescope.nvim",
	},
	keys = {
		{ "<leader>oo", "<cmd>Obsidian quick_switch<cr>", desc = "Obsidian: Quick Switcher (Telescope)" },
		{ "<leader>os", "<cmd>Obsidian search<cr>", desc = "Obsidian: Tìm kiếm trong ghi chú" },
		{ "<leader>on", "<cmd>Obsidian new<cr>", desc = "Obsidian: Tạo ghi chú mới" },
		{ "<leader>ot", "<cmd>Obsidian today<cr>", desc = "Obsidian: Daily note hôm nay" },
		{ "<leader>oy", "<cmd>Obsidian yesterday<cr>", desc = "Obsidian: Daily note hôm qua" },
		{ "<leader>ob", "<cmd>Obsidian backlinks<cr>", desc = "Obsidian: Backlinks" },
		{ "<leader>ol", "<cmd>Obsidian links<cr>", desc = "Obsidian: Danh sách liên kết" },
		{ "<leader>op", "<cmd>Obsidian paste_img<cr>", desc = "Obsidian: Dán ảnh từ clipboard" },
		{ "<leader>ov", "<cmd>Obsidian open<cr>", desc = "Obsidian: Mở note trong ứng dụng Obsidian" },
	},
	opts = {
		legacy_commands = false,
		workspaces = {
			{
				name = "second-brain",
				path = "~/Documents/my-second-brain",
			},
		},

		-- Thư mục chứa daily notes
		daily_notes = {
			folder = "dailies",
			date_format = "YYYY-MM-DD",
			alias_format = "MMMM D, YYYY",
			default_tags = { "daily-notes" },
			template = nil,
		},

		-- Cấu hình completion tương thích với blink.cmp (thông qua LSP)
		completion = {
			min_chars = 2,
		},

		-- Dùng Telescope làm picker
		picker = {
			name = "telescope.nvim",
			note_mappings = {
				new = "<C-x>",
				insert_link = "<C-l>",
			},
		},

		-- Tắt UI của obsidian.nvim để render-markdown.nvim xử lý hiển thị tốt nhất
		ui = {
			enable = false,
		},

		-- Đặt tên file theo Title nếu có, hoặc tạo timestamp
		note_id_func = function(title)
			if title ~= nil then
				return title:gsub(" ", "-"):gsub("[^A-Za-z0-9-]", ""):lower()
			else
				return tostring(os.time())
			end
		end,

		-- Thư mục lưu ảnh dán vào
		attachments = {
			folder = "assets/imgs",
		},

		-- Buffer mappings only inside the vault; preserve Colemak D-H n/e/i/o motions.
		callbacks = {
			enter_note = function()
				vim.keymap.set("n", "gf", "<cmd>Obsidian follow_link<cr>", { buffer = true, desc = "Follow note link" })
				vim.keymap.set(
					"n",
					"<leader>ch",
					"<cmd>Obsidian toggle_checkbox<cr>",
					{ buffer = true, desc = "Toggle checkbox" }
				)
				vim.keymap.set("n", "<CR>", function()
					return require("obsidian.actions").smart_action()
				end, { buffer = true, expr = true, desc = "Note action" })
			end,
		},
	},
}
