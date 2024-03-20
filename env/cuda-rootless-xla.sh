#!/bin/bash

conda create -n xla python=3.10 datasets accelerate evaluate scikit-learn torchvision torchaudio transformers bitsandbytes diffusers segment-anything sentencepiece imageio scipy numpy pyglet trimesh gradio fire pytorch-cuda=12.1 cuda -c conda-forge -c pytorch -c nvidia -y

conda activate xla
conda env config vars set LD_LIBRARY_PATH="$CONDA_PREFIX/lib"
conda env config vars set HF_HOME=/dev/shm
conda env config vars set PJRT_DEVICE=CUDA
conda env config vars set CUDA_NUM_DEVICES=4
# conda env config vars set XLA_USE_BF16=1
# conda env config vars set XLA_USE_SPMD=1
conda deactivate && sleep 5
conda activate xla

pip install torch sentencepiece
pip install https://storage.googleapis.com/pytorch-xla-releases/wheels/cuda/12.1/torch_xla-2.2.0-cp310-cp310-manylinux_2_28_x86_64.whl
pip uninstall -y accelerate
pip install git+https://github.com/huggingface/accelerate

python -c "import torch; print(torch.__version__, torch.version.cuda);"
python -c "import torch_xla; print(torch_xla.__version__);"
python -c "import accelerate; print(accelerate.__version__);"
python -c "from accelerate import Accelerator; accelerator = Accelerator();"
python -c "import torch; import torch_xla.core.xla_model as xm;"

echo 'import torch
import torch_xla.core.xla_model as xm
import torch_xla.runtime as xr
num_devices = xr.global_runtime_device_count()
print(num_devices)

dev = xm.xla_device()
t1 = torch.randn(3,3,device=dev)
t2 = torch.randn(3,3,device=dev)
print(t1 + t2)' | tee /tmp/run.py

PJRT_DEVICE=CUDA CUDA_NUM_DEVICES=4 python /tmp/run.py
git clone -j8 --depth 1 --branch main https://github.com/pytorch/xla.git
python xla/test/test_train_mp_imagenet.py --fake_data