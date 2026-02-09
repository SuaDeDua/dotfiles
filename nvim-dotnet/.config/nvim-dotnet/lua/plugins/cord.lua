return {
	"vyfor/cord.nvim",
	build = ":Cord update",
	opts = {
		display = {
			show_repository = false, -- Hide repository button
			show_cursor_position = true, -- Show cursor position
		},
		text = {
			viewing = "Viewing", -- Hide filename
			editing = "Editing", -- Hide filename
			file_browser = "Browsing files", -- Hide workspace/folder
			plugin_manager = "Managing plugins",
			lsp_manager = "Configuring LSP",
			vcs_manager = "Committing changes",
			workspace = "In Neovim", -- Hide workspace/folder name
		},
	},
}
