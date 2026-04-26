"""Feature engineering for the Prediction Agent.

Converts a PredictionRequest into the numeric feature vector
expected by the XGBoost model. All encoding logic lives here
so the API layer stays clean.
"""

from __future__ import annotations

import numpy as np
import pandas as pd

from app.schemas import PredictionRequest


# ── Ordered feature names (must match training) ────────────
FEATURE_NAMES: list[str] = [
    "distance_km",
    "weight_kg",
    "cargo_value_usd",
    "port_congestion_index",
    "day_of_week",
    "hour_of_departure",
    "historical_delay_rate",
    "is_hazardous",
    "is_perishable",
    # One-hot: transport mode
    "mode_air",
    "mode_rail",
    "mode_road",
    "mode_sea",
    # One-hot: weather origin
    "weather_origin_clear",
    "weather_origin_fog",
    "weather_origin_rain",
    "weather_origin_storm",
    # One-hot: weather destination
    "weather_dest_clear",
    "weather_dest_fog",
    "weather_dest_rain",
    "weather_dest_storm",
]


def request_to_features(req: PredictionRequest) -> pd.DataFrame:
    """Convert a single prediction request into a 1-row DataFrame.

    Returns a DataFrame with columns in ``FEATURE_NAMES`` order,
    ready to be passed directly to ``model.predict()``.
    """
    row: dict[str, float] = {
        "distance_km": req.distance_km,
        "weight_kg": req.weight_kg,
        "cargo_value_usd": req.cargo_value_usd,
        "port_congestion_index": req.port_congestion_index,
        "day_of_week": float(req.day_of_week),
        "hour_of_departure": float(req.hour_of_departure),
        "historical_delay_rate": req.historical_delay_rate,
        "is_hazardous": float(req.is_hazardous),
        "is_perishable": float(req.is_perishable),
    }

    # One-hot encode transport mode
    for mode in ("air", "rail", "road", "sea"):
        row[f"mode_{mode}"] = 1.0 if req.transport_mode.value == mode else 0.0

    # One-hot encode weather (origin)
    for w in ("clear", "fog", "rain", "storm"):
        row[f"weather_origin_{w}"] = 1.0 if req.weather_origin.value == w else 0.0

    # One-hot encode weather (destination)
    for w in ("clear", "fog", "rain", "storm"):
        row[f"weather_dest_{w}"] = 1.0 if req.weather_destination.value == w else 0.0

    return pd.DataFrame([row], columns=FEATURE_NAMES)


def get_top_risk_factors(
    features: pd.DataFrame,
    feature_importances: np.ndarray,
    top_n: int = 3,
) -> list[str]:
    """Return the top-N feature names contributing most to risk.

    Combines the model's global feature importances with the
    actual feature values to identify the strongest drivers.
    """
    values = features.values[0]
    weighted = values * feature_importances
    indices = np.argsort(weighted)[::-1][:top_n]

    labels = {
        "distance_km": "Long shipping distance",
        "weight_kg": "Heavy cargo weight",
        "cargo_value_usd": "High-value cargo",
        "port_congestion_index": "Port congestion",
        "day_of_week": "Day of week pattern",
        "hour_of_departure": "Departure hour risk",
        "historical_delay_rate": "Historical delay corridor",
        "is_hazardous": "Hazardous cargo handling",
        "is_perishable": "Perishable cargo urgency",
        "mode_air": "Air transport",
        "mode_rail": "Rail transport",
        "mode_road": "Road transport",
        "mode_sea": "Sea transport",
        "weather_origin_clear": "Clear weather at origin",
        "weather_origin_fog": "Fog at origin",
        "weather_origin_rain": "Rain at origin",
        "weather_origin_storm": "Storm at origin",
        "weather_dest_clear": "Clear weather at destination",
        "weather_dest_fog": "Fog at destination",
        "weather_dest_rain": "Rain at destination",
        "weather_dest_storm": "Storm at destination",
    }

    return [
        labels.get(FEATURE_NAMES[i], FEATURE_NAMES[i])
        for i in indices
        if weighted[i] > 0
    ]
