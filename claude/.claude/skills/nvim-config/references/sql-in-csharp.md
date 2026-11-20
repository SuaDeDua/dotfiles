# SQL trong raw string C#

Áp dụng cho query Dapper viết trong `$"""..."""`. Code nằm ở `lua/core/sql-format.lua`, được nạp trong `init.lua` sau `core.keymaps`.

## Vì sao không dùng Conform

- Conform chạy CSharpier cho file `.cs`. CSharpier không đụng vào nội dung bên trong chuỗi.
- SQLFluff chỉ chạy cho buffer `.sql`.
- Formatter `injected` cần treesitter injection. Injection của easy-dotnet chỉ nhận chuỗi có comment `//language=sql`, và cố ý bỏ qua chuỗi interpolated `$"""`. Mà Dapper lại cần `$` để viết `{nameof(...)}`.

## `:SqlFormat` (Visual: `<leader>fq`)

- Chạy `pg_format -s 4 -u 2` trên các dòng đang chọn: keyword viết HOA, mỗi cấp thụt 4 dấu cách. `{nameof(...)}`, `::text` và `@Param` được giữ nguyên.
- Giữ mức thụt lề nhỏ nhất của khối SQL. Raw string C# yêu cầu mọi dòng phải thụt ít nhất bằng dòng `"""` đóng; thụt ít hơn sẽ gặp lỗi CS9003.
- Người dùng chỉ chọn các dòng SQL, không chọn dòng `$"""` và `""";`.

## `:SqlSelect <Record> [alias] [schema.table]`

- Dùng `rg` tìm `record <Record>(` trong repo và đọc các tham số của primary constructor. Chỉ tách tại dấu phẩy ở mức ngoài cùng, và bỏ giá trị mặc định.
- Sinh `SELECT`, mỗi cột một dòng `alias.snake_case AS {nameof(Record.Prop)},`, dòng cuối không có dấu phẩy, rồi đến `FROM schema.table alias`.
- Các giá trị mặc định:
  - bảng: tên record bỏ `Response`, đổi sang snake_case số nhiều;
  - alias: các chữ hoa trong tên, viết thường;
  - schema: thư mục `src/Modules/<Module>/` viết thường.
- Nếu dòng phía trên đã là `SELECT` thì không sinh thêm `SELECT`. Tab gợi ý tên các record `*Response`.
- Giới hạn:
  - không sinh property nằm ngoài primary constructor;
  - cột lấy từ bảng JOIN vẫn dùng alias chính, phải sửa tay;
  - không sinh JOIN/WHERE.

## Tool qua Mason

Mason chỉ nạp ở `VeryLazy`, nên lúc khởi động PATH có thể chưa có `mason/bin`. Lệnh tùy biến phải dùng `vim.fn.exepath(tool)`, nếu không thấy thì thử `stdpath("data") .. "/mason/bin/<tool>"`. Tool đã có sẵn: `pg_format`, `postgres-language-server`. `sqlfluff` có trong config Conform nhưng **chưa cài**.
