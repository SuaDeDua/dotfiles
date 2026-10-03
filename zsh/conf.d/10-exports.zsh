# PATH & Environment variables
export PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH"
export PATH="/opt/homebrew/opt/curl/bin:$PATH"
export PATH="/opt/homebrew/share/android-commandlinetools/cmdline-tools/latest/bin:$PATH"
# export JAVA_HOME="/Library/Java/JavaVirtualMachines/openjdk-23.jdk/Contents/Home"
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
export PATH=$JAVA_HOME/bin:$PATH
# export NODE_PATH=$NODE_PATH:$(npm root -g) # Gây chậm shell, đã comment lại
export LDFLAGS="-L/opt/homebrew/opt/curl/lib"
export CPPFLAGS="-I/opt/homebrew/opt/curl/include"
export PKG_CONFIG_PATH="/opt/homebrew/opt/curl/lib/pkgconfig"
export PATH=$PATH:$HOME/go/bin
export PATH="/Users/suadedua/.local/bin:$PATH"
export PATH="/opt/homebrew/opt/imagemagick-full/bin:$PATH"
# export PATH="/opt/homebrew/opt/openjdk@21/bin:$PATH"
