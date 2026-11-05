# # PATH & Environment variables
# export PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH"
# export PATH="/opt/homebrew/opt/curl/bin:$PATH"
# export PATH="/opt/homebrew/share/android-commandlinetools/cmdline-tools/latest/bin:$PATH"
# # export JAVA_HOME="/Library/Java/JavaVirtualMachines/openjdk-23.jdk/Contents/Home"
# export JAVA_HOME=$(/usr/libexec/java_home -v 21)
# export PATH=$JAVA_HOME/bin:$PATH
# # export NODE_PATH=$NODE_PATH:$(npm root -g) # Gây chậm shell, đã comment lại
# typeset -U NODE_PATH
# export NODE_PATH="$(npm root -g):$NODE_PATH"
# export LDFLAGS="-L/opt/homebrew/opt/curl/lib"
# export CPPFLAGS="-I/opt/homebrew/opt/curl/include"
# export PKG_CONFIG_PATH="/opt/homebrew/opt/curl/lib/pkgconfig"
# export PATH=$PATH:$HOME/go/bin
# export PATH="/Users/suadedua/.local/bin:$PATH"
# export PATH="/opt/homebrew/opt/imagemagick-full/bin:$PATH"
# # export PATH="/opt/homebrew/opt/openjdk@21/bin:$PATH"
# PATH & Environment variables
export PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH"
export PATH="/opt/homebrew/opt/curl/bin:$PATH"
export PATH="/opt/homebrew/share/android-commandlinetools/cmdline-tools/latest/bin:$PATH"

# Gán cứng đường dẫn tĩnh thay vì gọi subshell $(/usr/libexec/java_home -v 21)
# (Nếu đường dẫn Java 21 của bạn nằm ở /Library/Java/..., hãy thay chuỗi tương ứng)
export JAVA_HOME="/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"

# Gán cứng đường dẫn node_modules toàn cục thay vì gọi $(npm root -g)
typeset -U NODE_PATH
export NODE_PATH="/opt/homebrew/lib/node_modules:$NODE_PATH"

export LDFLAGS="-L/opt/homebrew/opt/curl/lib"
export CPPFLAGS="-I/opt/homebrew/opt/curl/include"
export PKG_CONFIG_PATH="/opt/homebrew/opt/curl/lib/pkgconfig"
export PATH="$PATH:$HOME/go/bin"
export PATH="/Users/suadedua/.local/bin:$PATH"
export PATH="/opt/homebrew/opt/imagemagick-full/bin:$PATH"
export STARSHIP_CONFIG="~/.config/starship/starship.toml"
