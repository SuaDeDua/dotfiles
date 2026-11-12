# This is my config for MacOS


## Cấu hình Zsh riêng tư

Lưu API key, token và cấu hình riêng của máy trong `zsh/.zshrc.local`.
File này được `.zshrc` tự động nạp (kể cả khi IntelliJ đọc môi trường)
và đã được loại khỏi Git. Không đặt key trong các file `conf.d/*.zsh`.

Trên máy mới, chạy tại thư mục dotfiles:

```sh
cp zsh/.zshrc.local.example zsh/.zshrc.local
chmod 600 zsh/.zshrc.local
```

Điền giá trị thật vào file local bằng trình soạn thảo, rồi mở terminal mới
hoặc chạy `source ~/.zshrc`. File local chứa dữ liệu dạng văn bản thuần;
`.gitignore` chỉ ngăn Git thêm file, không mã hóa dữ liệu hay xóa key khỏi
lịch sử commit. Nếu key từng được commit/push, cần thu hồi và tạo key mới.
