import torch
import torch_xla.core.xla_model as xm
from accelerate import Accelerator
from transformers import PhiForCausalLM, AutoTokenizer

device = xm.xla_device()

acc = Accelerator(mixed_precision="bf16")

tokenizer = AutoTokenizer.from_pretrained("microsoft/phi-2")
model = PhiForCausalLM.from_pretrained("microsoft/phi-2", 
                                            device_map='auto',
                                            attn_implementation="sdpa",
                                            low_cpu_mem_usage=True)

_s  = "This is an example script ."
_input = tokenizer(_s, return_tensors="pt")
outputs = model.generate(_input.input_ids, max_length=100)
text = tokenizer.batch_decode(outputs,skip_special_tokens=True, clean_up_tokenization_spaces=False)[0]

print(text)