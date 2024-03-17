from transformers import pipeline
import torch

import torch_xla.core.xla_model as xm

device = xm.xla_device()

llm = "microsoft/phi-2"
pipe = pipeline("text-generation", model=llm, torch_dtype=torch.bfloat16, device=device)
text = pipe("More and more large language models are opensourced so Hugging Face has", max_length=1024)

print(text)
