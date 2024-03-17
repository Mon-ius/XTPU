import torch
import torch_xla.core.xla_model as xm
from transformers import PhiForCausalLM, AutoTokenizer

device = xm.xla_device()

model = PhiForCausalLM.from_pretrained("microsoft/phi-2", device_map="auto")
tokenizer = AutoTokenizer.from_pretrained("microsoft/phi-2")

llm = model.to(device)
_s  = "This is an example script ."
_input = tokenizer(_s, return_tensors="pt").to(device)
outputs = llm.generate(_input.input_ids, max_length=100).to(device)
text = tokenizer.batch_decode(outputs,skip_special_tokens=True, clean_up_tokenization_spaces=False)[0]

print(text)