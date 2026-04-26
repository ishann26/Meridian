"""API router for the Prediction Agent."""

from __future__ import annotations

from fastapi import APIRouter, HTTPException

from app.schemas import PredictionRequest, PredictionResponse, HealthResponse
from app.ml.predictor import PredictionAgent

router = APIRouter(prefix="/api/v1", tags=["predictions"])

# Singleton agent — loaded once at import time.
_agent: PredictionAgent | None = None


def get_agent() -> PredictionAgent:
    """Lazy-load the prediction agent."""
    global _agent
    if _agent is None:
        _agent = PredictionAgent.load()
    return _agent


@router.get("/health", response_model=HealthResponse)
async def health() -> HealthResponse:
    """Check API health and model status."""
    agent = get_agent()
    return HealthResponse(
        status="healthy",
        model_loaded=agent.is_loaded,
        model_version=agent.version,
        features_count=agent.features_count,
    )


@router.post("/predict", response_model=PredictionResponse)
async def predict(req: PredictionRequest) -> PredictionResponse:
    """Predict delay probability for a shipment.

    Accepts shipment features and returns delay probability,
    risk level, estimated delay hours, top risk factors, and
    an AI-generated recommendation.
    """
    agent = get_agent()

    if not agent.is_loaded:
        raise HTTPException(
            status_code=503,
            detail="Model not loaded. Run `python -m app.ml.train` first.",
        )

    try:
        return agent.predict(req)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/predict/batch", response_model=list[PredictionResponse])
async def predict_batch(
    requests: list[PredictionRequest],
) -> list[PredictionResponse]:
    """Batch prediction for multiple shipments."""
    agent = get_agent()

    if not agent.is_loaded:
        raise HTTPException(
            status_code=503,
            detail="Model not loaded. Run `python -m app.ml.train` first.",
        )

    if len(requests) > 100:
        raise HTTPException(
            status_code=400,
            detail="Batch size limited to 100 shipments.",
        )

    results = []
    for req in requests:
        try:
            results.append(agent.predict(req))
        except Exception as e:
            raise HTTPException(
                status_code=500,
                detail=f"Error predicting {req.shipment_id}: {e}",
            )

    return results
