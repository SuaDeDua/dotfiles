---
name: nvim-csharp-completion
description: Configure and troubleshoot C# completion and LuaSnip snippets in this dotfiles repository using Neovim, Blink and Roslyn. Use for missing generic arguments, method argument placeholders, snippet navigation and completion key conflicts.
---

# Neovim C# completion

Implement the requested editor behavior; distinguish menu display, selection preview, acceptance and snippet expansion. Explain changes and verification briefly in Vietnamese.

## Repository context

Read current files before editing; these paths and conventions are starting points, not proof of current runtime behavior:

- `nvim/.config/nvim/lua/plugins/nvim-cmp.lua` configures **blink.cmp**, despite its filename. LuaSnip is its snippet backend. Its LSP provider calls `core.csharp-completion.transform_items`.
- `nvim/.config/nvim/lua/core/csharp-completion.lua` converts eligible Roslyn completion items into dynamic snippets.
- `nvim/.config/nvim/lua/snippets/cs.lua` contains explicit C# templates; `plugins/easy-dotnet.lua` configures the server.
- `nvim/.config/nvim/lua/core/keymaps.lua` holds Colemak mappings. The user uses Cornix and Colemak D-H: `n/e/i/o` are motions; inspect mappings before changing them.
- Record meaningful configuration changes and actual verification in `nvim/CHANGELOG.md`.

## Dynamic completion versus templates

Use server declarations to derive generic parameters and method arguments; do not special-case names such as Result, Failure, AbstractValidator or ICommandHandler. Explicit snippets are appropriate for class skeletons, not for reproducing each library API.

The menu's generic marker does not establish the inserted text. Inspect the selected raw item and its resolved result: `label`, `labelDetails`, `kind`, `detail`, `documentation`, `textEdit`, `insertText`, `insertTextFormat`, `command` and client identity. A type may have a plain label and put `<TValue>` only in its resolved declaration. Detail can be a namespace rather than a signature; inspect fenced C# documentation as a fallback.

When reproducing resolve manually, apply `CompletionList.itemDefaults`, especially `data`, to the selected item before `completionItem/resolve`. Do not infer a missing signature from a malformed resolve request. Check the installed Blink resolve/transform lifecycle if the hook lacks resolved data.

Examples of intended dynamic results:

```text
Result<TValue>                         -> Result<${1:TValue}>$0
Dictionary<TKey, TValue>               -> Dictionary<${1:TKey}, ${2:TValue}>$0
Result.Failure<TValue>(Error error)     -> Failure<${1:TValue}>(${2:error})$0
Result.Failure(Error error)             -> Failure(${1:error})$0
```

Preserve edit ranges (including insert/replace variants) and `additionalTextEdits` for imports. Avoid modifying other language servers, existing server snippets or command-bearing items without evidence that handling them is necessary. Keep existing argument/type-argument lists intact. If metadata is insufficient, leave the completion unchanged rather than inventing arity or parameter names.

Parse C# method parameters structurally where possible: commas also occur inside generic types, tuples, attributes and defaults. The current helper uses Tree-sitter; verify parser availability and parsing failures. Preserve required `ref`/`out` modifiers and omit extension receiver parameters. Generic declarations can contain variance `in`/`out`; those modifiers are not part of call-site type arguments.

## Snippet and keyboard conventions

Current user-requested templates:

- `internalhandler`: class name from filename; empty primary constructor → editable `ICommandHandler` → empty generic contents → body.
- `internal`: class name from filename; editable `AbstractValidator` → empty generic contents → body.
- Do not restore example project dependencies or automatic `/** ... */` comments without a request.

The user's numbered examples describe jump order, not literal text or LuaSnip node numbers. LuaSnip positive insert-node positions start at 1; `i(0)` is the final exit, typically the class body.

Preserve the configured Tab/Shift-Tab and Ctrl-e/Ctrl-i navigation unless asked otherwise. Neovim Visual mapping mode `v` includes Select mode; LuaSnip uses Select mode for placeholders. Line-move mappings intended only for Visual should use `x`, so typing uppercase `I` in `Id` does not move lines. Terminal Tab/Ctrl-i distinction depends on extended-key support; verify received keys before declaring a mapping fix.

## Verification and reporting

For a completion transformation, exercise generic and ordinary variants, multiple type parameters, preserved imports/ranges, existing `<...>`/`(...)`, and unchanged unsupported items. For snippet changes, expand with LuaSnip and check placeholder ordering. Use representative server-shaped data; label it as synthetic testing.

Use isolated Neovim (`--headless -n -u NONE -i NONE`) with the required runtime paths for focused checks. Direct logs/state to a writable temporary location when needed. Inspect error output; a zero process exit alone does not prove Lua assertions passed. Avoid unrelated full-startup plugin failures obscuring the result.

Confirm the reported issue using a real resolved Roslyn item or interactive project session when available. A successful synthetic test does **not** prove that a user's dropdown is fixed. Report separately: what changed, what passed, what remains unverified. If the user reports the same issue again, capture actual runtime data before adding another speculative transformation.

Treat previous `nowait` changes for multicursor as unverified until a reproduction establishes the cause. Do not transfer an unrelated key-conflict hypothesis into completion fixes.
