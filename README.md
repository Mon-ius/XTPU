# XTPU

Boost AI application dev on TPU.


## I. Usage on VM Instance

### 1. Create on VM instance on GCP(Google Cloud Platform)

```bash
# Run on Cloud Shell Terminal
## Here, TEMPLATE=xvm ZONE=asia-east1-b USER=m0nius
curl -fsSL bit.ly/new-gcp-vm-instance | sh -s -- xvm asia-east1-b m0nius
```

it will produce a file `/tmp/xvm` for remote ssh connection!

### 2. Copy or Download the ssh config file.

Download the file `/tmp/xvm` to local, or just copy the content, then

```bash
# Run on local machine
mv /tmp/xvm ~/.ssh/config.d
```

### 3. Go for work :P

```bash
# Run on local machine
ssh x0
# ssh x1
# ssh x2
# ssh x3
# ...
```

## II. Usage on TPU computing resource

### 1. Create multiple TPUv2-8 nodes

```bash
# Run on Cloud Shell Terminal
curl -fsSL bit.ly/new-tpu-v2-node | sh -s -- -y
```

### 2. Create TPUv4-8 nodes in a queue

```bash
# Run on Cloud Shell Terminal
curl -fsSL bit.ly/new-tpu-v4-queue | sh -s -- -y
```