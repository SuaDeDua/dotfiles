require("Lilac.core")
require("Lilac.lazy")
require("current-theme")

-- If Neovim is running in VSCode mode, load additional key mappings specific to VSCode.
if vim.g.vscode then
	require("config.lazy")
	require("editor.keymaps")
	require("editor.commands")
	require("editor.extensions")
end
