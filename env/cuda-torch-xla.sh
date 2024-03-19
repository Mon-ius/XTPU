#!/bin/bash

export DEV_ROOT=/tmp
export DEV_PREFIX=$DEV_ROOT/opt/dev
export CONDA_ROOT_PREFIX=$DEV_PREFIX/conda

curl -fsSL https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -o /tmp/conda.sh
mkdir -p $DEV_PREFIX && chmod +x /tmp/conda.sh
bash /tmp/conda.sh -b -p $CONDA_ROOT_PREFIX && rm /tmp/conda.sh

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