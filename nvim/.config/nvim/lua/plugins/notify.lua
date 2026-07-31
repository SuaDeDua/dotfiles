-- FIX transparent background colour
return {
	"rcarriga/nvim-notify",
	keys = {
		-- Your existing keys mappings
	},
	config = function(_, opts)
		-- Merges default choices with your explicit hex code override
		require("notify").setup(vim.tbl_extend("keep", {
			background_colour = "#000000",
		}, opts))
	end,
}
