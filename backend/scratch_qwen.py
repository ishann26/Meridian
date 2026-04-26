import os
from dotenv import load_dotenv
from huggingface_hub import InferenceClient

load_dotenv(".env", override=True)
client = InferenceClient(api_key=os.environ.get("HF_API_KEY"))

try:
    msg = client.chat.completions.create(
        model="Qwen/Qwen2.5-72B-Instruct",
        messages=[{"role": "user", "content": 'Reply strictly in JSON format: {"test": true}'}],
        max_tokens=20
    )
    print("Qwen 2.5:", msg.choices[0].message.content)
except Exception as e:
    print("Qwen failed:", e)
