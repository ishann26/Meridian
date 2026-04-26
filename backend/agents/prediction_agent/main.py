import json
import logging
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Any, Optional

import numpy as np
import pandas as pd
import xgboost as xgb
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Paths
BASE_DIR = Path(__file__).resolve().parent
MODELS_DIR = BASE_DIR / "models"
MODEL_PATH = MODELS_DIR / "delay_predictor.json"
FEATURES_PATH = MODELS_DIR / "feature_names.json"

# Load Model and Features
model = xgb.XGBClassifier()
feature_names = []

# --- Pydantic Models ---

class LocationDict(BaseModel):
    lat: float
    lon: Optional[float] = None
    lng: Optional[float] = None

class WeatherDict(BaseModel):
    condition: str = "clear"
    severity: float = 0.5
    is_monsoon: bool = False
    temp: Optional[float] = None
    rain_mm: Optional[float] = None
    wind: Optional[float] = None
    visibility: Optional[float] = None

class PredictionRequest(BaseModel):
    planned_route: str = "South Asia"
    shipping_mode: str = "Standard Class"
    live_location: LocationDict
    weather: WeatherDict
    congestion: Optional[float] = None
    congestion_index: float = 0.5
    route_deviation_meters: float = 0.0
    order_date: datetime = Field(default_factory=datetime.now)
    cargo_weight_kg: float = 20.0
    cargo_value_inr: float = 15000.0
    cargo_department: str = "Fitness"
    cargo_type: Optional[str] = None
    historical_route_delay_rate: float = 0.5
    carrier_score: Optional[float] = None
    distance_to_next_hub_km: Optional[float] = None

class TopFeature(BaseModel):
    feature: str
    importance: float

class PredictionResponse(BaseModel):
    delay_probability: float
    predicted_delay_hours: float
    top_features: List[TopFeature]
    risk_level: str
    explanation: str

class BatchPredictionItem(PredictionRequest):
    shipment_id: str

class BatchPredictionRequest(BaseModel):
    shipments: List[BatchPredictionItem]

class BatchPredictionItemResponse(PredictionResponse):
    shipment_id: str

# --- App Initialization ---

app = FastAPI(title="Meridian Prediction Agent")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
def load_model():
    global model, feature_names
    if not MODEL_PATH.exists() or not FEATURES_PATH.exists():
        logger.warning("Model or feature names not found. Make sure to run train_model.py first.")
        return

    try:
        model.load_model(MODEL_PATH)
        with open(FEATURES_PATH, "r") as f:
            feature_names = json.load(f)
        logger.info(f"Loaded XGBoost model and {len(feature_names)} features.")
    except Exception as e:
        logger.error(f"Error loading model: {e}")

# --- Helper logic to map Pydantic -> XGBoost Features ---

def map_request_to_features(req: PredictionRequest) -> pd.DataFrame:
    """
    Map the flexible Pydantic request to the exact 12 features required by the XGBoost model.
    """
    # 1. historical_route_delay_rate
    hist_delay = req.historical_route_delay_rate
    
    # 2. weather_score (Base + Monsoon)
    weather_severity = req.weather.severity
    is_monsoon = req.weather.is_monsoon
    if req.weather.rain_mm is not None and req.weather.rain_mm > 10:
        weather_severity = max(weather_severity, 0.8)
        is_monsoon = True
    weather_score = min(1.0, weather_severity + (0.15 if is_monsoon else 0.0))
    
    # 3. congestion_index
    congestion = req.congestion if req.congestion is not None else req.congestion_index
    
    # 4. route_deviation_meters
    deviation = req.route_deviation_meters
    
    # 5. time_of_day_bin
    hour = req.order_date.hour
    if hour < 6:
        tod_bin = 0
    elif hour < 12:
        tod_bin = 1
    elif hour < 18:
        tod_bin = 2
    else:
        tod_bin = 3
        
    # 6. day_of_week
    dow = req.order_date.weekday()
    
    # 7. monsoon_flag
    monsoon_flag = 1 if is_monsoon else 0
    
    # 8. cargo_weight_kg
    weight = req.cargo_weight_kg
    
    # 9. cargo_value_inr
    value = req.cargo_value_inr
    
    # 10. cargo_type_encoded
    cargo_str = req.cargo_type if req.cargo_type else req.cargo_department
    cargo_type_encoded = hash(cargo_str) % 11
    
    # 11. carrier_score
    if req.carrier_score is not None:
        carrier_score = req.carrier_score
    else:
        carrier_map = {
            "Same Day": 1.0,
            "First Class": 0.85,
            "Second Class": 0.60,
            "Standard Class": 0.40,
        }
        carrier_score = carrier_map.get(req.shipping_mode, 0.5)
    
    # 12. distance_to_next_hub_km
    if req.distance_to_next_hub_km is not None:
        distance_hub = req.distance_to_next_hub_km
    else:
        lon = req.live_location.lon if req.live_location.lon is not None else req.live_location.lng
        from feature_engineering import _nearest_hub_distance
        distance_hub = _nearest_hub_distance(req.live_location.lat, lon or 0.0)
    
    # Build dict matching feature_names.json exactly
    feat_dict = {
        "historical_route_delay_rate": hist_delay,
        "weather_score": weather_score,
        "congestion_index": congestion,
        "route_deviation_meters": deviation,
        "time_of_day_bin": float(tod_bin),
        "day_of_week": float(dow),
        "monsoon_flag": float(monsoon_flag),
        "cargo_weight_kg": weight,
        "cargo_value_inr": value,
        "cargo_type_encoded": float(cargo_type_encoded),
        "carrier_score": carrier_score,
        "distance_to_next_hub_km": distance_hub
    }
    
    # Ensure correct order
    df = pd.DataFrame([feat_dict], columns=feature_names)
    return df.astype(np.float32)

@app.get("/health")
def health_check():
    return {
        "status": "healthy",
        "model_loaded": len(feature_names) > 0,
        "timestamp": datetime.now().isoformat()
    }

def _predict_single(request: PredictionRequest) -> PredictionResponse:
    # 1. Feature Engineering
    X_infer = map_request_to_features(request)
    
    # 2. Prediction
    proba = float(model.predict_proba(X_infer)[0, 1])
    
    # 3. Post-process to get insights
    predicted_delay_hours = proba * 48.0  # simple heuristic (max 48h)
    
    # Get feature importances (approximate local importance using global weights * feature value)
    global_importances = model.feature_importances_
    feature_vals = X_infer.iloc[0].values
    # simple proxy for local importance: value * global_importance
    local_importances = np.abs(feature_vals * global_importances)
    total = np.sum(local_importances) + 1e-9
    normalized_importances = local_importances / total
    
    top_indices = np.argsort(normalized_importances)[::-1][:3]
    top_features = [
        TopFeature(
            feature=feature_names[idx],
            importance=round(float(normalized_importances[idx]), 4)
        )
        for idx in top_indices
    ]

    # Check for critical features in the top features
    critical_feature_names = ["congestion_index", "weather_score", "route_deviation_meters"]
    has_critical_feature = any(tf.feature in critical_feature_names for tf in top_features)

    if proba >= 0.75 or (proba >= 0.60 and has_critical_feature):
        risk_level = "HIGH"
        # TODO: emit event or call monitoring/rerouting agents later
        explanation = "High risk due to critical route conditions (e.g. congestion, weather, or deviation)."
    elif proba > 0.25:
        risk_level = "MEDIUM"
        explanation = "Moderate risk. Monitor route closely."
    else:
        risk_level = "LOW"
        explanation = "Low risk. Shipment is proceeding on schedule."

    return PredictionResponse(
        delay_probability=round(proba, 4),
        predicted_delay_hours=round(predicted_delay_hours, 1),
        top_features=top_features,
        risk_level=risk_level,
        explanation=explanation
    )

@app.post("/predict", response_model=PredictionResponse)
def predict_delay(request: PredictionRequest):
    if not feature_names:
        raise HTTPException(status_code=500, detail="Model is not loaded.")
        
    try:
        return _predict_single(request)
    except Exception as e:
        logger.error(f"Prediction error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/batch_predict", response_model=List[BatchPredictionItemResponse])
def batch_predict_delay(request: BatchPredictionRequest):
    if not feature_names:
        raise HTTPException(status_code=500, detail="Model is not loaded.")
        
    try:
        results = []
        for shipment in request.shipments:
            single_resp = _predict_single(shipment)
            results.append(BatchPredictionItemResponse(
                shipment_id=shipment.shipment_id,
                delay_probability=single_resp.delay_probability,
                predicted_delay_hours=single_resp.predicted_delay_hours,
                top_features=single_resp.top_features,
                risk_level=single_resp.risk_level,
                explanation=single_resp.explanation
            ))
        return results
    except Exception as e:
        logger.error(f"Batch prediction error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
