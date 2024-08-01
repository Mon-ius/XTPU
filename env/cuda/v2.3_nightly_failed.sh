#!/bin/bash

conda create -n x3 python=3.11 pytorch-cuda=12.1 cuda -c pytorch -c nvidia -y
conda activate x3

conda env config vars set LD_LIBRARY_PATH="$CONDA_PREFIX/lib"
conda env config vars set HF_HOME=/dev/shm
conda env config vars set PJRT_DEVICE=CUDA
conda env config vars set GPU_NUM_DEVICES=4

conda deactivate
sleep 5
conda activate x3

pip install https://storage.googleapis.com/pytorch-xla-releases/wheels/cuda/12.1/torch-nightly-cp311-cp311-linux_x86_64.whl
pip install https://storage.googleapis.com/pytorch-xla-releases/wheels/cuda/12.1/torch_xla-nightly-cp311-cp311-linux_x86_64.whl
pip install https://storage.googleapis.com/pytorch-xla-releases/wheels/cuda/12.1/torchvision-0.19.0a0+480eec2-cp311-cp311-linux_x86_64.whl

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

PJRT_DEVICE=CUDA python /tmp/run.py

rm -rf /tmp/xla 
git clone -j8 --depth 1 --branch master https://github.com/pytorch/xla.git /tmp/xla
PJRT_DEVICE=CUDA GPU_NUM_DEVICES=4 python /tmp/xla/test/test_train_mp_imagenet.py --fake_data