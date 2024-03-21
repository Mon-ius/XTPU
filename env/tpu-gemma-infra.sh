#!/bin/bash

curl -fsSL bit.ly/cuda-torch-xla | sh

git clone -j8 --depth 1 --branch main https://github.com/Mon-ius/gemma_pytorch.git /tmp/gemma
cd /tmp/gemma && mv /tmp/gemma/scripts/run_xla.py /tmp/gemma
git clone -j8 --depth 1 --branch main git@hf.co:google/gemma-2b-pytorch

conda activate xla
python run_xla.py --ckp ./gemma-2b-pytorch/gemma-2b.ckpt
