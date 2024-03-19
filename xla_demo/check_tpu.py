from torch_xla._internal import tpu
import torch_xla.core.xla_model as xm
import torch_xla.runtime as xr

all_tpu = tpu.num_available_devices()
num_devices = xr.global_runtime_device_count()

print(num_devices, all_tpu)

devices = xm.get_xla_supported_devices()
for device in devices:
    print(f"- {device}")
