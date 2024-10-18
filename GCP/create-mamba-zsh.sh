#!/bin/dash

DEV_PREFIX=$HOME/.dev
DEV_DOWNLOAD=$DEV_PREFIX/download
DEV_INSTALL=$DEV_PREFIX/usr
PATH=$PATH:$DEV_PREFIX/usr/bin

mkdir -p "$DEV_PREFIX" "$DEV_DOWNLOAD" "$DEV_INSTALL" || exit

NCURSES_TAR="https://invisible-mirror.net/archives/ncurses/ncurses-6.5.tar.gz"
cd "$DEV_DOWNLOAD" && mkdir ncurses && curl -fsSL "${NCURSES_TAR}" | tar -xz --strip 1 -C ncurses
cd ncurses && CXXFLAGS=" -fPIC" CFLAGS=" -fPIC" ./configure --prefix="$DEV_INSTALL" --enable-shared
make MAKEINFO=true -j"$(nproc)" && make install

ZSH_TAR="https://sourceforge.net/projects/zsh/files/latest/download"
cd "$DEV_DOWNLOAD" && mkdir zsh && curl -fsSL "${ZSH_TAR}" | tar -xJ --strip 1 -C zsh
cd zsh && CPPFLAGS="-I${DEV_INSTALL}/include" LDFLAGS="-L${DEV_INSTALL}/lib" ./configure --prefix="$DEV_INSTALL"
make MAKEINFO=true -j"$(nproc)" && make install

curl -fsSL https://micro.mamba.pm/api/micromamba/linux-64/latest | tar -xvj bin/micromamba
chmod +x bin/micromamba && mv bin/micromamba bin/mamba && mv bin "$DEV_INSTALL" && rm -rf bin

git clone --depth=1 https://github.com/AUTOM77/dotfile /tmp/dotfile
find /tmp/dotfile/.zsh/ -mindepth 1 -maxdepth 1 -exec mv -v {} "$HOME" \;

s1="export DEV_PREFIX=$HOME/.dev
export DEV_DOWNLOAD=$DEV_PREFIX/download
export DEV_INSTALL=$DEV_PREFIX/usr
export DEV_OPT=$DEV_PREFIX/opt"

{ echo "$s1"; cat ~/.zshrc; } > ~/.zshrc.tmp && mv ~/.zshrc.tmp ~/.zshrc

cat <<'EOF' | tee -a ~/.zshrc

clean (){
find . -type f -name ".DS_Store" -exec rm -r {} +
find . -type f -name "*.pyc" -exec rm -f {} +
find . -type d -name "__pycache__" -exec rm -r {} +
}

export PATH=$PATH:$DEV_PREFIX/usr/bin
export MAMBA_ROOT_PREFIX=$DEV_PREFIX/mamba
EOF
