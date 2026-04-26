"""Prediction Agent — loads trained XGBoost model and runs inference.

This module is the core intelligence layer. It loads the saved
model once at startup and exposes a ``predict()`` function that
the API router calls.
"""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import joblib
import xgboost as xgb

from app.schemas import PredictionRequest, PredictionResponse, RiskLevel
from app.ml.features import request_to_features, get_top_risk_factors, FEATURE_NAMES

# ── Paths ────────────────────────────────────────────────────
MODEL_DIR = Path(__file__).resolve().parent.parent.parent / "models"
MODEL_PATH = MODEL_DIR / "delay_predictor.joblib"
METADATA_PATH = MODEL_DIR / "model_metadata.json"


class PredictionAgent:
    """Stateful prediction agent wrapping the XGBoost model.

    Load once via ``PredictionAgent.load()``, then call
    ``agent.predict(request)`` for each incoming request.
    """

    def __init__(self) -> None:
        self.model: xgb.XGBClassifier | None = None
        self.metadata: dict = {}
        self._loaded = False

    @classmethod
    def load(cls) -> "PredictionAgent":
        """Factory: load model + metadata from disk."""
        agent = cls()

        if MODEL_PATH.exists():
            agent.model = joblib.load(MODEL_PATH)
            agent._loaded = True

        if METADATA_PATH.exists():
            with open(METADATA_PATH) as f:
                agent.metadata = json.load(f)

        return agent

    @property
    def is_loaded(self) -> bool:
        return self._loaded

    @property
    def version(self) -> str:
        return self.metadata.get("version", "0.0.0")

    @property
    def features_count(self) -> int:
        return self.metadata.get("features_count", len(FEATURE_NAMES))

    def predict(self, req: PredictionRequest) -> PredictionResponse:
        """Run delay prediction for a single shipment request."""
        if not self._loaded or self.model is None:
            raise RuntimeError(
                "Model not loaded. Run `python -m app.ml.train` first."
            )

        # 1. Feature engineering
        features_df = request_to_features(req)

        # 2. Predict probability
        proba = float(self.model.predict_proba(features_df)[0, 1])

        # 3. Classify risk level
        risk = self._classify_risk(proba)

        # 4. Estimate delay hours (heuristic based on probability + features)
        delay_hours = self._estimate_delay_hours(proba, req)

        # 5. Get top risk factors
        importances = self.model.feature_importances_
        top_factors = get_top_risk_factors(features_df, importances, top_n=3)

        # 6. Generate recommendation
        recommendation = self._generate_recommendation(
            risk, top_factors, req,
        )

        # 7. Confidence (inverse of prediction uncertainty)
        confidence = max(proba, 1.0 - proba)

        return PredictionResponse(
            shipment_id=req.shipment_id,
            delay_probability=round(proba, 4),
            risk_level=risk,
            estimated_delay_hours=round(delay_hours, 1),
            confidence=round(confidence, 4),
            top_risk_factors=top_factors,
            recommendation=recommendation,
        )

    @staticmethod
    def _classify_risk(proba: float) -> RiskLevel:
        if proba >= 0.75:
            return RiskLevel.critical
        if proba >= 0.50:
            return RiskLevel.high
        if proba >= 0.25:
            return RiskLevel.medium
        return RiskLevel.low

    @staticmethod
    def _estimate_delay_hours(proba: float, req: PredictionRequest) -> float:
        """Heuristic delay estimate based on probability and route factors."""
        base = proba * 48  # max ~48h at p=1.0

        # Mode multiplier
        mode_mult = {
            "sea": 1.5,
            "road": 1.2,
            "rail": 1.0,
            "air": 0.6,
        }
        mult = mode_mult.get(req.transport_mode.value, 1.0)

        # Congestion amplifier
        congestion_amp = 1.0 + req.port_congestion_index * 0.5

        return base * mult * congestion_amp

    @staticmethod
    def _generate_recommendation(
        risk: RiskLevel,
        factors: list[str],
        req: PredictionRequest,
    ) -> str:
        """Generate a contextual mitigation recommendation."""
        if risk in (RiskLevel.critical, RiskLevel.high):
            if "Port congestion" in factors:
                return (
                    f"Reroute {req.shipment_id} to an alternate port. "
                    f"Current congestion index ({req.port_congestion_index:.0%}) "
                    f"significantly increases delay risk on the "
                    f"{req.origin}–{req.destination} corridor."
                )
            if any("Storm" in f or "Rain" in f for f in factors):
                return (
                    f"Delay departure of {req.shipment_id} by 24–48h to "
                    f"avoid adverse weather. Monitor forecasts for the "
                    f"{req.origin}–{req.destination} route."
                )
            return (
                f"Consider switching {req.shipment_id} to air freight "
                f"or splitting the shipment to reduce per-unit risk."
            )

        if risk == RiskLevel.medium:
            return (
                f"Monitor {req.shipment_id} closely. Pre-position buffer "
                f"stock at {req.destination} as a contingency."
            )

        return (
            f"{req.shipment_id} is on track. No immediate action required."
        )
