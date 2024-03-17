from diffusers import DiffusionPipeline
from time import time
import torch
import torch_xla.core.xla_model as xm

import torch
import torch.distributed as dist
import torch_xla.core.xla_model as xm
import torch_xla.distributed.xla_multiprocessing as xmp


token='YOUR_TOKEN'
model_id = "stabilityai/stable-diffusion-xl-base-1.0"

prompts = ["a dog", "a cat", "a pig", "a shit"]

def _mp_inf_(index, word_size):
    pipe = DiffusionPipeline.from_pretrained(model_id, token=token)
    device = xm.xla_device()
    dist.init_process_group('xla', init_method='xla://')
    pipe.to(device)

    start = time()
    prompt = prompts[index]
    result = pipe(prompt, num_inference_steps=100).images[0]
    print(f'Compilation time is {time()-start} sec at :{index} with {prompt}')
    result.save(f"result_{index}.png")

if __name__ == '__main__':
    xmp.spawn(_mp_inf_, args=(0,), nprocs=4)