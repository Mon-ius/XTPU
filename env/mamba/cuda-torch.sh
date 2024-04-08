#!/bin/bash

export DEV_ROOT=$HOME
export DEV_PREFIX=$DEV_ROOT/opt/dev
export CONDA_ROOT_PREFIX=$DEV_PREFIX/conda

curl -fsSL https://micro.mamba.pm/api/micromamba/linux-64/latest | tar -xvj bin/micromamba
mkdir -p $DEV_PREFIX 
mv bin/micromamba "$DEV_PREFIX/bin/mamba"

mamba create -n infra python=3.11 torchvision torchaudio transformers bitsandbytes diffusers segment-anything imageio scipy numpy pyglet trimesh gradio fire -c conda-forge -c pytorch -y
mamba run -n xla pip install torch torch_xla -f https://storage.googleapis.com/libtpu-releases/index.html
mamba run -n xla python -c "import torch; import torch_xla.core.xla_model as xm;"

mamba env list
mamba env config vars set LD_LIBRARY_PATH=$(python3-config --prefix)/lib