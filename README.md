# XTPU

Boost AI and LLM application dev on TPU.

## Overview

🚧 Buiding in 2024.. 🚧

---

### 1. ⚙ New vm instance

```bash
# Run on Cloud Shell Terminal
curl -fsSL bit.ly/new-gcp-vm-instance | sh
## Here, TEMPLATE=xvm ZONE=asia-east1-b USER=m0nius
curl -fsSL bit.ly/new-gcp-vm-instance | sh -s -- xvm asia-east1-b m0nius
```

### 2. 💽 Attach vm disk

```bash
# Run on Cloud Shell Terminal
curl -fsSL bit.ly/attach-gcp-vm-disk  | sh
## Here, VM_NAME=xvm-1 ZONE=asia-east1-b DISK=disk-01
curl -fsSL bit.ly/attach-gcp-vm-disk | sh -s -- xvm-1 asia-east1-b disk-01
```

### 3. ⛓ TPUv2, TPUv3, TPUv4, TPUv5 nodes

```bash
# Run on Cloud Shell Terminal, TPUv2
curl -fsSL bit.ly/new-tpu-v2-node | sh -s -- -y
# Run on Cloud Shell Terminal, queued TPUv4
curl -fsSL bit.ly/new-tpu-v4-queue | sh -s -- -y
```

### 4. 🫧 LLM training

```bash
# Run on Cloud Shell Terminal, TPUv2
curl -fsSL bit.ly/new-LLM-TPUv2-train | sh -s -- -y
# Run on Cloud Shell Terminal, queued TPUv4
curl -fsSL bit.ly/new-LLM-TPUv4-train | sh -s -- -y
```