from torch_xla._internal import tpu
import torch_xla.core.xla_model as xm
import torch_xla.runtime as xr


devices = xm.get_xla_supported_devices()
num_devices = xr.global_runtime_device_count()
av_devices = tpu.num_available_devices()
for device in devices:
    print(f"- {device}")

print(num_devices, av_devices)