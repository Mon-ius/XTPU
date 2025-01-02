#!/bin/dash

DEV_PREFIX=$HOME/.dev

sudo apt update && sudo apt install zsh bzip2 -y

mkdir -p "$DEV_PREFIX" || exit

curl -fsSL https://micro.mamba.pm/api/micromamba/linux-64/latest | tar -xvj bin/micromamba
chmod +x bin/micromamba && mv bin/micromamba bin/conda
sudo mv bin/conda /usr/bin/mamba

git clone --depth=1 https://github.com/AUTOM77/dotfile ~/dotfile
find ~/dotfile/.zsh/ -mindepth 1 -maxdepth 1 -exec mv -v {} "$HOME" \;

s1="export DEV_PREFIX=$HOME/.dev"

{ echo "$s1"; cat ~/.zshrc; } > ~/.zshrc.tmp && mv ~/.zshrc.tmp ~/.zshrc

cat <<'EOF' | tee -a ~/.zshrc

clean (){
find . -type f -name ".DS_Store" -exec rm -r {} +
find . -type f -name "*.pyc" -exec rm -f {} +
find . -type d -name "__pycache__" -exec rm -r {} +
}

export MAMBA_ROOT_PREFIX=$DEV_PREFIX/mamba
EOF

sudo chsh -s "$(which zsh)" "$USER"
