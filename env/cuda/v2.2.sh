#!/bin/bash

conda config --set proxy_servers.http socks5h://127.0.0.1:7891
conda create -n c8 python=3.10 cuda -c pytorch -c nvidia -y
conda activate c8 && ptxas --version

conda env config vars set LD_LIBRARY_PATH="$CONDA_PREFIX/lib"
conda env config vars set XLA_FLAGS="--xla_gpu_cuda_data_dir=$CONDA_PREFIX"
conda env config vars set HF_HOME="/dev/shm"
conda env config vars set HF_DATASETS_CACHE="/dev/shm"
conda env config vars set HF_ENDPOINT="https://hf-mirror.com"
conda env config vars set PJRT_DEVICE=CUDA
conda env config vars set GPU_NUM_DEVICES=4

conda deactivate && sleep 5 
conda activate c8

pip install torch torchvision
pip install https://storage.googleapis.com/pytorch-xla-releases/wheels/cuda/12.1/torch_xla-2.2.0-cp310-cp310-manylinux_2_28_x86_64.whl

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


# pip install git+https://github.com/huggingface/accelerate

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
PJRT_DEVICE=CUDA GPU_NUM_DEVICES=8 python /tmp/xla/test/test_train_mp_imagenet.py --fake_data