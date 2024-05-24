#!/bin/bash

export DEV_ROOT=$HOME
export DEV_PREFIX=$DEV_ROOT/opt/dev
export CONDA_ROOT_PREFIX=$DEV_PREFIX/conda

curl -fsSL https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -o "$DEV_ROOT/conda.sh"
mkdir -p "$DEV_PREFIX" && chmod +x "$DEV_ROOT/conda.sh"
bash "$DEV_ROOT/conda.sh" -b -p "$CONDA_ROOT_PREFIX" && rm "$DEV_ROOT/conda.sh"

. "$CONDA_ROOT_PREFIX/etc/profile.d/conda.sh"

conda create -n x3 python=3.11 pytorch torchvision pytorch-cuda=12.1 cuda -c pytorch -c nvidia -y
conda activate x3
conda env config vars set LD_LIBRARY_PATH="$CONDA_PREFIX/lib"
conda env config vars set HF_HOME=/dev/shm
conda env config vars set HF_DATASETS_CACHE="/dev/shm"
conda env config vars set HF_ENDPOINT="https://hf-mirror.com"
conda env config vars set PJRT_DEVICE=CUDA
conda env config vars set GPU_NUM_DEVICES=4

pip install https://storage.googleapis.com/pytorch-xla-releases/wheels/cuda/12.1/torch_xla-nightly-cp311-cp311-linux_x86_64.whl
python -c "import torch; print(torch.__version__, torch.version.cuda);"
python -c "import torch_xla; print(torch_xla.__version__);"
python -c "import accelerate; print(accelerate.__version__);"
python -c "from accelerate import Accelerator; accelerator = Accelerator();"
python -c "import torch; import torch_xla.core.xla_model as xm;"