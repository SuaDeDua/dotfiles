# Cấu hình nạp biến môi trường cho IntelliJ IDEA (Tránh bị treo)
if [ -n "$INTELLIJ_ENVIRONMENT_READER" ]; then
  source "$HOME/dotfiles/zsh/conf.d/10-exports.zsh"
  return
fi

# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ==============================================================================
# Refactored ZSH Configuration
# ==============================================================================
ZSH_CONF_DIR="$HOME/dotfiles/zsh/conf.d"

if [[ -d "$ZSH_CONF_DIR" ]]; then
  for config_file in "$ZSH_CONF_DIR"/*.zsh; do
    source "$config_file"
  done
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
