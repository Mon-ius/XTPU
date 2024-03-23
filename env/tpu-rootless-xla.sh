#!/bin/bash

export DEV_ROOT=$HOME
export DEV_PREFIX=$DEV_ROOT/opt/dev
export CONDA_ROOT_PREFIX=$DEV_PREFIX/conda

curl -fsSL https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -o $DEV_ROOT/conda.sh
mkdir -p $DEV_PREFIX && chmod +x $DEV_ROOT/conda.sh
bash $DEV_ROOT/conda.sh -b -p $CONDA_ROOT_PREFIX && rm $DEV_ROOT/conda.sh

. "$CONDA_ROOT_PREFIX/etc/profile.d/conda.sh"

conda create -n xla python=3.11 numpy -c conda-forge
conda activate xla
conda env config vars set LD_LIBRARY_PATH="$CONDA_PREFIX/lib"
conda env config vars set HF_HOME="/dev/shm"
conda env config vars set PJRT_DEVICE=TPU
# conda env config vars set XLA_USE_BF16=1
# conda env config vars set XLA_USE_SPMD=1
conda deactivate && conda activate xla

pip install 'torch~=2.2.0' --index-url https://download.pytorch.org/whl/cpu
pip install 'torch_xla[tpu]~=2.2.0' -f https://storage.googleapis.com/libtpu-releases/index.html
pip install git+https://github.com/huggingface/accelerate

python -c "import torch; print(torch.__version__);"
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

echo 'import torch, time

start_time = time.time()

net = torch.nn.Sequential(
    torch.nn.Linear(3, 8192),
    torch.nn.Conv2d(2, 32, kernel_size=1),
    torch.nn.MaxPool2d(kernel_size=2)
)

shape = (16, 2, 8192, 3)
s0 = torch.randn(shape).float()

print(net(s0).shape, f"cpu in {time.time() - start_time}")
' | tee /tmp/cpu_bench.py

echo 'import torch, time
import torch_xla.core.xla_model as xm

start_time = time.time()
xla = xm.xla_device()

net = torch.nn.Sequential(
    torch.nn.Linear(3, 8192),
    torch.nn.Conv2d(2, 32, kernel_size=1),
    torch.nn.MaxPool2d(kernel_size=2)
).to(xla)

shape = (16, 2, 8192, 3)
s0 = torch.randn(shape).float().to(xla)
print(net(s0).shape, f"xla in {time.time() - start_time}")
' | tee /tmp/xla_bench.py

echo 'import torch, time
import torch.nn as nn
import torch.nn.functional as F

start_time = time.time()

net = torch.nn.Sequential(
    torch.nn.Linear(3, 8192),
    torch.nn.Conv2d(2, 32, kernel_size=1),
    torch.nn.MaxPool2d(kernel_size=2)
)
shape = (16, 2, 8192, 3)
s0 = torch.randn(shape).float()

print(net(s0).shape, f"cpu in {time.time() - start_time}")

import torch_xla.core.xla_model as xm

start_time = time.time()
xla = xm.xla_device()

s0 = torch.randn(shape).float().to(xla)
net = torch.nn.Sequential(
    torch.nn.Linear(3, 8192),
    torch.nn.Conv2d(2, 32, kernel_size=1),
    torch.nn.MaxPool2d(kernel_size=2)
).to(xla)
print(net(s0).shape, f"xla in {time.time() - start_time}")
' | tee /tmp/rb_bench.py

PJRT_DEVICE=TPU python /tmp/run.py
python /tmp/cpu_bench.py
PJRT_DEVICE=TPU python /tmp/xla_bench.py
PJRT_DEVICE=TPU XLA_USE_BF16=1 python /tmp/xla_bench.py
PJRT_DEVICE=TPU XLA_USE_BF16=1 python /tmp/rb_bench.py
