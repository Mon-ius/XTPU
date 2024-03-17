from torch_xla._internal import tpu
import torch_xla.core.xla_model as xm

devices = xm.get_xla_supported_devices()
for device in devices:
    print(f"- {device}")

print(tpu.num_available_devices())