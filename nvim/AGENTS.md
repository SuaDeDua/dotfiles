# Neovim configuration guide

These instructions apply when editing anything under `nvim/`. They are shared by Codex and other agents that read `AGENTS.md`.

## Scope

This directory is a personal Neovim distribution for macOS. Preserve existing uncommitted changes and inspect the current configuration before editing. Record meaningful changes in `CHANGELOG.md`.

## User conventions

- Keyboard: Colemak-DH with Cornix layout.
- Do not assume QWERTY motion keys. Check `lua/core/keymaps.lua` before changing mappings.
- Completion uses `saghen/blink.cmp`, with LuaSnip as the snippet backend, even though the main file is named `lua/plugins/nvim-cmp.lua`.
- C# completion is provided by Roslyn/easy-dotnet. Dynamic completion should use resolved server metadata instead of hardcoding project type names.
- Formatting is managed by Conform.nvim on save: C# uses CSharpier, Lua uses StyLua, and SQL/PostgreSQL uses SQLFluff with the PostgreSQL dialect.
- PostgreSQL completion/diagnostics use the `postgres_lsp` server when `postgres-language-server` is installed; formatter and language server are separate.
- SQL embedded inside a C# interpolated/raw string is still part of the C# buffer; Conform does not safely rewrite that embedded region automatically. Format it in a `.sql` buffer or use a dedicated SQL-aware workflow. `:SqlFormat` / `<leader>fq` (`lua/core/sql-format.lua`, pg_format) formats a visually selected SQL block inside a raw string while keeping its indentation; `:SqlSelect <Record> [alias] [schema.table]` in the same file generates a Dapper `SELECT col AS {nameof(Record.Prop)} ... FROM schema.table alias` block from a record; when the entity and its EF configuration are found it reuses `csharp-scaffold.select_sql` to add JOINs via `<X>Id` foreign keys and real column names.

## Completion and snippets

- Snippet `internalendpoint` (`lua/core/csharp-endpoint.lua`) generates a Minimal API endpoint + `Request` class from the record `<FileName>Command`/`<FileName>Query` found via `rg` + Tree-sitter.
- `internalhandler`, `internalvalidator`, `recordevent` generate from existing code via `lua/core/csharp-scaffold.lua` (shared readers in `lua/core/csharp-source.lua`): handler from Command/Query + repositories + EF configuration, validator lengths from `HasMaxLength`, event parameters from `Raise(new X(...))`. They fall back to the plain skeleton when nothing is found. `:CsRegister` (`lua/core/csharp-register.lua`) adds the registration line: endpoint → same-folder `*Endpoints.cs` + `Tags` constant; `*Endpoints.cs` → `*Module.cs`; repository → `AddScoped` + `DbSet`. Snippet `publicendpoints` builds a folder's `*Endpoints.cs` from its endpoint classes; endpoint routes and tags follow the folder name. Generated code marks undecidable spots as snippet placeholders instead of guessing.
- `lua/core/csharp-refactor.lua` runs existing Roslyn code actions by title instead of reimplementing them: `:CsOrganizeUsings` (`<leader>go` in cs), `:CsSyncNamespace [dir]` (`<leader>gm`), `:CsMoveType` (`<leader>gx`). Quickfix actions such as "Remove unnecessary usings" only appear when the request includes the line's LSP diagnostics. Roslyn's "Change namespace to" edits only the file itself, so the command fixes `using` lines in referencing files afterwards.

- Preserve `textEdit` ranges, replace ranges and `additionalTextEdits` such as imports.
- A menu marker such as `<>` does not guarantee that the inserted text contains generic arguments. Inspect `label`, `detail`, `documentation`, `textEdit`, `insertText`, `insertTextFormat` and the resolved completion item.
- Derive generic parameters and method parameters from Roslyn declarations. Support multiple parameters, `ref`/`out`, generic types, tuples and defaults. Use Tree-sitter for C# parameter parsing where possible.
- Keep existing `<...>` or `(...)` after the cursor intact. If server metadata is insufficient, leave the completion unchanged.
- Keep explicit snippets reusable. Do not add project-specific dependencies or XML comments unless requested.
- LuaSnip insert nodes start at 1; `i(0)` is the final exit node. Verify Tab jump order after changing snippets.

## Keymaps and persistence

- Preserve Tab/Shift-Tab and Ctrl-e/Ctrl-i completion behavior unless the user requests a change.
- Select mode is used by LuaSnip placeholders. Visual-only line mappings should use mode `x`, not `v`, so typing uppercase letters inside a placeholder is safe.
- Swapfile is intentionally disabled. Persistent undo and backup are separate features; do not enable swapfile casually.
- Autosave is configured for buffer leave and successful write messages are suppressed. Formatter latency may still occur during a save.

## Verification

Use focused headless Neovim checks with `-n -u NONE -i NONE` and a writable temporary log/state path. Test both ordinary and generic completion, preserved imports/ranges, existing argument lists, unsupported items, and snippet placeholder navigation. Synthetic tests do not prove that the interactive Roslyn dropdown is fixed; report that distinction clearly.

Run `stylua` and `git diff --check` for Lua edits. Do not claim a runtime issue is fixed until a real reproduction or captured completion item supports it.
