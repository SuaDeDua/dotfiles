-- Commonly used command picker
return {
  -- https://github.com/DanWlker/toolbox.nvim
  'DanWlker/toolbox.nvim',
  keys = {
    {
      '<leader>tt',
      function()
        require('toolbox').show_picker()
      end,
      desc = '[T]oolbox',
      mode = { 'n', 'v' },
    },
  },
  dependencies = { 'nvim-telescope/telescope.nvim' },
  opts = {
    commands = {
      {
        name = 'Format JSON',
        execute = "%!jq '.'",
        weight = -1
      },
      {
        name = 'Format XML',
        execute = ":silent !xmllint --format % --output %",
        weight = -2
      },
      {
        name = 'Close Floating Popups',
        execute = ':lua for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do local config = vim.api.nvim_win_get_config(win); if config.relative ~= "" then vim.api.nvim_win_close(win, false); end end',
        weight = -3
      },
      {
        name = 'DOS 2 UNIX Line Endings',
        execute = ":silent !sed -i 's/\\r$//' %",
        weight = -4
      },
    },
  },
  config = true,
}
