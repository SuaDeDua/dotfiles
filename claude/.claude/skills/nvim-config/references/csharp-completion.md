# Completion C# (Blink + Roslyn + LuaSnip)

## File liên quan (trong `~/dotfiles/nvim/.config/nvim/`)

- `lua/plugins/nvim-cmp.lua`: cấu hình **blink.cmp** (dù tên file là nvim-cmp), dùng LuaSnip làm backend snippet. Provider LSP gọi `core.csharp-completion.transform_items`.
- `lua/core/csharp-completion.lua`: biến completion item của Roslyn thành snippet động.
- `lua/snippets/cs.lua`: snippet viết tay. `plugins/easy-dotnet.lua`: cấu hình server.

## Completion động và snippet viết tay

Lấy tham số generic và tham số method từ declaration mà server trả về. Không viết riêng cho tên cụ thể như Result, Failure, AbstractValidator hay ICommandHandler. Snippet viết tay chỉ dùng cho khung class, không dùng để chép lại API của từng thư viện.

Dấu `<>` trên menu không cho biết text sẽ được chèn. Phải xem cả item gốc lẫn item đã resolve: `label`, `labelDetails`, `kind`, `detail`, `documentation`, `textEdit`, `insertText`, `insertTextFormat`, `command` và client nào trả về. Với Roslyn, item gốc thường chỉ có `label = "NotEmpty<>"`, còn chữ ký chỉ xuất hiện sau `completionItem/resolve`. Blink gọi lại `transform_items` cho item đã resolve, kèm documentation dạng ```` ```csharp ````.

Kết quả mong muốn:

```text
Result<TValue>                                   -> Result<${1:TValue}>$0
Dictionary<TKey, TValue>                         -> Dictionary<${1:TKey}, ${2:TValue}>$0
Result.Failure<TValue>(Error error)              -> Failure<${1:TValue}>(${2:error})$0
Result.Failure(Error error)                      -> Failure(${1:error})$0
NotEmpty<T, TProperty>(this IRuleBuilder<T, TProperty> b)  -> NotEmpty()$0
MaximumLength<T>(this IRuleBuilder<T, string> b, int max)  -> MaximumLength(${1:max})$0
Array.Empty<T>()                                 -> Empty<${1:T}>()$0
```

Quy tắc cho type argument: nếu **mọi** type parameter đều xuất hiện trong kiểu của tham số, kể cả receiver `this` của extension method, thì C# tự suy ra được, nên bỏ `<...>`. Nếu không suy ra được, giữ placeholder generic. Phần này được xử lý bởi `inferable()`.

Các phần phải giữ nguyên:
- edit range (cả insert lẫn replace) và `additionalTextEdits` (import);
- `<...>` hoặc `(...)` đã có sau con trỏ;
- item của server khác, item có `command`, item vốn đã là snippet.

Nếu metadata không đủ, để nguyên item, không tự bịa số tham số.

Tham số method được parse bằng Tree-sitter, vì dấu phẩy còn xuất hiện trong generic, tuple, attribute và giá trị mặc định. Giữ `ref`/`out`, bỏ receiver `this`. Variance `in`/`out` của type parameter không phải là type argument khi gọi method.

## Lấy item Roslyn thật

Khi tự gửi `completionItem/resolve`, phải gộp `CompletionList.itemDefaults` (đặc biệt là `data`) vào item trước. Nếu thiếu bước này, request sẽ hỏng, có thể bị timeout, và trông giống như server không trả lời. Hãy loại trừ khả năng này trước khi kết luận Roslyn bị crash.

Roslyn chạy headless có thể crash (exit 134) khi nạp solution. Khi đó, nhờ người dùng tự lấy item trong nvim, ví dụ gắn một lệnh in tạm `vim.inspect` của item đang chọn vào hook resolve của Blink. Không viết thêm cách sửa dựa trên phỏng đoán.

## Snippet và phím

Snippet người dùng đã yêu cầu:
- `internalhandler`: tên class lấy từ tên file. Tìm được `<Tên bỏ Handler>` thì sinh cả handler (`csharp-scaffold.lua`); không tìm được thì ra khung: primary constructor trống → `ICommandHandler` sửa được → phần generic trống → thân class.
- `internalvalidator`: tương tự; khung khi không tìm được: `AbstractValidator` sửa được → thân class.
- `internalendpoint`, `recordevent`: sinh từ Command/Query và từ lời gọi `Raise(new X(...))`.

## Sinh code từ code có sẵn (`csharp-source.lua`, `csharp-scaffold.lua`)

- Chỉ suy ra những gì đọc được từ declaration (Tree-sitter) và từ EF Configuration. Chỗ nào phụ thuộc nghiệp vụ (cờ `hasAssets`, method repository chưa có, tên Error chưa có) thì để thành placeholder `S.ph(...)`, không bịa.
- Generator trả về `nil` khi không có dữ liệu; snippet khi đó dùng khung cũ.
- Query phân trang (`Page` + `PageSize` trong Query, Response bọc `IReadOnlyCollection<ItemResponse>`) có nhánh riêng: SELECT trên item, `COUNT(*)`, `QueryMultipleAsync`. Khi thêm một dạng query mới, sinh lại toàn bộ handler/validator/endpoint của module bằng bản cũ và bản mới rồi diff, để chắc chỉ file mục tiêu thay đổi.
- Kiểm chứng bằng cách sinh lại các file đã có trong Assets rồi so với bản viết tay. Mọi thứ có tác dụng ghi file (`:CsRegister`) phải chạy trên bản sao trong `/tmp` (thêm `.git` giả để `vim.fs.root` tìm được gốc).
- Headless: buffer trống khiến `snip_expand` lỗi (`word_under_cursor`), nên đặt một dòng `""` và con trỏ trước khi expand.

Không thêm dependency mẫu hay comment `/** */` khi người dùng không yêu cầu.

LuaSnip: insert node bắt đầu từ 1; `i(0)` là điểm thoát cuối cùng, thường là thân class. Các ví dụ đánh số của người dùng mô tả thứ tự nhảy, không phải số node.

Giữ Tab/Shift-Tab và Ctrl-e/Ctrl-i. Mapping chỉ dành cho Visual phải dùng mode `x`, không dùng `v`, để khi gõ chữ hoa trong placeholder (Select mode) không bị dính mapping. Ctrl-i và Tab có phân biệt được hay không tùy terminal có hỗ trợ extended key; hãy kiểm tra phím thực sự nhận được trước khi nói đã sửa xong.

## Refactor qua code action của Roslyn (`csharp-refactor.lua`)

Trước khi tự viết một refactor, hỏi Roslyn xem nó có những action nào: chạy nvim headless với config đầy đủ trong repo, chờ khoảng 60 giây cho solution nạp xong, rồi gửi `textDocument/codeAction` tại dòng using, dòng namespace, tên type và một vùng chọn. Phải gửi kèm `context.diagnostics` của dòng đó (`d.user_data.lsp`), nếu không các quickfix như xóa using thừa sẽ không xuất hiện. Nên tạo file thử có lỗi cố ý (namespace sai thư mục, using thừa, có hai type trong một file). Các action có ghi tác dụng phải chạy trên bản sao repo trong `/tmp`, kèm thư mục `obj/` và một `.git` giả. Lưu ý `rm` trên máy là bản tương tác, nên dùng `rm -f`.

## Kiểm chứng

Thử đủ các trường hợp: generic và không generic, nhiều type parameter, giữ import và range, đã có `<...>`/`(...)`, item không được hỗ trợ. Với snippet, expand bằng LuaSnip và kiểm tra thứ tự nhảy placeholder. Item test tự tạo phải ghi rõ là "mẫu". Nếu người dùng báo lại cùng một lỗi, lấy dữ liệu runtime thật trước khi thử cách sửa khác.
