return {
	"stevearc/conform.nvim",
	config = function()
		require("conform").setup({
			format_on_save = {
				async = false,
				timeout_ms = 1000,
				lsp_fallback = true,
			},
			formatters_by_ft = {
				lua = { "stylua" },
				java = { "google-java-format" },
				graphql = { "prettier" },
				javascript = { "prettier" },
				html = { "prettier" },
				http = { "kulala" },
			},
			-- Chỉ định nghĩa lại những tool lạ hoặc cần tham số custom
			formatters = {
				kulala = {
					command = "kulala-fmt",
					args = { "format", "$FILENAME" },
					stdin = false,
				},
				-- ĐÃ XÓA block csharpier ở đây để dùng cấu hình mặc định của plugin
			},
		})
	end,
}
