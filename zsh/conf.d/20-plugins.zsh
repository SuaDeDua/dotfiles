# Cấu hình Tab Autocomplete (Menu chọn bằng phím mũi tên / Tab, không phân biệt hoa thường)
zmodload -i zsh/complist
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# zsh-autosuggestions (Gợi ý lệnh mờ từ lịch sử)
if [ -f /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
  source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
  ZSH_AUTOSUGGEST_STRATEGY=(history completion)
fi

# Television installation
if command -v tv &>/dev/null; then
  eval "$(tv init zsh)"
fi

# Zoxide installation
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init zsh)"
fi

# Fzf
eval "$(fzf --zsh 2>/dev/null)"
