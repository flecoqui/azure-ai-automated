import json
import torch
import os
import logging
from transformers import AutoTokenizer, OPTForCausalLM, AutoModelForCausalLM
MODEL_NAME = os.environ.get("HF_MODEL_NAME", "Qwen/Qwen2-1.5B-Instruct")
logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)


# Globals loaded once
tokenizer = None
model = None
device = None


def init():

    global tokenizer, model, device

    base = os.environ["AZUREML_MODEL_DIR"]              # e.g. /var/azureml-app/azureml-models/.../1
    model_dir = os.path.join(base, "model")             # <- because your files are in .../1/model/

    logger.info(f"AZUREML_MODEL_DIR={base}")
    logger.info(f"Using model_dir={model_dir}")
    logger.info(f"Files in model_dir: {os.listdir(model_dir)}")

    # Pick device
    device = "cuda" if torch.cuda.is_available() else "cpu"

    # Load tokenizer + model
    # Qwen2 model card recommends transformers>=4.37.0; it also uses apply_chat_template. [1](https://huggingface.co/Qwen/Qwen2-1.5B-Instruct)[2](https://huggingface.co/docs/transformers/model_doc/qwen2)
    tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
    model = AutoModelForCausalLM.from_pretrained(
        MODEL_NAME,
        torch_dtype="auto",
        device_map="auto" if device == "cuda" else None,
    )

    if device != "cuda":
        model.to(device)

    model.eval()

# def init():
#    global model, tokenizer
#    model_dir = "./model"  # Azure mounts model here automatically
#    tokenizer = AutoTokenizer.from_pretrained(model_dir)
#    model = OPTForCausalLM.from_pretrained(model_dir)
#    model.eval()


def _build_messages(payload: dict):
    # Accept either a raw prompt or full chat messages
    if "messages" in payload and isinstance(payload["messages"], list):
        return payload["messages"]

    prompt = payload.get("input") or payload.get("text") or payload.get("prompt") or ""
    system = payload.get("system", "You are a helpful assistant.")
    return [
        {"role": "system", "content": system},
        {"role": "user", "content": prompt},
    ]


def run(raw_data):
    logger.info(f"raw_data={raw_data}")
    try:
        payload = json.loads(raw_data) if isinstance(raw_data, (str, bytes, bytearray)) else raw_data
        messages = _build_messages(payload)
        logger.info(f"messages={messages}")

        # Qwen examples format chat with apply_chat_template(add_generation_prompt=True). [1](https://huggingface.co/Qwen/Qwen2-1.5B-Instruct)[3](https://qwen.readthedocs.io/en/v2.0/inference/chat.html)
        text = tokenizer.apply_chat_template(
            messages,
            tokenize=False,
            add_generation_prompt=True
        )

        inputs = tokenizer([text], return_tensors="pt")
        inputs = {k: v.to(model.device) for k, v in inputs.items()}

        # Generation params (override via request if you want)
        max_new_tokens = int(payload.get("max_new_tokens", 256))
        temperature = float(payload.get("temperature", 0.7))
        top_p = float(payload.get("top_p", 0.90))
        top_k = float(payload.get("top_k", 50))
        do_sample = bool(payload.get("do_sample", False))

        with torch.no_grad():
            generated_ids = model.generate(
                **inputs,
                max_new_tokens=max_new_tokens,
                do_sample=do_sample,
                temperature=temperature,
                top_p=top_p,
            )

        # Remove prompt tokens from output (as in model card). [1](https://huggingface.co/Qwen/Qwen2-1.5B-Instruct)[3](https://qwen.readthedocs.io/en/v2.0/inference/chat.html)
        gen_only = generated_ids[:, inputs["input_ids"].shape[1]:]
        response_text = tokenizer.batch_decode(gen_only, skip_special_tokens=True)[0]
        logger.info(f"generated_text={response_text}")
        return {
            "generated_text": response_text,
            "model": MODEL_NAME,
            "device": str(model.device),
        }

    except Exception as e:
        # Keep errors JSON-serializable for AzureML inference server
        return {"error": str(e)}

