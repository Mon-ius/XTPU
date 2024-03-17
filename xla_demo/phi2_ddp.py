# import torch
# import torch_xla.core.xla_model as xm
from accelerate import Accelerator

accelerator = Accelerator()

def xla_real_devices(devices):
    return [_xla_real_device(device) for device in devices]

real_devices = xla_real_devices(local_devices)

# from datasets import load_dataset



# acc = Accelerator(mixed_precision="bf16")
# dev = acc.device

# print(dev)
