# XTPU

Boost AI application dev on TPU.


## I. Usage

### 1. Create on VM instance on GCP(Google Cloud Platform)

```bash
# Run on Cloud Shell Terminal
curl -fsSL bit.ly/new-gcp-vm-instance | bash
```

it will produce a file `/tmp/xvm` for remote ssh connection!

### 2. Copy or Download the ssh config file.

```bash
# Run on local machine
mv /tmp/xvm ~/.ssh/config.d
ssh x0
# ssh x1
# ssh x2
# ssh x3
# ...
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
