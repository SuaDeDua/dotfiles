# 📝 Neovim & Dotfiles Configuration Changelog

Nhật ký ghi lại toàn bộ các lần can thiệp, chỉnh sửa cấu hình hệ thống và Neovim nhằm giúp người dùng dễ dàng theo dõi, kiểm soát phiên bản và rollback khi cần thiết.

---

## 📌 [2026-11-19] - C# refactor: organize usings, namespace theo thư mục, chuyển type sang file mới

* Hỏi trực tiếp Roslyn (headless, trên file thật của Assetly) để xem nó có những action nào. Kết quả:
  * `Remove unnecessary usings`, `Sort Usings`;
  * `Change namespace to '<theo thư mục>'`, `Move file to ...`;
  * `Move type to X.cs`, `Extract 'X' to a new file`;
  * khi chọn câu lệnh: `Extract method`, `Extract local function`.
* Vì Roslyn đã có sẵn các action này, lệnh mới chỉ tìm action theo tiêu đề rồi áp dụng, không tự viết lại (`lua/core/csharp-refactor.lua`, nạp trong `init.lua`):
  * `:CsOrganizeUsings`, phím `<leader>go` trong file cs: xóa using thừa rồi sắp xếp. Action quickfix chỉ xuất hiện khi gửi kèm diagnostic của dòng (IDE0005).
  * `:CsSyncNamespace [thư mục]`, phím `<leader>gm`: đổi namespace theo thư mục cho file hiện tại hoặc mọi file `.cs` trong thư mục. Roslyn **chỉ sửa chính file**, nên sau đó lệnh tự sửa các file có `using <cũ>;` mà dùng type vừa chuyển: thêm `using <mới>;` (dùng `ensure_using` của `csharp-register`, hàm này giờ được export), và bỏ `using <cũ>;` khi không còn file nào khai báo namespace cũ.
  * `:CsMoveType`, phím `<leader>gx` (Visual hoặc trên dòng): tìm type trong vùng chọn bằng Tree-sitter, rồi gọi `Move type to X.cs`. Nếu vùng chọn chỉ có câu lệnh thì báo dùng `<leader>ga` → Extract method.
  * Các file bị action sửa được lưu lại.
* Tự thêm `using` khi gõ đã có sẵn từ trước (`dotnet_completion_items_from_unimported_namespaces_commit_behavior = "alwaysAddImport"`).
* Kiểm tra trên bản sao repo trong `/tmp`, có Roslyn thật, chạy cả với `-u NONE`, nạp riêng module, lẫn config đầy đủ:
  * xóa đúng `using System.Data.Common;`;
  * `Wrong` → `Assets.GetAssets`, và file tham chiếu được đổi `using`;
  * `ZzOther` được chuyển sang `ZzOther.cs`;
  * vùng chọn không có type thì báo lỗi.
  * Bản sao đã được xóa.
* Chưa thử bằng phím trong phiên tương tác. Chưa thử `:CsSyncNamespace` trên thư mục có nhiều file cùng đổi.

---

## 📌 [2026-11-17] - Query phân trang (`GetAssets`): handler, validator, endpoint

* Lỗi: với `GetAssetsQuery(State?, AssetModelId?, Page, PageSize)` và `GetAssetsResponse(Page, PageSize, TotalCount, Items)`:
  * handler không tìm ra entity, vì `GetAssets` là số nhiều;
  * nếu ép tìm ra entity thì lại SELECT trên `GetAssetsResponse` thay vì trên item, và lọc `= @Page`;
  * endpoint đặt tên tham số query PascalCase, `Page`/`PageSize` thiếu giá trị mặc định;
  * validator thiếu luật cho `Page`/`PageSize`.
* `entity_for` thử thêm dạng số ít (`S.singular`: `Assets` → `Asset`, `Categories` → `Category`).
* Query handler nhận ra **dạng phân trang**: Query có `Page` + `PageSize`, Response có một collection của Response khác (`Items`). Khi đó sinh:
  * `var parameters = new { ..., Take, Skip }`;
  * SELECT/JOIN trên kiểu item;
  * bộ lọc tùy chọn `(@X::uuid IS NULL OR ...)` cho tham số nullable;
  * `ORDER BY` theo cột unique đầu tiên trong Configuration (`a.tag`), để thành placeholder;
  * `OFFSET/LIMIT`, câu `COUNT(*)`, `QueryMultipleAsync`, rồi `new XxxResponse(...)` gán `items`/`totalCount`/`request.X`.
  * Query không phân trang: tham số nullable cũng sinh bộ lọc tùy chọn như trên.
* Endpoint GET: tham số query string viết camelCase. `Page`/`PageSize` kiểu `int` thành `int page = 1, int pageSize = 20`, đặt sau `ISender`.
* Validator: `Page` → `GreaterThanOrEqualTo(1)`; `PageSize` → `InclusiveBetween(1, 100)`, trong đó 100 là placeholder.
* Kiểm tra bằng headless `-u NONE`, sinh lại các file thật của module Assets bằng bản cũ và bản mới rồi diff:
  * chỉ phần của `GetAssets` thay đổi;
  * `GetAsset`, `GetAssetModel`, `GetFieldSet` và các validator khác giữ nguyên;
  * so với `GetAssetsQueryHandler` viết tay, nội dung khớp, chỉ khác cách xuống dòng.
  * Với config đầy đủ, handler cũng sinh được.
* Chưa xác minh trong phiên tương tác.

---

## 📌 [2026-11-17] - Gom endpoint theo thư mục, Tag theo thư mục, `:SqlSelect` tự JOIN

* Snippet mới `publicendpoints`: tạo file `XxxEndpoints.cs` trong một thư mục rồi gõ snippet, sẽ sinh `MapEndpoints(app)` gọi `X.MapEndpoint(app);` cho mọi class có `MapEndpoint(IEndpointRouteBuilder)` trong thư mục đó, xếp theo chữ cái.
* `internalendpoint`: `.WithTags(Tags.<Thư mục>)` thay vì tên module (`Presentation/AssetModels/` → `Tags.AssetModels`).
* `:CsRegister`:
  * Trên file endpoint: chỉ thêm vào `*Endpoints.cs` **cùng thư mục**; nếu thư mục chưa có file gom thì báo, không thêm nhầm sang thư mục khác. Thêm `internal const string X = "X";` vào `Tags.cs` khi chưa có.
  * Trên file gom `XxxEndpoints.cs`: thêm `XxxEndpoints.MapEndpoints(app);` cùng `using` vào `*Module.cs`.
* `:SqlSelect` dùng chung bộ dựng SQL với query handler (`csharp-scaffold.select_sql`). Cột không có trên bảng chính được JOIN theo khóa ngoại `<X>Id`, và tên cột lấy từ EF Configuration (`ManufacturerName` → `JOIN assets.manufacturers m` → `m.name`). Lệnh cũng đọc được record khai báo bằng property `{ get; init; }`. Khi thiếu entity hoặc Configuration thì giữ cách cũ.
* Kiểm tra bằng nvim headless `-u NONE`:
  * `publicendpoints` trên thư mục `AssetModels` thật ra đủ 4 endpoint.
  * `:CsRegister` chạy trên bản sao module trong `/tmp`, kết quả xem bằng diff: thêm `LocationEndpoints` vào `AssetsModule` và `Tags.Locations`; chạy lại thì báo "đã có".
  * `:SqlSelect AssetModelResponse` ra đúng 2 JOIN với `m.name`, `c.name`; `AssetResponse x` dùng alias `x`; `CustomFieldResponse` (record dạng property) chạy được.
* Chưa xác minh trong phiên tương tác.

---

## 📌 [2026-11-16] - Sinh handler, validator, domain event từ code có sẵn; lệnh `:CsRegister`

* `lua/core/csharp-source.lua` (mới): phần dùng chung. Tìm khai báo bằng `rg`, ưu tiên file cùng module; đọc bằng Tree-sitter: tham số, property, method, base list, `AggregateRoot<Guid>`. Đọc EF Configuration: `HasMaxLength`, `HasIndex(...).IsUnique()`, `ToTable`, `HasColumnName`, `jsonb`. Có cache theo từng lần sinh. `to_snippet()` đổi các chỗ cần quyết định thành placeholder của LuaSnip.
* `lua/core/csharp-scaffold.lua` (mới), dùng trong snippet ở `lua/snippets/cs.lua`:
  * `internalvalidator`: `RuleFor` cho từng property của `<Tên file bỏ Validator>`. `string` không nullable → `NotEmpty()`; `MaximumLength` lấy từ `HasMaxLength` của entity, kể cả hằng như `SerialNumber.MaxLength` (tự thêm `using`). `Guid` → `NotEmpty()`, `Guid?` → `NotEqual(Guid.Empty)`, enum → `IsInEnum()`.
  * `internalhandler`, nhánh Command: entity chính suy từ tên command hoặc từ tham số `<X>Id` có `I<X>Repository`. Có `<Entity>Id` thì nạp kèm `NotFound`; không có thì dùng factory `Create`. Value object có `V.Create(string)` → khối `Result<V>`. Entity khác được nạp theo `<X>Id` của request (nullable → nạp có điều kiện), hoặc theo `<X>Id` của entity đã nạp. Unique index → gọi method `Task<bool>` của repository có tham số trùng tên cột, và chọn `...NotUnique`/`Duplicate...` trong `XxxErrors`. Gọi method domain, `Insert`, `SaveChangesAsync`, trả `Id`.
  * `internalhandler`, nhánh Query: Dapper SELECT từ property của Response. Cột không có trên bảng chính → tự JOIN theo khóa ngoại `<X>Id`, tối đa 2 bước (`AssetModelName` → `JOIN asset_models am` → `am.name`); `Guid?` → `LEFT JOIN`. `jsonb` + `string` → `::text`. `WHERE` lấy từ tham số Query; một bản ghi → `NotFound`, danh sách → `QueryAsync`.
  * `recordevent` (mới): `public sealed record <Tên file>(...) : DomainEvent` với tham số suy từ `Raise(new <Tên file>(...))`, lấy kiểu từ tham số, biến cục bộ, property và chuỗi member (`SerialNumber?.Value` → `string?`, `result.Value.Id` → `CustomFieldId`).
  * Chưa có dữ liệu (chưa có command, chưa có lời gọi `Raise`) → snippet ra khung cũ, hoặc record trống để tự điền.
* `lua/core/csharp-register.lua` (mới), nạp từ `init.lua`: `:CsRegister` đọc buffer hiện tại.
  * Endpoint → `X.MapEndpoint(app);` trong `*Endpoints.cs`.
  * Repository → `services.AddScoped<IX, X>();` trong `*Module.cs`, kèm `DbSet<X>`.
  * EF configuration → `DbSet<X>`.
  * Dòng đã có thì bỏ qua; tự thêm `using` theo thứ tự; giữ BOM; lưu file đích.
* Kiểm tra bằng nvim headless `-u NONE` với code thật của module Assets:
  * Handler sinh ra khớp file viết tay ở `CreateAsset`, `UpdateAssetDetails`, `CreateAssetModel`, `DiscontinueAssetModel`. Còn placeholder: `hasAssets`, `isInUse`, check unique của Manufacturer, và việc tự sinh tag khi `Tag` trống.
  * Validator lấy đúng độ dài từ Configuration.
  * Query `GetAssetModel` ra đúng 2 JOIN; `GetAsset` ra `am.name`/`asset_model_id`/`custom_fields::text`.
  * Event: 6 event có sẵn khớp kiểu.
  * `:CsRegister` chạy trên bản sao module trong `/tmp`, kết quả xem bằng diff.
  * Thứ tự nhảy placeholder đã kiểm tra.
  * Config đầy đủ: loader thấy 4 snippet, `:CsRegister` đã có.
* Chưa xác minh: dropdown Blink tương tác; dòng dài chờ CSharpier format lại khi lưu.

---

## 📌 [2026-11-16] - Snippet `internalendpoint`: sinh endpoint + Request từ Command/Query

* Thêm `lua/core/csharp-endpoint.lua` và snippet `internalendpoint` trong `lua/snippets/cs.lua`. Snippet lấy tên class từ tên file (ví dụ `UpdateAssetDetails`), dùng `rg` tìm record `UpdateAssetDetailsCommand` hoặc `UpdateAssetDetailsQuery`, rồi đọc tham số và `ICommand<T>`/`IQuery<T>` bằng Tree-sitter.
* Sinh ra:
  * `using` cho namespace của command, `ApiResults`, `Result`, MediatR và AspNetCore;
  * `app.Map<Verb>`, chọn verb theo tiền tố tên (Create/Add → Post, Get/List → Get, Update/Change → Put, Delete/Remove → Delete);
  * route: phần gốc lấy theo **thư mục** chứa file, đổi sang kebab-case (`Presentation/AssetModels/` → `asset-models`). Nếu tham số đầu của command/query là `...Id` kiểu `Guid`/`int`/`long` thì route thêm `/{id:guid}`, `/{id:int}` hoặc `/{id:long}`, **kể cả với POST** (`AddCustomField(FieldSetId, …)` → `field-sets/{id:guid}`). Lambda nhận `<kiểu> id`, và `id` không còn nằm trong `Request`. Kiểu riêng của project dùng trong `Request` (ví dụ enum `CustomFieldType`) được tự thêm `using`;
  * `Result` + `Results.NoContent` cho `ICommand`, `Result<T>` + `Results.Ok` cho `ICommand<T>`/`IQuery<T>`;
  * class `Request` chứa các tham số còn lại; `IReadOnlyDictionary`/`IReadOnlyList` đổi thành `Dictionary`/`List` nullable và truyền thêm `?? []`. Với GET thì không sinh `Request`, tham số được bind thẳng vào lambda;
  * `.WithTags(Tags.<Module>)`.
* Thứ tự nhảy: (1) con trỏ đứng ngay sau route (`asset-models/█` hoặc `field-sets/{id:guid}█`) để gõ tiếp đường dẫn → (2) verb. Nếu không tìm thấy record, snippet vẫn sinh khung với `new <Tên>Command()`.
* Đã kiểm tra bằng nvim headless `-u NONE`, chỉ nạp LuaSnip, buffer đặt trong `Assets.Presentation/Assets/` của Assetly với record thật. `CreateAsset` và `GetAsset` cho ra code khớp file hiện có; `UpdateAssetDetails` ra PUT `assets/{id}` cùng Request 3 property; tên không có command cũng sinh được khung. Thứ tự nhảy: Put → route → hết. Với config đầy đủ, loader `from_lua` có thấy snippet.
* Chưa kiểm tra trong dropdown Blink tương tác.

---

## 📌 [2026-11-16] - Chuyển skill Claude sang `nvim-config` dùng được ở mọi project

* Gộp skill `nvim-csharp-completion` thành `claude/.claude/skills/nvim-config/`, gồm `SKILL.md` và các reference `csharp-completion.md`, `sql-in-csharp.md`. Dùng `stow claude` để tạo symlink `~/.claude/skills/nvim-config`. Nhờ đó Claude nạp skill được cả khi đang làm việc trong project khác (ví dụ Assetly), và có file thật để kiểm chứng.
* `AGENTS.md` vẫn là nguồn quy tắc chung; skill trỏ tới đó thay vì chép lại. Thêm `nvim/CLAUDE.md` (`@AGENTS.md`) để phiên mở trong dotfiles cũng nạp quy tắc.
* Xóa `.claude/skills/nvim-csharp-completion` cũ để không trùng tên skill khi mở phiên trong dotfiles. Bản cho Codex ở `.agents/skills/` giữ nguyên.
* Sửa ghi chú ngày 2026-11-13: lỗi timeout khi resolve chưa chắc do Roslyn, vì request thiếu `itemDefaults.data`.

---

## 📌 [2026-11-13] - Lệnh sinh SELECT ... FROM Dapper từ record C#

* `lua/core/sql-format.lua` thêm lệnh `:SqlSelect <Record> [alias] [schema.table]`:
  * Dùng `rg` tìm `record <Record>(` trong repo và đọc tham số của primary constructor. Lệnh chỉ tách tại dấu phẩy ở mức ngoài cùng nên không hỏng với generic/tuple, và bỏ giá trị mặc định.
  * Sinh khối `SELECT`, mỗi tham số một dòng `alias.snake_case AS {nameof(Record.Prop)},`, dòng cuối không có dấu phẩy, rồi đến `FROM schema.table alias`.
* Giá trị mặc định suy từ tên record:
  * bảng: bỏ `Response`, đổi sang snake_case số nhiều (`CustomFieldResponse` → `custom_fields`, `Category` → `categories`);
  * alias: các chữ hoa viết thường (`cf`);
  * schema: tên thư mục `src/Modules/<Module>/` viết thường.
  * Có thể truyền `[alias] [schema.table]` để ghi đè.
* Chèn và thụt lề:
  * Nếu dòng phía trên đã là `SELECT` thì không sinh lại `SELECT`.
  * Dòng hiện tại trống thì bị thay bằng kết quả; dòng có nội dung thì kết quả chèn bên dưới.
  * Cột thụt thêm 4 dấu cách so với `SELECT`/`FROM`, khớp `:SqlFormat`.
  * Tab gợi ý các record `*Response` trong repo.
* Giới hạn:
  * Property ngoài primary constructor (ví dụ `FieldSetResponse.Fields`) không được sinh.
  * Cột lấy từ bảng JOIN (ví dụ `AssetModelName` → `am.name`) vẫn dùng alias chính, cần sửa tay. Lệnh không sinh JOIN/WHERE.
* Đã kiểm tra bằng nvim headless `-u NONE`, chạy với buffer đặt trong thư mục module Assets:
  * `CustomFieldResponse`: ra `FROM assets.custom_fields cf`;
  * `FieldSetResponse`, đặt dưới `SELECT` có sẵn: ra `FROM assets.field_sets fs`;
  * `AssetResponse a assets.assets`: ra `FROM assets.assets a`.
* Chưa xác minh trong phiên nvim tương tác.

---

## 📌 [2026-11-13] - Bỏ type argument suy ra được khi completion method generic C#

* `lua/core/csharp-completion.lua` thêm `inferable()`. Khi mọi type parameter của method đều xuất hiện trong kiểu tham số (kể cả receiver `this` của extension method), snippet chỉ còn phần đối số. Ví dụ: `NotEmpty<T, TProperty>(this IRuleBuilder<T, TProperty>)` → `NotEmpty()`, `MaximumLength(${1:maximumLength})`, `Must(${1:predicate})`, `Where(${1:predicate})`.
* Method không suy ra được kiểu vẫn giữ placeholder generic: `Failure<${1:TValue}>(${2:error})`, `Array.Empty<${1:T}>()`.
* Nhãn menu vẫn là `NotEmpty<>` vì Roslyn trả nhãn như vậy; chỉ phần chèn vào thay đổi.
* Đã kiểm tra bằng nvim headless `-u NONE` với 7 item mẫu có chữ ký theo dạng Roslyn (FluentValidation, Result, LINQ, method thường). Item `NotEmpty` thật lấy từ Roslyn chỉ có `label = "NotEmpty<>"`, còn chữ ký đến từ `completionItem/resolve`; bước resolve không lấy được khi chạy headless: Roslyn crash (exit 134), và request resolve thủ công chưa gộp `itemDefaults.data` nên timeout có thể do chính request; nguyên nhân chưa xác định. Chưa xác minh dropdown thật trong phiên tương tác.

---

## 📌 [2026-11-13] - Lệnh format SQL trong raw string C#

* Thêm `lua/core/sql-format.lua` và nạp nó trong `init.lua` ngay sau `core.keymaps`. File này tạo lệnh `:SqlFormat` dùng cho vùng chọn, kèm phím tắt `<leader>fq` ở Visual mode (mode `x`).
* Lệnh chạy `pg_format -s 4 -u 2` (bản cài qua Mason) trên các dòng đang chọn. Keyword được viết HOA, mức thụt lề nhỏ nhất của khối SQL được giữ nguyên để không lỗi raw string C# (CS9003). `{nameof(...)}`, `::text` và `@Param` không bị đổi.
* Mason nạp ở `VeryLazy`, nên nếu PATH chưa có `pg_format` thì lệnh tìm trực tiếp trong `stdpath("data")/mason/bin`.
* Chỉ chọn các dòng SQL, không chọn dòng `$"""` và `""";`. Conform/CSharpier vẫn không động vào SQL trong chuỗi, còn SQLFluff vẫn dùng cho buffer `.sql`.
* Đã kiểm tra bằng nvim headless:
  * `-u NONE`: chạy cả lệnh lẫn phím tắt;
  * config đầy đủ: chạy được `:SqlFormat`.
* Chưa thử thao tác tay trong phiên nvim tương tác.

---

## 📌 [2026-11-13] - Thêm PostgreSQL language server

* Bật `postgres_lsp` cho filetype `sql` và `postgresql` khi executable `postgres-language-server` có trong PATH. Server cung cấp completion/diagnostics; `sqlfluff` vẫn chịu trách nhiệm format.
* Không bật server khi chưa cài binary để Neovim không báo lỗi lúc khởi động.

---

## 📌 [2026-11-13] - Thêm formatter SQL/PostgreSQL

* Conform.nvim dùng `sqlfluff format --dialect postgres -` cho filetype `sql` và `postgresql`, chạy cùng `format_on_save` hiện tại.
* SQL nằm trong raw/interpolated string C# không được tự sửa trực tiếp để tránh làm hỏng interpolation; nên format trong buffer `.sql` hoặc workflow riêng.

---

## 📌 [2026-11-12] - Thêm hướng dẫn dùng chung cho Codex và Gemini

* Thêm `nvim/AGENTS.md` làm nguồn quy tắc chung cho chỉnh sửa Neovim bằng Codex và Gemini CLI.
* Thêm `nvim/GEMINI.md` trỏ về cùng nguồn để tránh lệch hướng dẫn giữa hai công cụ. Claude tiếp tục dùng các skill project riêng trong `.claude/`.

---

## 📌 [2026-11-12] - Tạo skill cho completion C# trong Neovim

* Thêm `.claude/skills/nvim-csharp-completion/SKILL.md`, tổng hợp quy tắc xử lý Blink/Roslyn/LuaSnip: ưu tiên dữ liệu declaration dynamic, giữ generic/import/range, phân biệt kiểm thử mẫu với kiểm thử dropdown thật và ghi nhận giới hạn chưa xác minh.

---

## 📌 [2026-11-12] - Dynamic generic type từ declaration Roslyn

* Lấy type parameter từ detail hoặc declaration C# trong documentation đã resolve, ngoài label. Áp dụng theo dữ liệu server cho class/interface/struct bất kỳ, không hardcode tên `Result` hay `AbstractValidator`.
* Hỗ trợ nhiều type parameter và variance `in`/`out`; giữ completion thường nếu không có declaration generic hợp lệ. Đã chạy kiểm tra headless với dữ liệu completion mẫu, chưa xác minh dropdown project thực tế.

---

## 📌 [2026-11-12] - Giữ generic trong completion method C#

* Chuyển signature method generic Roslyn thành snippet có cả type arguments: `Failure<TValue>(Error error)` → `Failure<${1:TValue}>(${2:error})$0`. Tab sửa kiểu trước rồi tham số; overload thường giữ nguyên.
* Lấy signature từ documentation nếu detail không chứa signature; hỗ trợ label có type arguments. Không thêm lời gọi nếu đã có `<` hoặc `(` sau con trỏ.
* Kiểm tra headless với completion mẫu generic/thường, nhiều type parameter, range/import và thứ tự nhảy LuaSnip; chưa xác minh trực tiếp với dropdown Roslyn trong project.

---

## 📌 [2026-11-12] - Tối giản placeholder internal handler/validator

* `internalhandler`: constructor trống → `ICommandHandler` sửa được → generic trống → thân class.
* `internal`: `AbstractValidator` sửa được → generic trống → thân class. Bỏ dependency và command mẫu để dùng lại cho nhiều class.

---

## 📌 [2026-11-12] - Snippet internal command handler

* Thêm `internalhandler`: tên class theo file, primary constructor có các dependency mẫu và `ICommandHandler<CreateAssetCommand, Guid>`. Tab qua từng kiểu dependency, tên biến, command và kiểu kết quả rồi vào thân class. Giữ các snippet internal hiện có.

---

## 📌 [2026-11-12] - Snippet internal validator và completion generic C#

* Thêm snippet `internal`: namespace, `internal sealed class` theo tên file và `AbstractValidator<CreateAssetCommand>` với placeholder sửa kiểu command.
* Với completion kiểu generic của Roslyn có label `Type<T>` nhưng text edit chỉ chèn `Type`, chuyển thành snippet `Type<T>` có placeholder. Giữ range, additionalTextEdits và snippet server đã cung cấp; không thêm dấu generic khi đã có `<` phía sau con trỏ.

---

## 📌 [2026-11-12] - Bỏ XML comment khỏi snippet C#

* Các snippet `class`, `interface`, `record`, `enum`, `struct` và `aclass` không còn tự chèn `/** ... */` trước khai báo. Ví dụ `CreateAssetCommand` giờ được tạo trực tiếp mà không có comment rỗng.

---

## 📌 [2026-11-12] - Sửa `<leader>n` cho multicursor

* Đặt mapping multicursor `<leader>n` ở chế độ `nowait` và `silent`, tránh chờ prefix hoặc bị mapping leader khác giữ phím. Giữ `<leader>N` để thêm match theo chiều ngược lại và không thay motion Colemak `n = h`.

---

## 📌 [2026-11-11] - Sửa Shift-I/E kéo dòng khi điền tham số snippet

* Nguyên nhân: mapping mode `v` gồm cả Visual và Select; LuaSnip dùng Select mode để chọn placeholder, nên gõ `I` trong `Id` chạy lệnh kéo dòng lên.
* Chuyển mapping kéo dòng `I` và `E` sang mode `x` (Visual only). Giữ thao tác kéo dòng khi chọn Visual và cho phép gõ chữ hoa bình thường trong Select/snippet.

---

## 📌 [2026-11-11] - Phục hồi Tab mở bảng và chèn gợi ý trong command mode

* Đổi mapping cmdline Tab/Ctrl-e từ `show` sang `show_and_insert_or_accept_single`, theo preset gốc của Blink: mở menu và chèn item được chọn; nếu chỉ còn một item thì chấp nhận gợi ý. Nhấn tiếp để chọn item tiếp theo khi có nhiều kết quả.
* Shift-Tab/Ctrl-i tương ứng mở/chọn từ cuối hoặc đi về trước. Giữ ghost text làm preview và auto_insert khi chọn; không tự thực thi command chỉ vì chấp nhận completion. Không thay mapping Insert mode.

---

## 📌 [2026-11-11] - Autosave khi chuyển buffer, không hiện thông báo lưu thành công

* Bật autosave chỉ trên `BufLeave`; không ghi trên InsertLeave hoặc FocusLost.
* Dùng `silent update` và `shortmess+=W` để ẩn thông báo ghi thành công, kể cả Ctrl-s/`:w`. Giữ báo lỗi ghi và cảnh báo xung đột bên ngoài; không ghi đè file đã đổi trên đĩa. Bỏ qua buffer đặc biệt/readonly/chưa đặt tên.
* Giữ backup, persistent undo, swapfile tắt và formatter khi lưu như hiện tại. Formatter vẫn có thể tốn thời gian lúc autosave.

---

## 📌 [2026-11-11] - Tắt autosave để tránh khựng và thông báo khi chuyển buffer

* **Yêu cầu:** Không tự ghi file khi chuyển buffer/mất focus/thoát Insert mode.
* **Thay đổi:** Bỏ toàn bộ callback autosave và lệnh AutoSaveToggle trong `core/persistence.lua`; giữ backup tập trung, persistent undo và swapfile tắt. Xóa các hook cũ khi nạp lại module. Chỉ checktime khi FocusGained, không chạy lúc BufEnter.
* **Cách lưu:** Chủ động dùng Ctrl-s hoặc `:w`; `:wa` lưu tất cả buffer sửa đổi có thể ghi. Formatter vẫn chạy khi người dùng lưu.
* **Phục hồi:** Undo/backup bảo vệ trạng thái đã ghi, không bảo vệ phím vừa gõ chưa lưu khi crash. `:mksession` lưu danh sách buffer/bố cục/vị trí, không lưu nội dung buffer chưa ghi. Detach tmux giữ tiến trình Neovim cùng buffer khi server còn chạy; reboot/kill server không giữ RAM của tiến trình.
* **Tmux:** Sửa lỗi chính tả `@resurrect-stratery-nvim` thành `@resurrect-strategy-nvim`. Resurrect cần `Session.vim` trong working directory của pane để khôi phục phiên editor; cấu hình này không tự tạo file session. Continuum tự lưu trạng thái tmux, không tự lưu nội dung file đang sửa.

---

## 📌 [2026-11-11] - Đồng bộ navigation Blink cho Tab và Colemak D-H

* Dropdown mở: Tab/Ctrl-e chọn tiếp, Shift-Tab/Ctrl-i chọn trước. Dropdown đóng: cùng bộ phím nhảy tiến/lùi giữa tham số snippet. Enter chấp nhận item. Giữ Ctrl-j/Ctrl-k làm phím thay thế.
* Áp dụng bộ phím chọn item tương tự cho command-line completion.
* Bật `extended-keys` trong tmux và capability `extkeys` cho xterm-ghostty/xterm-256color để hỗ trợ phân biệt Ctrl-i và Tab. Terminal vẫn phải hỗ trợ giao thức phím mở rộng; terminal gửi mã legacy sẽ không phân biệt được. Reload tmux và mở lại Neovim để đàm phán lại phím.

---

## 📌 [2026-11-10] - Chọn method Roslyn thật và điền tham số như Java

* **Làm rõ yêu cầu:** Người dùng muốn gõ `Error.` và chọn method thật trong Blink để điền tham số bằng Tab, không phải nhớ trigger snippet thủ công.
* **Thay đổi:** Thêm `lua/core/csharp-completion.lua`, nối vào `sources.providers.lsp.transform_items`. Khi Roslyn resolve completion của method C#, đọc chữ ký trong detail/documentation và dùng parser C# để lấy tên tham số. Chuyển lời gọi thành LSP snippet để LuaSnip/Blink nhảy bằng Tab/Shift-Tab. Giữ text-edit range và additional edits (ví dụ using) của server.
* **Giới hạn/fallback:** Chỉ xử lý method C# từ easy_dotnet/Roslyn, không đổi Java. Giữ completion gốc nếu không có chữ ký phù hợp, không có parser, chữ ký không parse được, server đã trả snippet hoặc completion có command riêng. Không chèn thêm ngoặc/tham số khi sau con trỏ đã có danh sách argument. Overload theo chữ ký server đang trả; người dùng có thể xem các overload qua signature help. Các trigger `err...` cũ vẫn là lựa chọn bổ sung.
* **Kiểm chứng:** Với project C# tạm và Roslyn thật, resolve itemDefaults đầy đủ rồi nhận được chữ ký `Failure(string code, string description)` trong documentation. Chuyển thành `Failure(${1:code}, ${2:description})$0`, mở rộng bằng LuaSnip và nhảy qua Blink thành công. Kiểm tra thêm generic/tuple parameter types, default chứa dấu phẩy, ref/out, không có tham số, giữ import/range và các fallback. Kiểm tra này dùng Roslyn Mason của profile nvim-dotnet; chưa kiểm tra giao diện tương tác trong phiên Assetly của người dùng.
* **Cách thử:** Mở lại Neovim, chờ Roslyn tải solution; gõ `Error.` rồi chọn `Problem`/`Failure` bằng Ctrl-j/Ctrl-k, Enter để chấp nhận, điền giá trị và Tab/Shift-Tab giữa các tham số.

---

## 📌 [2026-11-10] - C# completion, signature help và snippet tham số Error

* **Yêu cầu:** Chọn completion và điền tham số bằng Tab như Java; giữ layout Cornix/Colemak D-H.
* **Roslyn (`easy-dotnet.lua`):** Khai báo dependency Blink và truyền `get_lsp_capabilities()` vào `lsp.config` để quảng bá snippet support. Bật completion từ namespace chưa import, thêm import khi chấp nhận và gợi ý trong danh sách tham số.
* **Blink (`nvim-cmp.lua`):** Bật signature help viền rounded. Tab/Shift-Tab ưu tiên nhảy snippet, sau đó mới chọn item; Ctrl-j/Ctrl-k tiếp tục chọn gợi ý, Enter chấp nhận. Không đổi motion Normal mode.
* **Snippet (`lua/snippets/cs.lua`):** Bổ sung `errfailure`, `errnotfound`, `errproblem`, `errconflict` dựa trên API Error hiện có của Assetly. Chọn snippet bằng Enter để điền code/description rồi dùng Tab hoặc Shift-Tab. Snippet không hardcode namespace hay tự thêm using; cần import đúng Error qua Roslyn hoặc code action. Các project khác cần có API Error tương ứng mới dùng được các mẫu này.
* **Kiểm chứng:** Kiểm tra schema Blink, capability snippet, cú pháp Lua; mở rộng cả bốn snippet bằng LuaSnip và nhảy forward/back qua API Blink thành công. Roslyn trong project C# tạm trả completion `Failure` dạng plain text (`insertTextFormat = 1`), nên chưa thể coi mọi method completion là snippet có tham số. Kiểm tra LSP dùng Roslyn đã có trong Mason của profile nvim-dotnet, không chạy toàn bộ phiên easy-dotnet/UI tương tác.
* **Cách thử:** Mở lại Neovim trong solution Assetly, chờ Roslyn tải project; dùng `Error`/`Error.` cho completion hoặc gõ `errfailure`, chọn mẫu, Enter và Tab điền tham số. Signature help hiện khi gõ dấu `(` hoặc `,` theo hỗ trợ server.

---

## 📌 [2026-11-10] - Rà soát cấu hình, sửa Treesitter/Obsidian/debugger và lưu file không dùng swap

* **Thiết bị và layout:** Người dùng dùng bàn phím **Cornix** với layout **Colemak D-H**. Giữ các motion `n/e/i/o` tương ứng trái/xuống/lên/phải và `j` để vào Insert mode. Khi sửa keymap về sau cần kiểm tra tương thích layout này; không giả định người dùng dùng QWERTY.
* **Treesitter:** Chuyển sang API của nhánh `main`: gọi `setup` và `install` riêng; thêm `markdown_inline`. Highlight tự bật nếu parser tồn tại; chỉ thay indent khi có parser và query `indents`. Bỏ cấu hình cũ không có tác dụng và bỏ phần indent C# trùng lặp.
* **Lưu file:** Sửa `<C-s>` trong Insert mode để thực thi lệnh lưu ngay. Giữ `swapfile = false` theo lựa chọn của người dùng.
* **Phục hồi ít gây phiền:** Đưa cơ chế lưu vào `lua/core/persistence.lua`. Autosave khi `InsertLeave`, `BufLeave`, `FocusLost`; giữ hook formatter. Undo bền vững và bản backup trước lần ghi gần nhất được lưu tập trung trong `stdpath("state")/undo` và `/backup`, không tạo file rác trong dự án. Thư mục được tạo với quyền `0700`.
* **Lỗi lưu và xung đột:** Không dùng `silent! write`. Báo lỗi ghi, không lặp cùng thông báo; bỏ qua file readonly/buffer đặc biệt. Nếu file trên đĩa thay đổi hoặc bị xóa, autosave bỏ qua để người dùng so sánh trước khi lưu. `:AutoSaveToggle` bật/tắt toàn cục; `:let b:auto_save = v:false` tắt cho buffer hiện tại.
* **Giới hạn:** Backup/undo không thay thế swap cho các phím vừa gõ chưa kịp lưu trước khi crash. Autosave có thể kích hoạt formatter và file watcher khi thoát Insert mode. Dùng `:AutoSaveToggle` trước khi thử sửa rồi muốn bỏ thay đổi.
* **Obsidian:** Chuyển từ `epwalsh/obsidian.nvim` sang `obsidian-nvim/obsidian.nvim`, pin commit `eb28dd537e930de0c2a7ea4827aaced80d37d006` và cập nhật lockfile. Bản này có LSP nội bộ để Blink nhận completion qua source `lsp` đã có. Chuyển command sang `:Obsidian <subcommand>`, cập nhật callback keymap, định dạng ngày và tùy chọn thư mục ảnh theo API mới.
* **Kiểm chứng:** Kiểm tra cú pháp Lua và StyLua; chạy headless cho autosave/backup/undo, phím lưu, lỗi ghi và xung đột bên ngoài; kiểm tra Treesitter highlight/fallback, Obsidian LSP và executable Python DAP. Đã cài Obsidian theo commit pin và các parser yêu cầu trên máy.
* **Python DAP:** Bỏ đường dẫn pyenv 3.10.14 không tồn tại; dùng Python của Mason debugpy, fallback executable `debugpy-adapter`. Nếu thiếu debugger, hiện hướng dẫn cài đặt thay vì dùng đường dẫn sai.

---

## 📌 [2026-11-10] - Căn chỉnh thụt lề, xuống dòng và format C# chuẩn như nvim-dotnet
* **File bị ảnh hưởng:**
  - `~/.config/nvim/lua/plugins/nvim-treesitter.lua`
  - `~/.config/nvim/lua/plugins/conform.lua`
  - `~/.config/nvim/ftplugin/cs.lua` (Tạo mới)
  - `~/.config/nvim/lua/plugins/mini-splitjoin.lua` (Tạo mới)
* **Nguyên nhân sự cố:**
  - `dotfiles/nvim` chưa cài đặt parser `c_sharp` cho Treesitter; hàm thụt lề `indentexpr` dùng script regex cũ của Vim (`GetCSIndent`), khiến việc bấm Enter xuống dòng bị thụt lề sai cú pháp C#.
  - `conform.nvim` thiếu cấu hình `cs = { "csharpier" }`, không tự động format ngoặc nhọn Allman style và ngắt dòng LINQ khi lưu.
  - Cài đặt chung của editor là `shiftwidth = 2`, trong khi chuẩn C# yêu cầu 4 spaces.
  - Thiếu plugin tách/gộp tham số đa dòng (`mini.splitjoin`).
* **Nội dung thay đổi:**
  - `nvim-treesitter.lua`: Thêm `"c_sharp"` vào `ensure_installed`, tải parser `c_sharp.so`, và thêm autocmd áp dụng `vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"`.
  - `ftplugin/cs.lua`: Tạo file cấu hình riêng cho C# với `shiftwidth = 4`, `tabstop = 4`, `softtabstop = 4`, `expandtab = true`.
  - `conform.lua`: Thêm `cs = { "csharpier" }` vào `formatters_by_ft` để tự động căn chỉnh và ngắt dòng chuẩn bằng CSharpier khi lưu (`:w` / `<C-s>`).
  - `mini-splitjoin.lua`: Cài đặt `echasnovski/mini.splitjoin` với phím tắt `sk` (Split dòng tham số/argument dài) và `sj` (Join gộp dòng lại).

---

## 📌 [2026-11-09] - Tắt template tự sinh của easy-dotnet, tắt swapfile & tối ưu bảo vệ dữ liệu
* **File bị ảnh hưởng:**
  - `~/.config/nvim/lua/plugins/easy-dotnet.lua`
  - `~/.config/nvim/lua/core/options.lua`
  - Thư mục swap `~/.local/state/nvim/swap/`
* **Nguyên nhân sự cố:**
  - Plugin `easy-dotnet.nvim` mặc định bật `auto_bootstrap_namespace` dạng khối (`block_scoped`), tự động chèn code boilerplate cũ mỗi khi tạo file `.cs` mới.
  - Cơ chế swapfile (`.swp`) gây rác ổ cứng và bắn cảnh báo xung đột `W325 / E325: Ignoring swapfile`.
* **Nội dung thay đổi:**
  - `easy-dotnet.lua`: Đổi `auto_bootstrap_namespace.enabled = false` để file `.cs` mới tạo hoàn toàn trống, sẵn sàng cho custom snippet.
  - `options.lua`:
    - Tắt hoàn toàn swapfile: `vim.opt.swapfile = false`. Dọn sạch toàn bộ file `.swp` cũ trên máy.
    - Kích hoạt Auto-save an toàn khi rời cửa sổ/chuyển buffer: `FocusLost`, `BufLeave` -> `silent! write`.
    - Tự động kiểm tra và reload file nếu bị sửa đổi bên ngoài: `autoread = true`, `checktime` trên `FocusGained`, `BufEnter`.
    - Giữ `writebackup = true` để tạo bản sao lưu tạm trước khi ghi đè, chống mất dữ liệu khi crash.

---

## 📌 [2026-11-08] - Tích hợp LuaSnip & Tạo bộ Custom Snippet .NET/C# động
* **File bị ảnh hưởng:**
  - `~/.config/nvim/lua/plugins/nvim-cmp.lua`
  - `~/.config/nvim/lua/snippets/cs.lua` (Tạo mới)
* **Nguyên nhân sự cố:**
  - Người dùng muốn có tính năng snippet tương tự Java (tự động phát hiện namespace từ `.csproj`, chèn doc comment, lấy tên class từ tên file).
  - Engine snippet mặc định của `blink.cmp` chỉ đọc snippet tĩnh, không hỗ trợ thực thi hàm Lua động.
* **Nội dung thay đổi:**
  - `nvim-cmp.lua`: Thêm `L3MON4D3/LuaSnip` vào dependencies của `blink.cmp`, cấu hình `snippets = { preset = "luasnip" }`, và nạp snippet từ `lua/snippets/`.
  - `cs.lua`: Viết logic Lua quét ngược thư mục tìm `.csproj` và đọc thẻ `<RootNamespace>` để tính namespace file-scoped tương đối (`namespace Project.Folder.Subfolder;`).
  - Cung cấp bộ snippet đầy đủ:
    - `class`: Sinh class, namespace và doc comment theo tên file.
    - `interface`: Tự động thêm tiền tố `I` vào tên interface nếu file chưa có.
    - `record`, `recordclass`, `enum`, `struct`, `aclass`.

---

## 📌 [2026-11-05] - Cấu hình plugin obsidian.nvim & Sửa lỗi crash FileNotFoundError
* **File bị ảnh hưởng:**
  - `~/.config/nvim/lua/plugins/obsidian.lua`
* **Nguyên nhân sự cố:**
  - Đường dẫn workspace cấu hình cũ trỏ vào `~/Documents/my-second-brain/persional/` không tồn tại, khiến plugin sập với lỗi `FileNotFoundError` khi khởi động Neovim.
* **Nội dung thay đổi:**
  - Trỏ workspace chuẩn xác vào Vault `~/Documents/my-second-brain`.
  - Tắt UI mặc định (`ui.enable = false`) để tránh xung đột giao diện với `render-markdown.nvim`.
  - Tích hợp completion với `blink.cmp` thông qua LSP nội bộ của Obsidian (`obsidian-ls`).
  - Tích hợp `telescope.nvim` làm picker tìm kiếm ghi chú.
  - Cấu hình đặt tên file theo slug tiêu đề (`note_id_func`) và bộ phím tắt tiện ích (`<leader>o...`).

---

## 📌 [2026-11-04] - Phục hồi Autocomplete, Autosuggestions & Syntax Highlighting sau khi chuyển sang Starship
* **File bị ảnh hưởng:**
  - `~/dotfiles/zsh/.zshrc`
  - `~/dotfiles/zsh/conf.d/20-plugins.zsh`
  - `~/dotfiles/zsh/conf.d/60-syntax-highlighting.zsh` (Tạo mới)
* **Nguyên nhân sự cố:**
  - Sau khi gỡ bỏ Oh-My-Zsh & Powerlevel10k, mảng `plugins=(...)` không còn tác dụng trong Zsh thuần.
  - Các plugin Homebrew (`zsh-autosuggestions`, `zsh-syntax-highlighting`) chưa được `source`, mất menu chọn Tab completion, và code bị gãy dòng khi copy-paste.
* **Nội dung thay đổi:**
  - `zsh/.zshrc`: Đưa `fpath` từ Homebrew lên trước `compinit -C` để nhận diện đầy đủ completion và tăng tốc độ mở terminal.
  - `20-plugins.zsh`: Cấu hình Tab Autocomplete (menu navigation bằng phím mũi tên, case-insensitive, colors), nạp `zsh-autosuggestions` trực tiếp từ Homebrew, liên kết phím `Ctrl + F` (`autosuggest-accept`).
  - `60-syntax-highlighting.zsh`: Nạp `zsh-syntax-highlighting` ở cuối cùng theo đúng chuẩn Zsh.

---

## 📌 [2026-10-27] - Khắc phục delay 1s phím `i` trong Visual Mode (Colemak D-H vs Neovim Default Mapping)
* **File bị ảnh hưởng:**
  - `~/.config/nvim/lua/core/keymaps.lua`
* **Nguyên nhân sự cố:**
  - Neovim 0.10+ bổ sung keymap mặc định `in` (Select child inner node) trong visual và operator-pending mode.
  - Người dùng map phím `i` thành `k` (di chuyển lên trong Colemak D-H). Khi ấn `i` trong Visual Mode, Neovim chờ 1000ms (`timeoutlen`) để xem người dùng có gõ tiếp `n` hay không, gây hiện tượng khựng/delay 1 giây.
* **Nội dung thay đổi:**
  - Thêm `pcall(vim.keymap.del, { "x", "o" }, "in")` để gỡ bỏ keymap mặc định gây xung đột.
  - Bổ sung tùy chọn `{ nowait = true }` cho phím `i`.

---

## 📌 [2026-10-27] - Kích hoạt Syntax Highlighting cho file `.hurl`
* **File bị ảnh hưởng:**
  - `~/.config/nvim/lua/plugins/nvim-treesitter.lua`
  - `~/.config/nvim/ftplugin/hurl.lua` (Tạo mới)
* **Nguyên nhân sự cố:**
  - Neovim 0.12+ và `nvim-treesitter` nhánh `main` không tự động kích hoạt highlight cho filetype `hurl`.
* **Nội dung thay đổi:**
  - Thêm `"hurl"` vào `ensure_installed` và biên dịch parser `hurl.so`.
  - Tạo `ftplugin/hurl.lua` gọi `vim.treesitter.start()` để tự động tô màu cú pháp khi mở file `.hurl`.

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
