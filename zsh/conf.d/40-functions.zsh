function nvims() {
  items=("default" "nvim-dotnet" "nvim-moaid" "nvim-roslyn")
  config=$(printf "%s\n" "${items[@]}" | fzf --prompt=" Neovim Config  " --height=~50% --layout=reverse --border --exit-0)
  if [[ -z $config ]]; then
    echo "Nothing selected"
    return 0
  elif [[ $config == "default" ]]; then
    config=""
  fi
  NVIM_APPNAME=$config nvim $@
}

function efadd() {
    if [ -z "$1" ]; then
        echo "Lỗi: Bạn chưa nhập tên Migration!"
        echo "Cách dùng: efadd TenMigration"
        return 1
    fi
    dotnet ef migrations add "$1" -p src/Modules/Assets/Assetly.Modules.Assets.Infrastructure -s src/API/Assetly.Api -o Database/Migrations
}

function efup() {
    dotnet ef database update -p src/Modules/Assets/Assetly.Modules.Assets.Infrastructure -s src/API/Assetly.Api
}

gpup() {
  branch=$(git rev-parse --abbrev-ref HEAD)
  git push --set-upstream origin "$branch"
}

opg() {
  local base="$HOME/Documents/git"
  local dir
  dir=$(find "$base" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) -exec test -d {} \; -print | fzf)
  if [[ -n "$dir" ]]; then
    cd "$dir"
  else
    cd "$base"
  fi
}

op() {
  local user_dir="$HOME"
  local dir
  dir=$(find "$user_dir" -mindepth 1 -maxdepth 1 -type d  ! -name '.*' | fzf) && cd "$dir"
}

qss() {
  local dotfiles_dir="$HOME/dotfiles"
  local git_base="$HOME/Documents/git"

  if ! tmux has-session -t setting 2>/dev/null; then
    tmux new-session -d -s setting -c "$dotfiles_dir"
  fi

  local dir
  local base="$HOME/Documents/git"

  dir=$(find "$base" -mindepth 1 -maxdepth 1 -type d ! -name '.*' | fzf)

  local name="$(basename "$dir")"

  if ! tmux has-session -t "$name" 2>/dev/null; then
    tmux new-session -d -s "$name" -c "$dir"
  fi
   if [[ -n "$TMUX" ]]; then
    tmux switch-client -t "$name"
  else
    tmux attach-session -t "$name"
  fi       
}
