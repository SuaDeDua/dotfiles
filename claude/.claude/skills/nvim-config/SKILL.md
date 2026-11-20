---
name: nvim-config
description: Sửa, thêm hoặc debug cấu hình Neovim của người dùng (dotfiles, symlink tới ~/.config/nvim) — keymap Colemak, completion C# Roslyn/Blink, LuaSnip snippet, formatter Conform/Mason, lệnh Lua tùy biến như :SqlFormat/:SqlSelect. Dùng bất cứ khi nào người dùng muốn nvim làm được gì đó mới, hỏi phím tắt/motion, báo lỗi completion/format/snippet, hoặc dán diagnostic từ editor kèm ý muốn đổi hành vi editor — kể cả khi đang làm việc trong một project khác như Assetly.
---

# Cấu hình Neovim

Config nằm ở `~/dotfiles/nvim/.config/nvim`. Đường dẫn `~/.config/nvim` là symlink tới đó, được tạo bằng GNU Stow. Mọi thay đổi đều nằm trong Git của `~/dotfiles`, không nằm trong project đang mở. Trả lời người dùng bằng tiếng Việt.

## Trước khi sửa

1. Đọc `~/dotfiles/nvim/AGENTS.md`. Đây là nguồn quy tắc chung cho Claude, Codex và Gemini: layout Colemak-DH, Blink/LuaSnip, formatter, keymap, cách kiểm chứng. Skill này chỉ bổ sung cách làm việc. Nếu hai nơi mâu thuẫn, làm theo `AGENTS.md` và sửa lại skill.
2. Đọc file đang có trước khi sửa. Repo dotfiles thường có thay đổi chưa commit từ phiên khác. Giữ nguyên các thay đổi đó, chỉ sửa đúng phần được yêu cầu.
3. Trước khi gán phím mới, kiểm tra `lua/core/keymaps.lua`. Người dùng gõ Colemak-DH trên bàn phím Cornix và đã map lại nhiều phím: `n/e/i/o` là motion, `j` vào Insert, `;` mở dòng mới. Vì vậy `;` không còn dùng để lặp `f`. Khi chỉ cách bấm phím, dùng phím theo map của người dùng.
4. Đọc reference theo chủ đề:
   - [references/csharp-completion.md](references/csharp-completion.md): completion C#, generic, snippet, cách lấy item Roslyn thật.
   - [references/sql-in-csharp.md](references/sql-in-csharp.md): SQL trong raw string C#, `:SqlFormat`, `:SqlSelect`, tool cài qua Mason.

## Khi nào sửa config, khi nào chỉ hướng dẫn

Khi người dùng nhờ sửa config nvim, cứ sửa trực tiếp; đó là yêu cầu rõ ràng. Mentor Mode của project chỉ áp dụng cho code của project. Nhưng nếu câu hỏi chỉ là "có motion nào nhanh không?", hãy chỉ cách dùng tính năng sẵn có trước (motion, macro, `:s`, LSP code action), rồi mới đề xuất viết lệnh mới. Người dùng đang học vim, và thêm lệnh tùy biến làm config khó bảo trì hơn.

Ưu tiên tính năng có sẵn trước khi tự viết. Ví dụ "Implement interface" của Roslyn được gọi qua `<leader>ga`. Chỉ viết lệnh Lua mới khi thao tác lặp lại nhiều và không có công cụ nào làm được.

## Kiểm chứng trong ngữ cảnh project thật

Config được viết ở dotfiles, nhưng hành vi chỉ thấy rõ trên file thật của project: record C#, solution đã được Roslyn nạp, thư mục module. Vì vậy:

- Chạy kiểm tra headless với `-n -u NONE -i NONE` và chỉ nạp module đang sửa (`-c "luafile ~/.config/nvim/lua/core/<file>.lua"`). Cách này tránh lỗi của plugin không liên quan làm lẫn kết quả.
- Nếu lệnh phụ thuộc vào vị trí file, ví dụ suy schema từ `src/Modules/<Module>/`, đặt buffer test vào đúng thư mục đó. Xong thì xóa file tạm và kiểm tra `git status` của project để chắc không còn sót file.
- Kiểm tra thêm một lần với config đầy đủ (bỏ `-u NONE`). Các plugin nạp lazy (`VeryLazy`), như Mason, có thể làm PATH khác với lúc chạy `-u NONE`.
- Test với dữ liệu mẫu không chứng minh được hành vi thật trong dropdown hay phiên tương tác. Báo tách riêng: đã sửa gì, test nào đã qua (ghi rõ dùng dữ liệu thật hay mẫu), và phần nào chưa xác minh. Khi cần dữ liệu runtime mà headless không lấy được, nhờ người dùng thao tác trong nvim của họ, đừng đoán.
- Với file Lua đã sửa, chạy `stylua` và `git -C ~/dotfiles diff --check -- nvim`.

## Ghi lại

- Mỗi thay đổi có ý nghĩa thì thêm một mục **ở đầu** `~/dotfiles/nvim/CHANGELOG.md`, theo dạng `## 📌 [YYYY-MM-DD] - Tiêu đề`, rồi các gạch đầu dòng: đã đổi gì, vì sao, kiểm chứng ra sao, còn gì chưa xác minh. Nếu sửa tiếp chính tính năng vừa thêm trong cùng ngày, cập nhật mục đó thay vì thêm mục mới.
- Nếu quy ước hoặc lệnh mới cần agent khác biết, thêm vào `AGENTS.md` ngắn gọn. Chi tiết cách làm thì đặt ở reference của skill này.
- Không tự commit hoặc push dotfiles trừ khi người dùng yêu cầu.

## Tiếp nối

Khi kết thúc, nhắc người dùng thử thao tác thật trong nvim, chỉ rõ phải bấm gì. Nếu đây là lần sửa thứ hai cho cùng một lỗi, xin dữ liệu runtime thật trước khi thử thêm một cách sửa khác.
