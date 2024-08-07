#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export DEV_ROOT=$HOME
export DEV_PREFIX=$DEV_ROOT/opt/dev
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
root soft nofile 100000
root hard nofile 100000
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

curl -fsSL https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -o $DEV_ROOT/conda.sh
mkdir -p $DEV_PREFIX && chmod +x $DEV_ROOT/conda.sh
bash $DEV_ROOT/conda.sh -b -p $CONDA_ROOT_PREFIX && rm $DEV_ROOT/conda.sh

. "$CONDA_ROOT_PREFIX/etc/profile.d/conda.sh"

conda create -n xla python=3.10 datasets accelerate evaluate scikit-learn torchvision torchaudio transformers bitsandbytes diffusers segment-anything sentencepiece imageio scipy numpy pyglet trimesh gradio fire pytorch-cuda=12.1 cuda -c conda-forge -c pytorch -c nvidia -y

conda activate xla
conda env config vars set LD_LIBRARY_PATH="$CONDA_PREFIX/lib"
conda env config vars set HF_HOME="/dev/shm"
conda env config vars set HF_DATASETS_CACHE="/dev/shm"
conda env config vars set HF_ENDPOINT="https://hf-mirror.com"
conda env config vars set PJRT_DEVICE=CUDA
conda env config vars set GPU_NUM_DEVICES=4
# conda env config vars set XLA_USE_BF16=1
# conda env config vars set XLA_USE_SPMD=1
conda deactivate && sleep 5 
conda activate xla

pip install https://storage.googleapis.com/pytorch-xla-releases/wheels/cuda/12.1/torch_xla-2.2.0-cp310-cp310-manylinux_2_28_x86_64.whl
# pip uninstall -y accelerate
# pip install git+https://github.com/huggingface/accelerate

python -c "import torch; print(torch.__version__, torch.version.cuda);"
python -c "import torch_xla; print(torch_xla.__version__);"
python -c "import accelerate; print(accelerate.__version__);"
python -c "from accelerate import Accelerator; accelerator = Accelerator();"
python -c "import torch; import torch_xla.core.xla_model as xm;"

echo 'import torch
import torch_xla.core.xla_model as xm

devices = xm.get_xla_supported_devices()
for device in devices:
    print(f"- {device}")

dev = devices[0]
t1 = torch.randn(3,3,device=dev)
t2 = torch.randn(3,3,device=dev)
print(t1 + t2)' | tee /tmp/run.py

PJRT_DEVICE=CUDA python /tmp/run.py

rm -rf /tmp/xla 
git clone -j8 --depth 1 --branch master https://github.com/pytorch/xla.git /tmp/xla
PJRT_DEVICE=CUDA GPU_NUM_DEVICES=4 python /tmp/xla/test/test_train_mp_imagenet.py --fake_data

cat <<'EOF' | tee "$HOME"/.zshrc
export DEV_ROOT=$HOME
export DEV_PREFIX=$DEV_ROOT/opt/dev
export CONDA_ROOT_PREFIX=$DEV_PREFIX/conda
DISABLE_MAGIC_FUNCTIONS=true
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