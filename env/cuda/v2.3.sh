#!/bin/bash

conda create -n x3 python=3.10 cuda -c nvidia -y
conda activate x3

conda env config vars set LD_LIBRARY_PATH="$CONDA_PREFIX/lib"
conda env config vars set HF_HOME=/dev/shm
conda env config vars set PJRT_DEVICE=CUDA
conda env config vars set GPU_NUM_DEVICES=4

pip install torch==2.3.0.dev20240315+cu121 torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu121
pip install https://storage.googleapis.com/pytorch-xla-releases/wheels/cuda/12.1/torch_xla-2.3.0rc2-cp310-cp310-linux_x86_64.whl

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

PJRT_DEVICE=CUDA GPU_NUM_DEVICES=4 python /tmp/run.py
git clone -j8 --depth 1 --branch main https://github.com/pytorch/xla.git
PJRT_DEVICE=CUDA GPU_NUM_DEVICES=4 python xla/test/test_train_mp_imagenet.py --fake_data