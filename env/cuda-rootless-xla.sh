#!/bin/bash

# conda create -n xla python=3.12 datasets accelerate evaluate scikit-learn torchvision torchaudio transformers bitsandbytes diffusers segment-anything sentencepiece imageio scipy numpy pyglet trimesh gradio fire pytorch-cuda=12.1 cuda -c conda-forge -c pytorch -c nvidia -y

export DEV_ROOT=$HOME
export DEV_PREFIX=$DEV_ROOT/opt/dev
export CONDA_ROOT_PREFIX=$DEV_PREFIX/conda

curl -fsSL https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -o "$DEV_ROOT/conda.sh"
mkdir -p "$DEV_PREFIX" && chmod +x "$DEV_ROOT/conda.sh"
bash "$DEV_ROOT/conda.sh" -b -p "$CONDA_ROOT_PREFIX" && rm "$DEV_ROOT/conda.sh"

. "$CONDA_ROOT_PREFIX/etc/profile.d/conda.sh"

conda create -n x3 python=3.10 pytorch torchvision accelerate transformers pytorch-cuda=12.1 cuda -c pytorch -c nvidia -y
conda activate x3
conda env config vars set LD_LIBRARY_PATH="$CONDA_PREFIX/lib"
conda env config vars set XLA_FLAGS="--xla_gpu_cuda_data_dir=$CONDA_PREFIX"
conda env config vars set HF_HOME=/dev/shm
conda env config vars set HF_DATASETS_CACHE="/dev/shm"
conda env config vars set HF_ENDPOINT="https://hf-mirror.com"
conda env config vars set PJRT_DEVICE=CUDA
conda env config vars set GPU_NUM_DEVICES=4

conda deactivate && sleep 5 
conda activate x3

pip install https://storage.googleapis.com/pytorch-xla-releases/wheels/cuda/12.1/torch_xla-2.3.0-cp310-cp310-manylinux_2_28_x86_64.whl
python -c "import torch; print(torch.__version__, torch.version.cuda);"
python -c "import torch_xla; print(torch_xla.__version__);"
python -c "import torch; import torch_xla.core.xla_model as xm;"

git clone -j8 --depth 1 --branch main https://github.com/pytorch/xla.git /tmp/xla
PJRT_DEVICE=CUDA GPU_NUM_DEVICES=4 python /tmp/xla/test/test_train_mp_imagenet.py --fake_data

cat <<'EOF' | tee -a "$HOME"/.bashrc
export DEV_ROOT=$HOME
export DEV_PREFIX=$DEV_ROOT/opt/dev
export CONDA_ROOT_PREFIX=$DEV_PREFIX/conda

if [ -f "$CONDA_ROOT_PREFIX/etc/profile.d/conda.sh" ]; then
    . "$CONDA_ROOT_PREFIX/etc/profile.d/conda.sh"
else
    export PATH="$CONDA_ROOT_PREFIX/bin:$PATH"
fi
EOF
