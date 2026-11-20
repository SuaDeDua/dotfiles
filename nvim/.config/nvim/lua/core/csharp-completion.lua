-- Convert resolved Roslyn method signatures to argument snippets for Blink.
local M = {}

-- Roslyn may put type parameters in the resolved declaration, not the label.
local function generic_type(item, after_cursor)
	local kinds = vim.lsp.protocol.CompletionItemKind
	if item.kind ~= kinds.Class and item.kind ~= kinds.Interface and item.kind ~= kinds.Struct then
		return
	end
	if after_cursor:match("^%s*<") then
		return
	end
	local name = item.label:match("^([%w_]+)")
	local insert = item.textEdit and item.textEdit.newText or item.insertText or item.label
	if not name or insert ~= name then
		return
	end
	local parameters = item.label:match("^" .. vim.pesc(name) .. "%s*<([^<>]+)>$")
	if not parameters then
		local doc = type(item.documentation) == "table" and item.documentation.value or item.documentation
		local declaration = doc and doc:match("```csharp%s*\n(.-)\n```")
		-- Only use declaration text: prose can mention unrelated generic types.
		for _, signature in ipairs({ item.detail or "", declaration or "" }) do
			parameters = signature:match("%f[%w_]" .. vim.pesc(name) .. "%s*<([^<>]+)>")
			if parameters then
				break
			end
		end
	end
	if not parameters then
		return
	end
	local placeholders = {}
	for parameter in parameters:gmatch("[^,]+") do
		parameter = vim.trim(parameter)
		parameter = parameter:gsub("^in%s+", ""):gsub("^out%s+", "")
		if not parameter:match("^[%a_][%w_]*$") then
			return
		end
		table.insert(placeholders, "${" .. (#placeholders + 1) .. ":" .. parameter .. "}")
	end
	local snippet = name .. "<" .. table.concat(placeholders, ", ") .. ">$0"
	if item.textEdit then
		item.textEdit.newText = snippet
	else
		item.insertText = snippet
	end
	item.insertTextFormat = vim.lsp.protocol.InsertTextFormat.Snippet
end

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

-- Type arguments can be omitted when every type parameter appears in a parameter type,
-- including the `this` receiver of extension methods; Failure<TValue>(Error) still needs them.
local function inferable(generic, params)
	for parameter in generic:sub(2, -2):gmatch("[^,]+") do
		parameter = vim.trim(parameter):gsub("^in%s+", ""):gsub("^out%s+", "")
		if not params:find("%f[%w_]" .. vim.pesc(parameter) .. "%f[^%w_]") then
			return false
		end
	end
	return true
end

function M.transform_items(ctx, items)
	if vim.bo.filetype ~= "cs" then
		return items
	end
	local after_cursor = vim.api.nvim_get_current_line():sub(ctx.cursor[2] + 1)
	for _, item in ipairs(items) do
		if
			item.insertTextFormat ~= vim.lsp.protocol.InsertTextFormat.Snippet
			and not item.command
			and (item.client_name == "easy_dotnet" or (item.client_name or ""):lower():find("roslyn", 1, true))
		then
			generic_type(item, after_cursor)
		end
	end
	if after_cursor:match("^%s*%(") or after_cursor:match("^%s*<") then
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
			local signature = item.detail
			local name = item.label:match("^([%w_]+)")
			if not name then
				name = item.label
			end
			if not signature or not signature:find(vim.pesc(name) .. "%s*[<(]") then
				signature = doc and doc:match("```csharp%s*\n(.-)\n```") or signature
			end
			local insert = item.textEdit and item.textEdit.newText or item.insertText or name
			if signature and insert == name then
				local args, params = arguments(signature, name)
				if args then
					local generic = signature:match(vim.pesc(name) .. "%s*(%b<>)%s*%(")
					if generic and inferable(generic, params) then
						generic = nil -- C# infers them, e.g. NotEmpty<T, TProperty>(this IRuleBuilder<T, TProperty>)
					end
					local type_placeholders = {}
					if generic then
						for parameter in generic:sub(2, -2):gmatch("[^,]+") do
							parameter = vim.trim(parameter)
							table.insert(type_placeholders, "${" .. (#type_placeholders + 1) .. ":" .. parameter .. "}")
						end
					end
					local placeholders = {}
					for index, arg in ipairs(args) do
						placeholders[index] = (arg.modifier and arg.modifier .. " " or "")
							.. "${"
							.. (index + #type_placeholders)
							.. ":"
							.. arg.name
							.. "}"
					end
					local type_arguments = generic and ("<" .. table.concat(type_placeholders, ", ") .. ">") or ""
					local snippet = name .. type_arguments .. "(" .. table.concat(placeholders, ", ") .. ")$0"
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
