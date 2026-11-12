-- Quiet buffer-leave autosave; backups and undo stay outside projects.
local state = vim.fn.stdpath("state")
for _, dir in ipairs({ "backup", "undo" }) do
	vim.fn.mkdir(state .. "/" .. dir, "p", 448) -- 0700
end
vim.opt.backup = true
vim.opt.writebackup = true
vim.opt.backupdir = { state .. "/backup//" }
vim.opt.undofile = true
vim.opt.undodir = { state .. "/undo//" }
vim.opt.autoread = true
-- Clear the old autosave hooks even when reloading this module in a live session.
vim.g.auto_save = true
local group = vim.api.nvim_create_augroup("UserPersistence", { clear = true })
if vim.fn.exists(":AutoSaveToggle") == 2 then
	vim.api.nvim_del_user_command("AutoSaveToggle")
end

-- Suppress successful write messages for autosave, Ctrl-s and :write.
vim.opt.shortmess:append("W")

-- Check external changes on focus regain without writing buffers.
vim.api.nvim_create_autocmd("FocusGained", {
	group = group,
	command = "silent! checktime",
	desc = "Reload externally changed, unmodified files",
})

local disk = {}
local warned = {}
local function stamp(buf)
	local stat = vim.uv.fs_stat(vim.api.nvim_buf_get_name(buf))
	return stat and { size = stat.size, mtime = stat.mtime, ino = stat.ino } or false
end
local function remember(buf)
	disk[buf] = stamp(buf)
	warned[buf] = nil
end
local function warn(buf, message)
	if warned[buf] == message then
		return
	end
	warned[buf] = message
	vim.schedule(function()
		vim.notify(message, vim.log.levels.ERROR, { title = "Autosave" })
	end)
end
vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile", "BufWritePost", "BufFilePost" }, {
	group = group,
	callback = function(ev)
		remember(ev.buf)
	end,
})
for _, buf in ipairs(vim.api.nvim_list_bufs()) do
	if vim.api.nvim_buf_is_loaded(buf) then
		remember(buf)
	end
end
vim.api.nvim_create_autocmd("BufLeave", {
	group = group,
	desc = "Quietly save modified files when switching buffers",
	callback = function(ev)
		local buf = ev.buf
		local bo = vim.bo[buf]
		if
			not vim.g.auto_save
			or vim.b[buf].auto_save == false
			or not bo.modified
			or bo.readonly
			or not bo.modifiable
			or bo.buftype ~= ""
			or vim.api.nvim_buf_get_name(buf) == ""
		then
			return
		end
		if disk[buf] == nil or not vim.deep_equal(disk[buf], stamp(buf)) then
			warn(buf, "File changed on disk; autosave skipped: " .. vim.api.nvim_buf_get_name(buf))
			return
		end
		local ok, err = pcall(vim.api.nvim_buf_call, buf, function()
			vim.cmd("silent update")
		end)
		if not ok then
			warn(buf, "Could not save " .. vim.api.nvim_buf_get_name(buf) .. ": " .. tostring(err))
		end
	end,
})
vim.api.nvim_create_autocmd("BufWipeout", {
	group = group,
	callback = function(ev)
		disk[ev.buf], warned[ev.buf] = nil, nil
	end,
})
