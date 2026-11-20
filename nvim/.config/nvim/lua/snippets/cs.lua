local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local d = ls.dynamic_node
local sn = ls.snippet_node

-- Hàm tự động phân tích đường dẫn file thành C# Namespace dựa vào .csproj
local function get_csharp_namespace()
	local file_path = vim.api.nvim_buf_get_name(0)
	if file_path == "" then
		return "MyNamespace"
	end

	file_path = vim.fs.normalize(vim.fn.fnamemodify(file_path, ":p"))
	local dir = vim.fs.dirname(file_path)

	-- Tìm vị trí file .csproj gần nhất ngược lên trên
	local root_file = vim.fs.find(function(name)
		return name:match("%.csproj$")
	end, { upward = true, path = dir })[1]

	if root_file then
		local root_dir = vim.fs.dirname(root_file)
		local project_name = vim.fs.basename(root_file):gsub("%.csproj$", "")

		-- Đọc <RootNamespace> từ .csproj nếu có chỉ định riêng
		local file = io.open(root_file, "r")
		if file then
			local content = file:read("*a")
			file:close()
			local root_ns = content:match("<RootNamespace>(.-)</RootNamespace>")
			if root_ns and root_ns ~= "" then
				project_name = root_ns
			end
		end

		-- Nếu file nằm cùng cấp với .csproj
		if dir == root_dir then
			return project_name
		end

		-- Tính namespace tương đối theo cấu trúc thư mục con
		local relative_path = dir:sub(#root_dir + 2)
		if relative_path and relative_path ~= "" then
			return project_name .. "." .. relative_path:gsub("/", "."):gsub("\\", ".")
		end

		return project_name
	end

	-- Fallback nếu không tìm thấy file .csproj: lấy tên folder cha
	local parent = vim.fs.basename(dir)
	return (parent and parent ~= "") and parent or "MyNamespace"
end

-- Hàm lấy tên class dựa trên tên file .cs hiện tại
local function get_class_name()
	local filename = vim.fs.basename(vim.api.nvim_buf_get_name(0))
	if filename and filename:match("%.cs$") then
		return filename:gsub("%.cs$", "")
	end
	return "ClassName"
end

-- Hàm lấy tên interface dựa trên tên file (tự động thêm tiền tố 'I' nếu file chưa có)
local function get_interface_name()
	local name = get_class_name()
	if name == "ClassName" then
		return "IInterface"
	end
	if not name:match("^I[A-Z]") then
		return "I" .. name
	end
	return name
end

-- Snippet sinh từ code trong repo: build(class, namespace) trả text có placeholder (core.csharp-source),
-- hoặc nil để dùng fallback(). Lỗi khi sinh được báo ra và cũng rơi về fallback.
local function generated(build, fallback)
	return d(1, function()
		local ok, text = pcall(build, get_class_name(), get_csharp_namespace())
		if not ok then
			vim.notify("snippet: " .. tostring(text), vim.log.levels.WARN)
		end
		if ok and text then
			local body = require("core.csharp-source").to_snippet(text)
			return sn(nil, ls.parser.parse_snippet(nil, body))
		end
		return sn(nil, fallback and fallback() or { i(1) })
	end)
end

local snippets = {
	s({
		trig = "internalhandler",
		name = "internal sealed command/query handler",
		dscr = "Handler generated from <FileName minus Handler> Command/Query; empty skeleton when not found",
	}, {
		generated(function(class, namespace)
			return require("core.csharp-scaffold").handler(class, namespace)
		end, function()
			return {
				t("namespace "),
				f(get_csharp_namespace, {}),
				t({ ";", "", "internal sealed class " }),
				f(get_class_name, {}),
				t("("),
				i(1),
				t(") : "),
				i(2, ""),
				t({ "{", "    " }),
				i(3),
				t({ "", "}" }),
			}
		end),
		i(0),
	}),

	s({
		trig = "internalendpoint",
		name = "internal static endpoint",
		dscr = "Minimal API endpoint + Request generated from <FileName>Command/Query",
	}, {
		d(1, function()
			local nodes = {}
			for _, part in ipairs(require("core.csharp-endpoint").parts(get_class_name(), get_csharp_namespace())) do
				if part.text then
					table.insert(nodes, t(vim.split(part.text, "\n", { plain = true })))
				else
					table.insert(nodes, i(part.insert, part.default))
				end
			end
			return sn(nil, nodes)
		end),
		i(0),
	}),

	s({
		trig = "internalvalidator",
		name = "internal sealed validator",
		dscr = "FluentValidation validator generated from <FileName minus Validator>; empty skeleton when not found",
	}, {
		generated(function(class, namespace)
			return require("core.csharp-scaffold").validator(class, namespace)
		end, function()
			return {
				t("namespace "),
				f(get_csharp_namespace, {}),
				t({ ";", "", "internal sealed class " }),
				f(get_class_name, {}),
				t(" : "),
				i(1, "AbstractValidator"),
				t({ "{", "    " }),
				i(2),
				t({ "", "}" }),
			}
		end),
		i(0),
	}),

	s({
		trig = "publicendpoints",
		name = "public static endpoints (folder)",
		dscr = "MapEndpoints calling X.MapEndpoint(app) for every endpoint class in this folder",
	}, {
		generated(function(class, namespace)
			return require("core.csharp-endpoint").aggregate(class, namespace)
		end),
		i(0),
	}),

	s({
		trig = "recordevent",
		name = "domain event record",
		dscr = "Domain event record with parameters inferred from Raise(new <FileName>(...))",
	}, {
		generated(function(class, namespace)
			return require("core.csharp-scaffold").domain_event(class, namespace)
		end),
		i(0),
	}),

	s({
		trig = "internal",
		name = "internal static class",
		dscr = "Internal static",
	}, {
		t("namespace "),
		f(get_csharp_namespace, {}),
		t({ ";", "", "internal static class " }),
		f(1, get_class_name, {}),
		t({ "{", "    " }),
		i(0),
		t({ "", "}" }),
	}),

	-- 1. Snippet: class
	s("class", {
		t("namespace "),
		f(get_csharp_namespace, {}),
		t({ ";", "", "public class " }),
		f(get_class_name, {}),
		t({ "", "{", "    " }),
		i(0),
		t({ "", "}" }),
	}),

	-- 2. Snippet: interface
	s("interface", {
		t("namespace "),
		f(get_csharp_namespace, {}),
		t({ ";", "", "public interface " }),
		f(get_interface_name, {}),
		t({ "", "{", "    " }),
		i(0),
		t({ "", "}" }),
	}),

	-- 3. Snippet: record (Positional / Primary constructor)
	s("record", {
		t("namespace "),
		f(get_csharp_namespace, {}),
		t({ ";", "", "public sealed record " }),
		f(get_class_name, {}),
		t("("),
		i(1),
		t({ ");" }),
	}),

	-- 4. Snippet: record class (Có body {})
	s("recordclass", {
		t("namespace "),
		f(get_csharp_namespace, {}),
		t({ ";", "", "public record " }),
		f(get_class_name, {}),
		t({ "", "{", "    " }),
		i(0),
		t({ "", "}" }),
	}),

	-- 5. Snippet: enum
	s("enum", {
		t("namespace "),
		f(get_csharp_namespace, {}),
		t({ ";", "", "public enum " }),
		f(get_class_name, {}),
		t({ "", "{", "    " }),
		i(0),
		t({ "", "}" }),
	}),

	-- 6. Snippet: struct (readonly struct)
	s("struct", {
		t("namespace "),
		f(get_csharp_namespace, {}),
		t({ ";", "", "public readonly struct " }),
		f(get_class_name, {}),
		t({ "", "{", "    " }),
		i(0),
		t({ "", "}" }),
	}),

	-- 7. Snippet: abstract class
	s("aclass", {
		t("namespace "),
		f(get_csharp_namespace, {}),
		t({ ";", "", "public abstract class " }),
		f(get_class_name, {}),
		t({ "", "{", "    " }),
		i(0),
		t({ "", "}" }),
	}),
}

-- Optional Result-pattern helpers for projects exposing Error.<factory>(code, description).
-- Resolve/import Error through Roslyn first; no project namespace is hardcoded here.
for _, method in ipairs({ "Failure", "NotFound", "Problem", "Conflict" }) do
	table.insert(
		snippets,
		s({
			trig = "err" .. method:lower(),
			name = "Error." .. method .. "(code, description)",
			dscr = "Error factory with editable code and description (requires matching Error API)",
		}, {
			t("Error." .. method .. '("'),
			i(1, "Domain.Error"),
			t('", "'),
			i(2, "Description"),
			t('")'),
			i(0),
		})
	)
end

return snippets
