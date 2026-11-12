typeset -U PATH path
typeset -U fpath FPATH

# Private environment variables (also available to IntelliJ).
if [[ -r "$HOME/dotfiles/zsh/.zshrc.local" ]]; then
  source "$HOME/dotfiles/zsh/.zshrc.local"
fi

# Cấu hình nạp biến môi trường cho IntelliJ IDEA (Tránh bị treo)
if [ -n "$INTELLIJ_ENVIRONMENT_READER" ]; then
  source "$HOME/dotfiles/zsh/conf.d/10-exports.zsh"
  return
fi

# You may need to manually set your language environment
export LANG=en_US.UTF-8
export EDITOR=/opt/homebrew/bin/nvim

# Completion paths & initialization
fpath=(/opt/homebrew/share/zsh/site-functions $fpath)
autoload -Uz compinit && compinit -C

# Starship prompt
eval "$(starship init zsh)"

# ==============================================================================
# Refactored ZSH Configuration
# ==============================================================================
ZSH_CONF_DIR="$HOME/dotfiles/zsh/conf.d"

if [[ -d "$ZSH_CONF_DIR" ]]; then
  for config_file in "$ZSH_CONF_DIR"/*.zsh; do
    source "$config_file"
  done
fi
