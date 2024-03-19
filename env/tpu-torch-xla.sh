#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export DEV_PREFIX=/opt/dev
export CONDA_ROOT_PREFIX=$DEV_PREFIX/conda

sudo apt-get -qq update
sudo apt-get -qq \
    -o Dpkg::Options::="--force-confnew" \
    -o Dpkg::Options::="--force-confdef" \
    --allow-downgrades \
    --allow-remove-essential \
    --allow-change-held-packages  \
    dist-upgrade
sudo apt-get -qq install net-tools tmux mosh zsh rclone fuse3 curl git bzip2 git-lfs
sudo apt-get -qq autoremove --purge
sudo mkdir -p $DEV_PREFIX && sudo chown -R "$USER:$USER" $DEV_PREFIX
sudo sed -i 's/#user_allow_other/user_allow_other/' /etc/fuse.conf
sudo sed -i 's/required /sufficient /' /etc/pam.d/chsh
sudo sed -i 's/AllowTcpForwarding no/AllowTcpForwarding yes/1' /etc/ssh/sshd_config
curl -fsSL git.io/ubuntu-hirsute-p10k > "$HOME"/.p10k.zsh
git clone --depth=1 https://github.com/mattmc3/antidote.git "$HOME"/.antidote

cat <<EOF | sudo tee -a /etc/containers/registries.conf
unqualified-search-registries = ["docker.io"]
EOF

cat <<EOF | sudo tee -a /etc/security/limits.conf
*       hard    nofile  100000
*       soft    nofile  100000
EOF

cat <<EOF | sudo tee "$HOME"/.zsh_plugins.txt
rupa/z
ohmyzsh/ohmyzsh
romkatv/powerlevel10k
seletskiy/zsh-git-smart-commands
zsh-users/zsh-completions

zdharma-continuum/fast-syntax-highlighting
zsh-users/zsh-autosuggestions
zsh-users/zsh-history-substring-search
EOF

cat <<EOF | sudo tee -a /etc/modules
fuse
tun
loop
ip_tables
tcp_bbr
EOF

cat <<EOF | sudo tee /etc/sysctl.d/bbr.conf
net.core.default_qdisc=fq_codel
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_moderate_rcvbuf = 1
net.core.wmem_max = 26214400
net.core.rmem_max = 26214400
EOF

curl -fsSL https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -o conda.sh
sudo mkdir -p $DEV_PREFIX && sudo chown -R "$USER:$USER" $DEV_PREFIX
sudo chmod +x conda.sh && bash conda.sh -b -p $CONDA_ROOT_PREFIX && rm conda.sh

. "$CONDA_ROOT_PREFIX/etc/profile.d/conda.sh"

conda create -n xla python=3.11 datasets accelerate evaluate scikit-learn torchvision torchaudio transformers bitsandbytes diffusers segment-anything sentencepiece imageio scipy numpy pyglet trimesh gradio fire -c conda-forge -c pytorch -y
conda activate xla
conda env config vars set LD_LIBRARY_PATH="$CONDA_PREFIX/lib"
conda env config vars set HF_HOME="/dev/shm"
conda env config vars set PJRT_DEVICE=TPU
# conda env config vars set XLA_USE_BF16=1
# conda env config vars set XLA_USE_SPMD=1
conda deactivate && conda activate xla

pip install 'torch~=2.2.0' --index-url https://download.pytorch.org/whl/cpu
pip install 'torch_xla[tpu]~=2.2.0' -f https://storage.googleapis.com/libtpu-releases/index.html

python -c "import torch; print(torch.__version__);"
python -c "import torch_xla; print(torch_xla.__version__);"
python -c "import accelerate; print(accelerate.__version__);"

python -c "import torch; import torch_xla.core.xla_model as xm;"
cat <<'EOF' | tee /tmp/run.py
import torch
import torch_xla.core.xla_model as xm

dev = xm.xla_device()
t1 = torch.randn(3,3,device=dev)
t2 = torch.randn(3,3,device=dev)
print(t1 + t2)
EOF
PJRT_DEVICE=TPU python /tmp/run.py

cat <<'EOF' | tee "$HOME"/.zshrc
export DEV_PREFIX=/opt/dev
export CONDA_ROOT_PREFIX=$DEV_PREFIX/conda

if [[ -r "$HOME/.cache/p10k-instant-prompt-$USER.zsh" ]]; then
    source "$HOME/.cache/p10k-instant-prompt-$USER.zsh"
fi
. $HOME/.antidote/antidote.zsh
antidote load
[[ ! -f $HOME/.p10k.zsh ]] || source $HOME/.p10k.zsh

if [ -f "$CONDA_ROOT_PREFIX/etc/profile.d/conda.sh" ]; then
    . "$CONDA_ROOT_PREFIX/etc/profile.d/conda.sh"
else
    export PATH="$CONDA_ROOT_PREFIX/bin:$PATH"
fi
EOF
chsh -s /bin/zsh && sudo reboot