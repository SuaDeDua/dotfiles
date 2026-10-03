# fzf aliases
alias f=fzf
alias nlof='~/scripts/fzf_listoldfiles.sh'
alias fp='fzf --preview="bat --color=always {}"'
alias fv='nvim $(fzf -m --preview="bat --color=always {}")'

# java aliases
alias mbuild="mvn clean install -DskipTests"
alias mrun="mvn spring-boot:run"
alias mstart="mvn clean install -DskipTests && mvn spring-boot:run -pl xxxx-start -am"

# Neovim & editors
alias v=nvim
alias vim=nvim
alias nv=nvim
alias n=nvim
alias ovim=vim
alias cfg='nvim-dotnet ~/.config'
alias ndot='nvim-dotnet ~/dotfiles/nvim-dotnet/.config/nvim-dotnet/'
alias njava='nvim ~/dotfiles/nvim-java/.config/nvim-java/'
alias ghostty='nvim-dotnet ~/.config/ghostty'
alias vcf="cd ~/.config/nvim && nvim"

# Multi config nvim
alias nvim-dotnet="NVIM_APPNAME=nvim-dotnet nvim"
alias nvim-moaid="NVIM_APPNAME=nvim-moaid nvim"
alias nvim-roslyn="NVIM_APPNAME=nvim-roslyn nvim"
alias nvim-java="NVIM_APPNAME=nvim-java nvim"

# Tmux
alias ctm='nvim ~/.config/tmux/tmux.conf'
alias stm='tmux source-file ~/.config/tmux/tmux.conf \;'

# Directories
alias netp='cd ~/Documents/dotnet/NET-Project/'
alias jp='cd ~/Documents/java/'
alias note='nvim-dotnet ~/Documents/my-second-brain/'
alias dev-habit='nvim-dotnet ~/Documents/NET-Course/dev-habit/'

# Utilities
alias os='nvim-dotnet ~/.zshrc'
alias ss='source ~/.zshrc'
alias k='kubectl'
alias gr=./gradlew
alias rm="rm -i"
alias dds="find . -name '.DS_Store' -type f -delete"
alias python=python3
alias dc=docker-compose
alias lzd=lazydocker
alias gcof='git fetch && git checkout $(git branch | fzf | sed "s/^..//")'
