return {
	"Mofiqul/dracula.nvim",
	name = "dracula",
	priority = 1000,
	config = function()
		require("dracula").setup({
			-- customize dracula color palette
			colors = {
				bg = "none",
				fg = "#f8f8f2",
				selection = "#44475a",
				comment = "#6272a4",
				red = "#ff5555",
				orange = "#ffb86c",
				yellow = "#f1fa8c",
				green = "#50fa7b",
				purple = "#bd93f9",
				cyan = "#8be9fd",
				pink = "#ff79c6",
				bright_red = "#ff6e6e",
				bright_green = "#69ff94",
				bright_yellow = "#ffffa5",
				bright_blue = "#d6acff",
				bright_magenta = "#ff92df",
				bright_cyan = "#a4ffff",
				bright_white = "#ffffff",
				menu = "#282a36",
				visual = "#3e4452",
				gutter_fg = "#4b5263",
				nontext = "#3b4048",
				white = "#f8f8f2",
				black = "#282a36",
			},
			-- show the '~' characters after the end of buffers
			show_end_of_buffer = true, -- default false
			-- use transparent background
			transparent_bg = true, -- default false
			-- set custom lualine background color
			lualine_bg_color = nil, -- default nil
			-- set italic comment
			italic_comment = true, -- default false
			-- overrides the default highlights with table see `:h synIDattr`
			overrides = {
				-- NvimTree
				NvimTreeNormal = { bg = "NONE" },
				NvimTreeNormalNC = { bg = "NONE" },
				NvimTreeWinSeparator = { bg = "NONE", fg = "#44475a" },
				NvimTreeEndOfBuffer = { bg = "NONE" },
				
				-- Telescope
				TelescopeNormal = { bg = "NONE" },
				TelescopeBorder = { bg = "NONE" },
				TelescopePromptNormal = { bg = "NONE" },
				TelescopePromptBorder = { bg = "NONE" },
				TelescopeResultsNormal = { bg = "NONE" },
				TelescopeResultsBorder = { bg = "NONE" },
				TelescopePreviewNormal = { bg = "NONE" },
				TelescopePreviewBorder = { bg = "NONE" },

				-- General Floating Windows
				NormalFloat = { bg = "NONE" },
				FloatBorder = { bg = "NONE" },
				
				-- Completion Menu (cmp)
				Pmenu = { bg = "NONE" },
				PmenuSel = { bg = "#44475a" },
				PmenuSbar = { bg = "NONE" },
				PmenuThumb = { bg = "#44475a" },

				-- Trouble
				TroubleNormal = { bg = "NONE" },
				TroubleNormalNC = { bg = "NONE" },
				
				-- WhichKey / Others
				WhichKeyFloat = { bg = "NONE" },

				-- LSP / Roslyn References & Inlay Hints
				LspCodeLens = { fg = "#6272a4", italic = true },
				LspInlayHint = { fg = "#6272a4", italic = true },
			},
			-- You can use overrides as a function to have access to the colors
			-- overrides = function (colors)
			--   return {
			--     NonText = { fg = white, bg = black },
			--   }
			-- end,
		})

		vim.cmd.colorscheme("dracula")
	end,
}
