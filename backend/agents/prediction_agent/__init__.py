"""
Prediction Agent — Public Interface

Exposes: predict(input_data) -> PredictionResult
"""

import logging
import sys
from pathlib import Path
from typing import Any, Dict

logger = logging.getLogger(__name__)

# ── Types ────────────────────────────────────────────────────

class PredictionResult:
    def __init__(self, delay_risk: float, prediction_score: float, context: Dict[str, Any]):
        self.delayRisk = delay_risk
        self.predictionScore = prediction_score
        self.context = context

    def to_dict(self) -> Dict[str, Any]:
        return {
            "delayRisk": self.delayRisk,
            "predictionScore": self.predictionScore,
            "context": self.context,
        }


# ── Public Interface ─────────────────────────────────────────

def predict(input_data: Dict[str, Any]) -> PredictionResult:
    """
    Runs the XGBoost delay prediction model on the given shipment data.

    Falls back to a heuristic result if the model is not yet trained,
    so the pipeline always progresses without crashing.

    Args:
        input_data: Shipment data dict. Expected keys: shipment_id, origin,
                    destination, context (optional weather/congestion context).

    Returns:
        PredictionResult with delayRisk, predictionScore, and context.
    """
    logger.info("[prediction_agent] Running prediction for shipment=%s", input_data.get("shipment_id"))

    # Add this agent's directory to sys.path for internal imports
    _agent_dir = str(Path(__file__).resolve().parent)
    if _agent_dir not in sys.path:
        sys.path.insert(0, _agent_dir)

    # Extract context from input_data to feed into the model request
    ctx = input_data.get("context", {})
    weather = ctx.get("weather", {"condition": "clear", "severity": 0.3})
    congestion_index = ctx.get("congestion_index", 0.3)

    try:
        import json
        from pathlib import Path as P
        import xgboost as xgb
        import numpy as np
        import pandas as pd
        from feature_engineering import _nearest_hub_distance

        agent_dir = P(__file__).resolve().parent
        model_path = agent_dir / "models" / "delay_predictor.json"
        features_path = agent_dir / "models" / "feature_names.json"

        if not model_path.exists() or not features_path.exists():
            raise FileNotFoundError("Model not trained yet.")

        model = xgb.XGBClassifier()
        model.load_model(model_path)
        with open(features_path) as f:
            feature_names = json.load(f)

        from datetime import datetime
        now = datetime.now()
        hour = now.hour
        tod_bin = 0 if hour < 6 else (1 if hour < 12 else (2 if hour < 18 else 3))
        dow = now.weekday()

        weather_severity = float(weather.get("severity", 0.3))
        is_monsoon = bool(weather.get("is_monsoon", False))
        weather_score = min(1.0, weather_severity + (0.15 if is_monsoon else 0.0))

        feat_dict = {
            "historical_route_delay_rate": ctx.get("historical_route_delay_rate", 0.5),
            "weather_score": weather_score,
            "congestion_index": congestion_index,
            "route_deviation_meters": ctx.get("route_deviation_meters", 0.0),
            "time_of_day_bin": float(tod_bin),
            "day_of_week": float(dow),
            "monsoon_flag": float(1 if is_monsoon else 0),
            "cargo_weight_kg": input_data.get("cargo_weight_kg", 20.0),
            "cargo_value_inr": input_data.get("cargo_value_inr", 15000.0),
            "cargo_type_encoded": float(hash(input_data.get("cargo_type", "General")) % 11),
            "carrier_score": ctx.get("carrier_score", 0.5),
            "distance_to_next_hub_km": ctx.get("distance_to_next_hub_km", 50.0),
        }

        df = pd.DataFrame([feat_dict], columns=feature_names).astype(np.float32)
        proba = float(model.predict_proba(df)[0, 1])

        risk_label = "HIGH" if proba >= 0.7 else ("MEDIUM" if proba >= 0.35 else "LOW")

        logger.info("[prediction_agent] delay_probability=%.3f risk=%s", proba, risk_label)

        return PredictionResult(
            delay_risk=round(proba, 4),
            prediction_score=round(proba, 4),
            context={
                "risk_level": risk_label,
                "weather_score": round(weather_score, 3),
                "congestion_index": congestion_index,
                "predicted_delay_hours": round(proba * 48.0, 1),
            },
        )

    except FileNotFoundError:
        logger.warning("[prediction_agent] Model not found. Using heuristic fallback.")
    except Exception as e:
        logger.error("[prediction_agent] Model inference failed: %s. Using heuristic fallback.", e)

    # ── Heuristic Fallback ───────────────────────────────────
    weather_severity = float(weather.get("severity", 0.3))
    delay_risk = round(min(1.0, (weather_severity * 0.4 + congestion_index * 0.6)), 4)
    risk_label = "HIGH" if delay_risk >= 0.7 else ("MEDIUM" if delay_risk >= 0.35 else "LOW")

    return PredictionResult(
        delay_risk=delay_risk,
        prediction_score=delay_risk,
        context={
            "risk_level": risk_label,
            "weather_score": weather_severity,
            "congestion_index": congestion_index,
            "predicted_delay_hours": round(delay_risk * 48.0, 1),
            "source": "heuristic_fallback",
        },
    )
