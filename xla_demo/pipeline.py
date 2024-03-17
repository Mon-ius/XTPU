import torch
from transformers import pipeline


llm = "microsoft/phi-2"
generator = pipeline("text-generation", model=llm, device_map="auto", torch_dtype=torch.bfloat16)

generator("More and more large language models are opensourced so Hugging Face has")
