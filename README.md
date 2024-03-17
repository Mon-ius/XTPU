# XTPU

Boost AI and LLM application dev on TPU.

## Overview

🚧 Buiding in 2024.. 🚧

---

### 1. ⚙ New vm instance

```bash
# Run on Cloud Shell Terminal
curl -fsSL bit.ly/new-gcp-vm-instance | sh
## Here, USER=m0nius ZONE=asia-east1-b  TEMPLATE=xvm
curl -fsSL bit.ly/new-gcp-vm-instance | sh -s -- m0nius asia-east1-b xvm

# Generate new ssh key
curl -fsSL bit.ly/ssh-vm-gen | sh
```

### 2. 💽 Attach vm disk

```bash
# Run on Cloud Shell Terminal
curl -fsSL bit.ly/attach-gcp-vm-disk  | sh
## Here, DISK=disk-1 ZONE=asia-east1-b VM_NAME=xvm-1
curl -fsSL bit.ly/attach-gcp-vm-disk | sh -s -- disk-1 asia-east1-b xvm-1
```

### 3. ⛓ TPUv2, TPUv3, TPUv4, TPUv5 nodes

```bash
# Clean all queued TPU nodes
curl -fsSL bit.ly/clean-tpu-nodes | sh -s -- proj_name asia-east1-b
# Run on Cloud Shell Terminal, TPUv2
curl -fsSL bit.ly/new-tpu-v2-node | sh -s -- -y
# Run on Cloud Shell Terminal, queued TPUv4
curl -fsSL bit.ly/new-tpu-v4-queue | sh -s -- -y
```

### 4. 🫧 LLM training

#### 4.1 Miniconda Environment
```bash
curl -fsSL bit.ly/tpu-torch-xla | sh
```
#### 4.2 Model Training

```bash
# Run on Cloud Shell Terminal, TPUv2
curl -fsSL bit.ly/new-LLM-TPUv2-train | sh -s -- -y
# Run on Cloud Shell Terminal, queued TPUv4
curl -fsSL bit.ly/new-LLM-TPUv4-train | sh -s -- -y
```

### 5. 🥋 Optimize HW

```bash
# Replace OS of the VM to Alpine Linux 
curl -fsSL bit.ly/os-LLM-Alpine-acc | sh -s -- 3.19
```

### 6. 🪢 Dataset Mount

```bash
# Mount remote dataset
curl -fsSL bit.ly/remote-LLM-dataset-mount | sh -s -- dataset
```

## Refrence

1. https://github.com/pytorch-tpu/transformers/blob/llama2-google-next-training/SPMD_USER_GUIDE.md
2. https://huggingface.co/blog/accelerate-large-models
3. https://pytorch.org/blog/path-achieve-low-inference-latency/?utm_content=254892693&utm_medium=social&utm_source=linkedin&hss_channel=lcp-78618366