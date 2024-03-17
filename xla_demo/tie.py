from accelerate import infer_auto_device_map, init_empty_weights
from transformers import AutoConfig, AutoModelForCausalLM

config = AutoConfig.from_pretrained("facebook/opt-13b")
with init_empty_weights():
    model = AutoModelForCausalLM.from_config(config)

model.tie_weights()
device_map = infer_auto_device_map(model)

print(device_map)