import os
import logging

logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)

def init():

    base = os.environ["AZUREML_MODEL_DIR"]              # e.g. /var/azureml-app/azureml-models/.../1
    model_dir = os.path.join(base, "model")             # <- because your files are in .../1/model/

    logger.info(f"AZUREML_MODEL_DIR={base}")
    logger.info(f"Using model_dir={model_dir}")
    logger.info(f"Files in model_dir: {os.listdir(model_dir)}")


def run(raw_data):
    logger.info(f"input={raw_data}")
    result = "this is my response"
    logger.info(f"generated_text={result}")
    return {   "choices": [
            {
            "index": 0,
            "message": {
                "role": "assistant",
                "content": result
            },
            "finish_reason": "stop"
            }
            ]
        }
