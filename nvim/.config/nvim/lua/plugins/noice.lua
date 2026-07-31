return {
	"folke/noice.nvim",
	event = "VeryLazy",
	dependencies = {
		"MunifTanjim/nui.nvim",
		"rcarriga/nvim-notify",
	},
	opts = {
		---@type NoiceConfigViews
		views = {
			cmdline_popup = {
				backend = "popup",
				relative = "editor",
				zindex = 200,
				position = {
					row = "40%", -- 40% from top of the screen. This will position it almost at the center.
					col = "50%",
				},
				size = {
					width = 60,
					height = "auto",
				},
				win_options = {
					winhighlight = {
						Normal = "NoiceCmdlinePopup",
						FloatTitle = "NoiceCmdlinePopupTitle",
						FloatBorder = "NoiceCmdlinePopupBorder",
						IncSearch = "",
						CurSearch = "",
						Search = "",
					},
					winbar = "",
					foldenable = false,
					cursorline = false,
				},
			},
			popupmenu = {
				-- relative = 'editor', -- "'cursor'"|"'editor'"|"'win'"
				position = {
					row = "auto", -- Popup will show up below the cmdline automatically
					col = "auto",
				},
				size = {
					width = 120, -- Making this as wide as the cmdline_popup
					height = "auto",
				},
				border = {
					---@type _.NuiBorderStyle
					style = "double", -- 'double'"|"'none'"|"'rounded'"|"'shadow'"|"'single'"|"'solid'
					---@type _.NuiBorderPadding
					padding = { 0, 1 },
				},
				win_options = {
					winhighlight = {
						Normal = "NoicePopupmenu", -- Normal | NoicePopupmenu
						FloatBorder = "NoicePopupmenuBorder", -- DiagnosticInfo | NoicePopupmenuBorder
						CursorLine = "NoicePopupmenuSelected",
						PmenuMatch = "NoicePopupmenuMatch",
					},
				},
			},
		},
		cmdline = {
			view = "cmdline_popup", -- cmdline_popup, cmdline
		},
	},
}
