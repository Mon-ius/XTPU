#!/bin/bash

conda create -n cxla python=3.10 cuda -c nvidia -y
conda activate cxla

conda env config vars set LD_LIBRARY_PATH="$CONDA_PREFIX/lib"
conda env config vars set HF_HOME=/dev/shm
conda env config vars set PJRT_DEVICE=CUDA
conda env config vars set CUDA_NUM_DEVICES=4

pip install torch torchvision torchaudio sentencepiece immutabledict fairscale
pip install https://storage.googleapis.com/pytorch-xla-releases/wheels/cuda/12.1/torch_xla-2.2.0-cp310-cp310-manylinux_2_28_x86_64.whl
pip install git+https://github.com/huggingface/accelerate

git clone -j8 --depth 1 --branch main https://github.com/google/gemma_pytorch.git /tmp/gemma_pytorch
cd /tmp/gemma_pytorch && git clone git@hf.co:google/gemma-2b-pytorch
PJRT_DEVICE=CUDA CUDA_NUM_DEVICES=4 python run_xla.py --ckp ./gemma-2b-pytorch/gemma-2b.ckpt