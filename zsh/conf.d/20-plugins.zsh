# Zsh completions
fpath=(/opt/homebrew/share/zsh/site-functions $fpath)
# Không gọi compinit ở đây vì Oh-My-Zsh đã tự gọi và có bộ đệm (cache) giúp nhanh hơn

# Oh My Zsh installation
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
# Đã xóa zsh-autocomplete (rất nặng) và fast-syntax-highlighting (xung đột)
plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-256color)
source $ZSH/oh-my-zsh.sh

# Syntax highlighting (Đã được nạp qua plugins của Oh-My-Zsh ở trên nên không cần source thủ công nữa)
# source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# fzf
eval "$(fzf --zsh 2>/dev/null)"
