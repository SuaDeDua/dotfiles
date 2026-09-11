return {
  diff = function(args)
    return vim.system({ "git", "diff", "--no-ext-diff", "HEAD~1", "HEAD" }, { text = true }):wait().stdout
  end,
}
