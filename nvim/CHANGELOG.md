# 📝 Neovim & Dotfiles Configuration Changelog

Nhật ký ghi lại toàn bộ các lần can thiệp, chỉnh sửa cấu hình hệ thống và Neovim nhằm giúp người dùng dễ dàng theo dõi, kiểm soát phiên bản và rollback khi cần thiết.

---

## 📌 [2026-10-13] - Sửa lỗi JDTLS không nhận file XML (thiếu file://) & Căn lề chuẩn 4-8-16-24 spaces
* **File bị ảnh hưởng:**
  - `~/.config/nvim/ftplugin/java.lua`
  - `~/.config/nvim/eclipse-formatter.xml`
* **Nguyên nhân sự cố:**
  - Trong `java.lua`, đường dẫn cấu hình `url` truyền vào JDTLS là đường dẫn local thuần (`/Users/...`) thay vì URL chuẩn có protocol (`file:///Users/...`).
  - Java ném lỗi `MalformedURLException: no protocol: /Users/...` khiến JDTLS âm thầm thất bại khi tải file `eclipse-formatter.xml`, fallback về profile mặc định nội bộ (2 spaces). Do đó mọi chỉnh sửa trong XML trước đó không hề có hiệu lực!
  - Đoạn code mong muốn của người dùng có cấu trúc thụt lề cấp số nhân hoàn hảo:
    - Khai báo class member: 4 spaces
    - Thân hàm: 8 spaces (4 + 4)
    - Chuỗi Stream nối tiếp: 16 spaces (8 + 8)
    - Tham số constructor bẻ dòng: 24 spaces (16 + 8)
* **Nội dung thay đổi:**
  - `java.lua`: Sửa `url` thành `"file://" .. vim.env.HOME .. "/.config/nvim/eclipse-formatter.xml"`. JDTLS đã nạp thành công profile `GoogleStyle` không còn báo lỗi.
  - `eclipse-formatter.xml`:
    - `indentation.size = "4"`, `tabulation.size = "4"` (Base = 4 spaces).
    - `continuation_indentation = "2"` (Mỗi cấp độ bẻ dòng tăng đúng 2 levels = 8 spaces: 8 -> 16 -> 24).
    - `alignment_for_selector_in_method_invocation = "80"`, `count_dependent = "80|-1|80"` (Tự động ngắt `.stream()`, `.map()`, `.toList()` xuống 16 spaces).
    - `alignment_for_arguments_in_allocation_expression = "48"`, `count_dependent = "48|-1|48"` (Tự động ngắt tham số constructor xuống 24 spaces).

---

## 📌 [2026-10-12] - Cấu hình Format chuẩn Stream API (Fluent Chain) & Thụt lề 4 spaces
* **File bị ảnh hưởng:**
  - `~/.config/nvim/lua/plugins/conform.lua`
  - `~/.config/nvim/eclipse-formatter.xml`
* **Nguyên nhân sự cố:**
  - `conform.nvim` chạy `google-java-format` ép cứng thụt lề 2 spaces và gộp chuỗi Stream API thành 1 dòng dính liền.
  - Thuộc tính `join_wrapped_lines = "true"` trong `eclipse-formatter.xml` kéo giật các dòng ngắt thủ công lại thành 1 hàng ngang.
* **Nội dung thay đổi:**
  - `conform.lua`: Gỡ `google-java-format` để Neovim tự động dùng LSP (JDTLS).
  - `eclipse-formatter.xml`:
    - Đổi `join_wrapped_lines = "false"` để giữ nguyên ngắt dòng chuỗi Stream (`.stream()`, `.map()`, `.toList()`) và danh sách tham số.
    - Đổi `tabulation.size = "4"` (thụt lề chuẩn 4 spaces).
    - Đổi `lineSplit = "120"`.
    - Đặt `continuation_indentation = "8"` (chuẩn IntelliJ / Spring): Khắc phục việc Google Style đặt giá trị 2 khiến dòng ngắt tham số chỉ được cộng 2 spaces (8 + 2 = 10 spaces). Gán bằng 8 giúp cụm tham số `category.getId()` đạt chuẩn 16 spaces (8 + 8 = 16 spaces).
    - Đặt `alignment_for_selector_in_method_invocation = "80"` và `count_dependent = "80|-1|80"` (Wrap all except first): Tự động ngắt dòng các hàm tiếp theo (`.stream()`, `.map()`, `.toList()`) kể cả khi viết chung 1 dòng, nhưng giữ `repository.findAll()` ở dòng đầu.
    - Đặt `alignment_for_arguments_in_allocation_expression = "52"` và `count_dependent = "52|-1|52"`.
    - Đặt `alignment_for_arguments_in_method_invocation = "16"` để biểu thức lambda (`category -> ...`) nằm ngay sau `.map(` trên cùng 1 dòng.
    - Đặt `alignment_for_record_components = "48"`, `alignment_for_superinterfaces_in_type_declaration = "80"`.

---

## 📌 [2026-10-12] - Sửa lỗi JDTLS Exit Code 13 & Đụng độ Multi-module Workspace
* **File bị ảnh hưởng:**
  - `~/.config/nvim/ftplugin/java.lua`
  - Thư mục cache `~/jdtls-workspace/`
* **Nguyên nhân sự cố:**
  - `root_dir` cũ sử dụng marker `pom.xml`. Trong dự án Maven đa module (`evently`), mỗi module con đều có `pom.xml` riêng nên Neovim đã bật nhiều tiến trình JDTLS cùng chạy đồng thời.
  - Các tiến trình này cùng ghi vào một thư mục `~/jdtls-workspace/evently` dẫn đến hỏng file index nhị phân (`.index`).
  - Khi JDTLS đọc file hỏng, kích thước bộ nhớ bị đọc sai thành 1.1GB dẫn tới lỗi `OutOfMemoryError: Java heap space` và sập tiến trình với mã lỗi `Exit code 13`.
* **Nội dung thay đổi:**
  - Đổi cơ chế tìm `root_dir`: Ưu tiên các file gốc (`.git`, `mvnw`, `gradlew`), bỏ `pom.xml` ở tầng root để cả dự án đa module chỉ dùng chung **1 server JDTLS**.
  - Đổi `workspace_dir`: Sinh mã hash sha256 gắn theo đường dẫn tuyệt đối (`evently-<hash>`), đảm bảo workspace hoàn toàn cô lập, không bao giờ bị ghi đè chéo.
  - Dọn dẹp toàn bộ dữ liệu cache hỏng cũ trong `~/jdtls-workspace/`.
  - Liên kết lại file format cục bộ `eclipse-formatter.xml`.

---

## 📌 [2026-10-03] - Kích hoạt Syntax Highlighting Treesitter cho Java
* **File bị ảnh hưởng:**
  - `~/.config/nvim/ftplugin/java.lua`
* **Nguyên nhân sự cố:**
  - Plugin `nvim-treesitter` đang cài nhánh thử nghiệm `main`. Nhánh này đã bỏ hoàn toàn tính năng tự động highlight (`highlight = { enable = true }`), yêu cầu phải gọi hàm khởi tạo gốc của Neovim.
  - Markdown tự nhận màu vì Neovim 0.10+ tích hợp sẵn, nhưng file `.java` bị mất màu hoàn toàn.
* **Nội dung thay đổi:**
  - Thêm lệnh `pcall(vim.treesitter.start)` ngay đầu file `java.lua` để tự động bật Treesitter cho mọi buffer Java.

---

## 📌 [2026-09-30] - Cấu hình bộ Formatter Google Style / AOSP (4 spaces)
* **File bị ảnh hưởng:**
  - `~/.config/nvim/eclipse-formatter.xml` (Tạo mới từ Google Java Style XML)
  - `~/.config/nvim/ftplugin/java.lua`
* **Nội dung thay đổi:**
  - Tải file `eclipse-java-google-style.xml` về `~/.config/nvim/eclipse-formatter.xml`.
  - Tăng độ dài dòng `lineSplit` từ 100 lên 120 ký tự.
  - Bật xuống dòng cho annotation tham số: `insert_new_line_after_annotation_on_parameter = "insert"`.
  - Cấu hình format Record và Interface không bị mất thụt lề:
    - `alignment_for_record_components = "48"` (thay vì 81).
    - `alignment_for_superinterfaces_in_type_declaration = "80"` (thay vì 16).
  - Đổi thụt lề từ Google chuẩn (2 spaces) sang chuẩn AOSP / Spring Boot cộng đồng (4 spaces): `tabulation.size = "4"`.
  - Trỏ `settings.java.format.url` trong `java.lua` về file cục bộ này.

---

## 📌 [2026-09-16] - Tối ưu hóa tốc độ khởi động Shell (Zsh)
* **File bị ảnh hưởng:**
  - `~/dotfiles/zsh/conf.d/10-exports.zsh`
  - `~/dotfiles/zsh/conf.d/20-plugins.zsh`
* **Nguyên nhân sự cố:**
  - Startup Zsh mất hơn 1.4s do gọi subshell `$(npm root -g)` mỗi lần mở terminal.
  - Lệnh `compinit` bị gọi 2 lần (làm vô hiệu bộ đệm của Oh-My-Zsh).
  - Plugin nặng `zsh-autocomplete` và xung đột giữa 2 plugin tô màu cú pháp.
* **Nội dung thay đổi:**
  - Vô hiệu hóa `$(npm root -g)`.
  - Bỏ lệnh gọi `compinit` thủ công để nhường quyền tối ưu cache cho Oh-My-Zsh.
  - Gỡ bỏ `zsh-autocomplete` và `fast-syntax-highlighting`, giảm thời gian nạp shell từ 1.43s xuống còn ~0.7s.

---

## 📌 [2026-09-14] - Chống treo IntelliJ IDEA khi nạp môi trường từ `/bin/zsh`
* **File bị ảnh hưởng:**
  - `~/dotfiles/zsh/.zshrc`
* **Nguyên nhân sự cố:**
  - IntelliJ khởi chạy zsh ngầm để đọc biến môi trường (`PATH`), nhưng bị treo vô hạn vì các script giao diện (`p10k`, `fzf`, themes) chờ TTY.
* **Nội dung thay đổi:**
  - Thêm chốt chặn đầu file `.zshrc`: Nếu phát hiện biến `INTELLIJ_ENVIRONMENT_READER`, chỉ nạp file `10-exports.zsh` rồi thoát ngay lập tức.

---

## 📌 [2026-09-09] - Vá lỗi `blink-cmp-deps` (Maven autocompletion)
* **File bị ảnh hưởng:**
  - `~/.local/share/nvim/lazy/blink-cmp-deps/lua/blink_deps/util.lua`
* **Nguyên nhân sự cố:**
  - Thư viện `blink.cmp` cập nhật phiên bản mới xóa bỏ hàm `context.get_pos()`, khiến plugin phụ trợ `blink-cmp-deps` bị sập khi gợi ý dependency Maven trong `pom.xml`.
* **Nội dung thay đổi:**
  - Thay thế `context.get_pos()` bằng fallback an toàn trỏ vào thuộc tính `context.cursor` mới của Neovim.
