#!/bin/bash

conda create -n d1 python=3.10 cuda opencv -c pytorch -c nvidia -y

conda activate d1 && ptxas --version

conda env config vars set LD_LIBRARY_PATH="$CONDA_PREFIX/lib"
conda env config vars set HF_HOME="/dev/shm"
conda env config vars set HF_DATASETS_CACHE="/dev/shm"
conda env config vars set HF_ENDPOINT="https://hf-mirror.com"