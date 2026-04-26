"""
Risk Prediction Service — ML-based delay risk scoring.

Tries a hosted ML endpoint first, falls back to a local model,
and ultimately uses a deterministic heuristic as the final fallback.
"""

import logging
import pickle
from pathlib import Path
from typing import Optional

import httpx
import numpy as np

from ..config import settings
from ..models import ContextData, LiveState, PlannedState, RiskPrediction

logger = logging.getLogger(__name__)


class RiskPredictionService:
    """Predicts shipment delay probability using ML or heuristic fallback."""

    def __init__(self):
        self._local_model = None
        self._http: Optional[httpx.AsyncClient] = None

    async def predict(
        self,
        planned: PlannedState,
        live: LiveState,
        context: ContextData,
        time_delay_minutes: float,
        route_deviation_km: float,
    ) -> RiskPrediction:
        """
        Run risk prediction. Priority:
          1. Hosted ML endpoint
          2. Local pickled model
          3. Deterministic heuristic
        """
        # Skip placeholder endpoints
        if settings.ml.model_endpoint and not settings.ml.model_endpoint.startswith("https://your-"):
            try:
                return await self._predict_remote(
                    planned, live, context, time_delay_minutes, route_deviation_km
                )
            except Exception as e:
                logger.warning("Remote ML prediction failed, falling back: %s", e)

        # Try local model
        try:
            return self._predict_local(
                planned, live, context, time_delay_minutes, route_deviation_km
            )
        except Exception as e:
            logger.warning("Local ML prediction failed, using heuristic: %s", e)

        # Deterministic heuristic fallback
        return self._predict_heuristic(
            context, time_delay_minutes, route_deviation_km
        )

    # ── Remote ML Endpoint ──────────────────────────────────

    async def _predict_remote(self, planned, live, context, delay, route_dev) -> RiskPrediction:
        if self._http is None or self._http.is_closed:
            self._http = httpx.AsyncClient(timeout=10.0)

        features = self._build_features(planned, live, context, delay, route_dev)
        headers = {}
        if settings.ml.model_api_key:
            headers["Authorization"] = f"Bearer {settings.ml.model_api_key}"

        resp = await self._http.post(
            settings.ml.model_endpoint,
            json={"features": features},
            headers=headers,
        )
        resp.raise_for_status()
        data = resp.json()

        return RiskPrediction(
            predicted_delay_probability=data.get("probability", 0.0),
            predicted_delay_minutes=data.get("predicted_delay", 0.0),
            confidence=data.get("confidence", 0.0),
            model_version=data.get("model_version", "remote"),
        )

    # ── Local Model ─────────────────────────────────────────

    def _predict_local(self, planned, live, context, delay, route_dev) -> RiskPrediction:
        if self._local_model is None:
            model_path = Path(settings.ml.model_local_path)
            if not model_path.exists():
                raise FileNotFoundError(f"Local model not found: {model_path}")
            with open(model_path, "rb") as f:
                self._local_model = pickle.load(f)
            logger.info("Loaded local ML model from %s", model_path)

        features = self._build_features(planned, live, context, delay, route_dev)
        X = np.array([features])
        prob = float(self._local_model.predict_proba(X)[0][1])

        return RiskPrediction(
            predicted_delay_probability=prob,
            predicted_delay_minutes=delay * prob,
            confidence=0.7,
            model_version="local",
        )

    # ── Heuristic Fallback ──────────────────────────────────

    @staticmethod
    def _predict_heuristic(context: ContextData, delay: float, route_dev: float) -> RiskPrediction:
        """
        Deterministic risk scoring when no ML model is available.
        Combines time delay, route deviation, and context signals.
        """
        score = 0.0

        # Time component (0-40 points)
        if delay > 120:
            score += 40
        elif delay > 60:
            score += 25
        elif delay > 30:
            score += 15
        elif delay > 10:
            score += 5

        # Route component (0-30 points)
        if route_dev > 50:
            score += 30
        elif route_dev > 20:
            score += 20
        elif route_dev > 10:
            score += 10

        # Weather component (0-15 points)
        score += (context.weather_risk_score / 100.0) * 15

        # Flight delay component (0-15 points)
        flight_delay = getattr(context, "flight_delay_minutes", 0.0) or 0.0
        score += min(15.0, (flight_delay / 120.0) * 15)

        probability = min(1.0, score / 100.0)

        return RiskPrediction(
            predicted_delay_probability=probability,
            predicted_delay_minutes=delay * probability,
            confidence=0.5,
            model_version="heuristic-v1",
        )

    # ── Feature Engineering ─────────────────────────────────

    @staticmethod
    def _build_features(planned, live, context, delay, route_dev) -> list:
        """Build feature vector for ML model input."""
        return [
            delay,
            route_dev,
            context.weather_risk_score,
            getattr(context, "flight_delay_minutes", 0.0) or 0.0,
            live.speed_kmh or 0.0,
            planned.planned_duration_minutes,
        ]

    async def close(self):
        if self._http and not self._http.is_closed:
            await self._http.aclose()
