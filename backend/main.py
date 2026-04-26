"""
Meridian Pipeline — FastAPI Entry Point

POST /run   →  runs the full multi-agent pipeline
GET  /health → service health check

Start with:
    uvicorn main:app --host 0.0.0.0 --port 8000 --reload
"""

import logging
from datetime import datetime
from typing import Any, Dict, List, Optional

import uvicorn
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from orchestrator import run_pipeline

# ── Logging ──────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s │ %(levelname)-8s │ %(name)-25s │ %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("meridian.api")

# ── App ───────────────────────────────────────────────────────
app = FastAPI(
    title="Meridian Logistics Orchestrator",
    description=(
        "Multi-agent logistics pipeline. "
        "Chains prediction → routing → optimization → decision → execution → monitoring."
    ),
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Request / Response Models ─────────────────────────────────

class WeatherContext(BaseModel):
    condition: str = "clear"
    severity: float = Field(0.3, ge=0.0, le=1.0)
    is_monsoon: bool = False


class ShipmentContext(BaseModel):
    weather: WeatherContext = Field(default_factory=WeatherContext)
    congestion_index: float = Field(0.3, ge=0.0, le=1.0)
    weather_risk: float = Field(0.3, ge=0.0, le=1.0)
    disruption_flag: bool = False
    carrier_score: float = Field(0.5, ge=0.0, le=1.0)
    historical_route_delay_rate: float = Field(0.5, ge=0.0, le=1.0)
    distance_to_next_hub_km: Optional[float] = None


class VehicleSpec(BaseModel):
    capacity_kg: int = 2000
    max_driving_minutes: int = 480


class PipelineRequest(BaseModel):
    shipment_id: str = Field(..., examples=["SHP001"])
    origin: str = Field(..., examples=["PORT_A"])
    destination: str = Field(..., examples=["PORT_D"])
    stops: List[str] = Field(default_factory=list, examples=[["PORT_B", "PORT_C"]])
    context: ShipmentContext = Field(default_factory=ShipmentContext)
    vehicle: VehicleSpec = Field(default_factory=VehicleSpec)
    cargo_weight_kg: float = 20.0
    cargo_value_inr: float = 15000.0
    cargo_type: Optional[str] = None
    constraints: Dict[str, Any] = Field(default_factory=dict)


class PipelineMeta(BaseModel):
    shipment_id: str
    success: bool
    total_attempts: int
    reran: bool
    total_time_seconds: float


class PipelineResponse(BaseModel):
    prediction: Dict[str, Any]
    routing: Dict[str, Any]
    optimization: Dict[str, Any]
    decision: Dict[str, Any]
    execution: Dict[str, Any]
    monitoring: Dict[str, Any]
    pipeline_meta: PipelineMeta


# ── Error Handler ─────────────────────────────────────────────

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error("Unhandled exception: %s", exc, exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"detail": str(exc), "timestamp": datetime.utcnow().isoformat() + "Z"},
    )


# ── Routes ────────────────────────────────────────────────────

@app.get("/health", tags=["Health"])
def health():
    """Liveness check."""
    return {
        "status": "healthy",
        "service": "meridian-orchestrator",
        "timestamp": datetime.utcnow().isoformat() + "Z",
    }


@app.post(
    "/run",
    response_model=PipelineResponse,
    tags=["Pipeline"],
    summary="Run the full multi-agent logistics pipeline",
    response_description="Complete pipeline result with all agent outputs",
)
def run(request: PipelineRequest):
    """
    Executes the Meridian multi-agent pipeline:

    1. **Prediction** — XGBoost delay risk score
    2. **Routing** — A\\* rerouting engine
    3. **Optimization** — OR-Tools CVRP solver
    4. **Decision** — Gemini LLM action selection
    5. **Execution** — Action dispatch
    6. **Monitoring** — Deviation scoring + rerun trigger

    Returns the output of every agent plus pipeline metadata.
    """
    logger.info("POST /run — shipment_id=%s", request.shipment_id)

    # Convert Pydantic model to plain dict for the orchestrator
    input_data = request.model_dump()

    # Flatten nested context so agents find top-level keys easily
    ctx = input_data.pop("context", {})
    weather = ctx.pop("weather", {})
    input_data["context"] = {
        **ctx,
        "weather": weather,
        "weather_risk": ctx.get("weather_risk", weather.get("severity", 0.3)),
    }

    try:
        result = run_pipeline(input_data)
    except Exception as e:
        logger.error("Pipeline execution failed: %s", e, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Pipeline failed: {e}")

    if "error" in result:
        raise HTTPException(status_code=500, detail=result["error"])

    return result


# ── Dev Server ────────────────────────────────────────────────

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
