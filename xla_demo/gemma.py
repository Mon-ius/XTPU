from transformers import AutoTokenizer, AutoModelForCausalLM

token='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'
tokenizer = AutoTokenizer.from_pretrained("google/gemma-7b", token=token)
model = AutoModelForCausalLM.from_pretrained("google/gemma-7b", 
                                            device_map='auto',
                                            attn_implementation="sdpa",
                                            low_cpu_mem_usage=True, 
                                            token=token)

input_text = "Write me a poem about Machine Learning."
input_token = tokenizer(input_text, return_tensors="pt")

outputs = model.generate(input_token.input_ids, max_length=300)

print(tokenizer.decode(outputs[0]))
