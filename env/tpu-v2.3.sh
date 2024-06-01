#!/bin/bash

export DEV_ROOT=$HOME
export DEV_PREFIX=$DEV_ROOT/opt/dev
export CONDA_ROOT_PREFIX=$DEV_PREFIX/conda

curl -fsSL https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -o "$DEV_ROOT/conda.sh"
mkdir -p "$DEV_PREFIX" && chmod +x "$DEV_ROOT/conda.sh"
bash "$DEV_ROOT/conda.sh" -b -p "$CONDA_ROOT_PREFIX" && rm "$DEV_ROOT/conda.sh"

. "$CONDA_ROOT_PREFIX/etc/profile.d/conda.sh"

conda create -n x2 python=3.11 numpy -c conda-forge -y
conda activate x2
conda env config vars set LD_LIBRARY_PATH="$CONDA_PREFIX/lib"
conda env config vars set HF_HOME="/dev/shm"
conda env config vars set HF_DATASETS_CACHE="/dev/shm"
conda env config vars set PJRT_DEVICE=TPU
conda deactivate && conda activate x2

pip install 'torch~=2.3.0' --index-url https://download.pytorch.org/whl/cpu
pip install 'torch_xla[tpu]~=2.3.0' -f https://storage.googleapis.com/libtpu-releases/index.html
python -c "import torch; print(torch.__version__, torch.version.cuda);"
python -c "import torch_xla; print(torch_xla.__version__);"
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

PJRT_DEVICE=TPU python /tmp/run.py
git clone -j8 --depth 1 --branch main https://github.com/pytorch/xla.git /tmp/xla
PJRT_DEVICE=TPU python /tmp/xla/test/test_train_mp_imagenet.py --fake_data
