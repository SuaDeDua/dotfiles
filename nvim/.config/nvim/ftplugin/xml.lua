vim.lsp.config("lemminx", {
	cmd = { "lemminx" }, -- Bắt buộc phải có: Chỉ định lệnh khởi chạy máy chủ (Mason đã đưa nó vào PATH)
	root_markers = { "pom.xml", ".git" }, -- Bắt buộc phải có: Cách Neovim tìm thư mục gốc của project
	settings = {
		xml = {
			-- Trỏ đến thư viện từ điển của Maven
			catalogs = { "https://maven.apache.org/xsd/maven-4.0.0.xsd" },
		},
	},
})

-- Kích hoạt LSP cho file xml hiện tại
vim.lsp.enable("lemminx")
