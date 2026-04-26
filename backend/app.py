from fastapi import FastAPI
import joblib
import pandas as pd

app = FastAPI()

model = joblib.load("flight_delay_model.pkl")
columns = joblib.load("flight_features.pkl")

@app.post("/predict/flight")
def predict(data: dict):
    df = pd.DataFrame([data])
    df = pd.get_dummies(df)
    df = df.reindex(columns=columns, fill_value=0)

    pred = model.predict(df)[0]

    return {"delay": int(pred)}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app:app", reload=True)
