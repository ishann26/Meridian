"""Meridian Backend — FastAPI application entry point.

Start with:
    uvicorn app.main:app --reload --port 8000

Interactive docs at http://localhost:8000/docs
"""

from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routes import router

app = FastAPI(
    title="Meridian Prediction Agent",
    description=(
        "XGBoost-powered delay probability prediction for logistics "
        "shipments. Predicts risk, estimates delay hours, and generates "
        "AI recommendations for route optimization."
    ),
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# ── CORS (allow Flutter frontend in dev) ─────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Tighten in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routes ───────────────────────────────────────────────────
app.include_router(router)


@app.get("/", tags=["root"])
async def root():
    """API root — redirect to docs."""
    return {
        "name": "Meridian Prediction Agent",
        "version": "1.0.0",
        "docs": "/docs",
        "health": "/api/v1/health",
    }
