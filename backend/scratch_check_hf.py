import os
from dotenv import load_dotenv

load_dotenv(".env", override=True)
key = os.environ.get("HF_API_KEY", "")
print(f"Token length: {len(key)}")
print(f"Prefix: {key[:3]}")

import requests
r = requests.get('https://huggingface.co/api/whoami', headers={'Authorization': f'Bearer {key}'})
print('Status:', r.status_code)
print('Response:', r.json())
