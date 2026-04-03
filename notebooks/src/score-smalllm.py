import json
import torch
import os
import logging
from transformers import AutoTokenizer, OPTForCausalLM

logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)

def init():
    global tokenizer, model

    base = os.environ["AZUREML_MODEL_DIR"]              # e.g. /var/azureml-app/azureml-models/.../1
    model_dir = os.path.join(base, "model")             # <- because your files are in .../1/model/

    logger.info(f"AZUREML_MODEL_DIR={base}")
    logger.info(f"Using model_dir={model_dir}")
    logger.info(f"Files in model_dir: {os.listdir(model_dir)}")

    tokenizer = AutoTokenizer.from_pretrained(model_dir, local_files_only=True)
    model = OPTForCausalLM.from_pretrained(model_dir, local_files_only=True)
    model.eval()

def run(raw_data):
    logger.info(f"raw_data={raw_data}")
    data = json.loads(raw_data)
    inputs = tokenizer(data["text"], return_tensors="pt")

    with torch.no_grad():
        output_ids = model.generate(
            **inputs,
            max_new_tokens=50,
            temperature=0.7,
            do_sample=True,
            pad_token_id=tokenizer.eos_token_id,
        )
    result = tokenizer.decode(
            output_ids[0],
            skip_special_tokens=True
        )
    logger.info(f"generated_text={result}")

    return {
        "generated_text": result
    }