-- Navigate nvim and tmux windows/panels with vim bindings
return {
	-- https://github.com/christoomey/vim-tmux-navigator
	"christoomey/vim-tmux-navigator",
	-- Only load this plugin if tmux is being used
	event = function()
		if vim.fn.exists("$TMUX") == 1 then
			return "VeryLazy"
		end
	end,
	cmd = {
		"TmuxNavigateLeft",
		"TmuxNavigateDown",
		"TmuxNavigateUp",
		"TmuxNavigateRight",
		"TmuxNavigatePrevious",
		"TmuxNavigatorProcessList",
	},
	keys = {
		{ "<c-n>", "<cmd>TmuxNavigateLeft<cr>" },
		{ "<c-e>", "<cmd>TmuxNavigateDown<cr>" },
		{ "<c-i>", "<cmd>TmuxNavigateUp<cr>" },
		{ "<c-o>", "<cmd>TmuxNavigateRight<cr>" },
		{ "<c-\\>", "<cmd>TmuxNavigatePrevious<cr>" },
	},
}
