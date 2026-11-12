-- Convert resolved Roslyn method signatures to argument snippets for Blink.
local M = {}

local function arguments(signature, name)
	local escaped = vim.pesc(name)
	local params = signature:match(escaped .. "%s*(%b())") or signature:match(escaped .. "%b<>%s*(%b())")
	if not params then
		return
	end
	-- Parse parameter declarations with the C# grammar, not by splitting commas
	-- (generic types, tuples, attributes and default strings can contain commas).
	local source = "class __Completion { void __Method" .. params .. " {} }"
	local ok, parser = pcall(vim.treesitter.get_string_parser, source, "c_sharp")
	if not ok then
		return
	end
	local tree = parser:parse()[1]
	if tree:root():has_error() then
		return
	end
	local result = {}
	local function visit(node)
		if node:type() == "parameter" then
			local id = node:field("name")[1]
			if not id then
				return false
			end
			local text = vim.treesitter.get_node_text(node, source)
			local modifier
			for child in node:iter_children() do
				local value = vim.treesitter.get_node_text(child, source)
				if value == "ref" or value == "out" then
					modifier = value
				end
			end
			if not text:match("^%s*this%s") then
				table.insert(result, { name = vim.treesitter.get_node_text(id, source), modifier = modifier })
			end
			return true
		end
		for child in node:iter_children() do
			if visit(child) == false then
				return false
			end
		end
		return true
	end
	if visit(tree:root()) then
		return result, params
	end
end

function M.transform_items(ctx, items)
	if vim.bo.filetype ~= "cs" then
		return items
	end
	local after_cursor = vim.api.nvim_get_current_line():sub(ctx.cursor[2] + 1)
	if after_cursor:match("^%s*%(") then
		return items -- Keep an existing argument list intact.
	end
	for _, item in ipairs(items) do
		if
			item.kind == vim.lsp.protocol.CompletionItemKind.Method
			and item.insertTextFormat ~= vim.lsp.protocol.InsertTextFormat.Snippet
			and not item.command
			and (item.client_name == "easy_dotnet" or (item.client_name or ""):lower():find("roslyn", 1, true))
		then
			local doc = type(item.documentation) == "table" and item.documentation.value or item.documentation
			local signature = item.detail or (doc and doc:match("```csharp%s*\n(.-)\n```"))
			local name = item.label
			local insert = item.textEdit and item.textEdit.newText or item.insertText or name
			if signature and insert == name then
				local args, params = arguments(signature, name)
				if args then
					local placeholders = {}
					for index, arg in ipairs(args) do
						placeholders[index] = (arg.modifier and arg.modifier .. " " or "")
							.. "${"
							.. index
							.. ":"
							.. arg.name
							.. "}"
					end
					local snippet = name .. "(" .. table.concat(placeholders, ", ") .. ")$0"
					if item.textEdit then
						item.textEdit.newText = snippet
					else
						item.insertText = snippet
					end
					item.insertTextFormat = vim.lsp.protocol.InsertTextFormat.Snippet
					item.labelDetails = vim.tbl_extend("force", item.labelDetails or {}, { detail = params })
				end
			end
		end
	end
	return items
end

return M
