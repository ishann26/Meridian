Ran command: `uvicorn app:app --reload`

You are getting that error because Windows doesn't automatically add `uvicorn` to your terminal's command path.

Instead of running `uvicorn` directly, you need to tell Python to run it for you. 

Run this exact command in your terminal to start the API server:
```powershell
python -m uvicorn app:app --reload
```

Once it is running, you can test the API by opening this URL in your browser:
**http://127.0.0.1:8000/docs**

---

*(If you just want to run the terminal demo script instead of the server, use `python main.py`)*