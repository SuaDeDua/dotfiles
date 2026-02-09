return {
    "stevearc/conform.nvim",
    config = function()
        require("conform").setup({
            format_on_save = {
                -- Nên tăng timeout lên 1000ms vì C# khởi động tool hơi chậm
                timeout_ms = 1000, 
                lsp_format = "fallback",
            },
            formatters_by_ft = {
                lua = { "stylua" },
                cs = { "csharpier" }, -- Conform tự biết cách gọi csharpier chuẩn
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
