#!/bin/dash

set +e

NVIDIA="https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-archive-keyring.gpg"
ARCH=$(arch)
curl -fsSL "$NVIDIA" | sudo tee /etc/apt/trusted.gpg.d/cuda-archive-keyring.gpg
echo "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/$ARCH /" | sudo tee /etc/apt/sources.list.d/cuda.list

sudo apt remove --purge -y "cuda*"
sudo apt remove --purge -y "nvidia*"
sudo apt remove --purge -y "*cublas*"
sudo apt remove --purge -y "libnvidia*"
sudo apt autoremove --purge -y

sudo apt-get update && sudo apt-get install -y cuda-toolkit cuda-drivers
sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit datacenter-gpu-manager