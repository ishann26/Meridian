"""Pydantic models for API request/response schemas."""

from __future__ import annotations

from enum import Enum
from pydantic import BaseModel, Field


class TransportMode(str, Enum):
    """Transport mode for a shipment leg."""
    road = "road"
    rail = "rail"
    air = "air"
    sea = "sea"


class WeatherCondition(str, Enum):
    """Simplified weather condition at origin/destination."""
    clear = "clear"
    rain = "rain"
    storm = "storm"
    fog = "fog"


class PredictionRequest(BaseModel):
    """Input features for delay probability prediction.

    Each field maps to an XGBoost feature used during training.
    """
    shipment_id: str = Field(..., description="Unique shipment identifier")
    origin: str = Field(..., description="Origin city/port")
    destination: str = Field(..., description="Destination city/port")
    transport_mode: TransportMode
    distance_km: float = Field(..., gt=0, description="Route distance in km")
    weight_kg: float = Field(..., gt=0, description="Cargo weight in kg")
    cargo_value_usd: float = Field(..., ge=0, description="Declared cargo value")
    port_congestion_index: float = Field(
        ..., ge=0.0, le=1.0,
        description="0.0 = no congestion, 1.0 = fully congested",
    )
    weather_origin: WeatherCondition = WeatherCondition.clear
    weather_destination: WeatherCondition = WeatherCondition.clear
    day_of_week: int = Field(..., ge=0, le=6, description="0=Mon … 6=Sun")
    hour_of_departure: int = Field(..., ge=0, le=23)
    historical_delay_rate: float = Field(
        ..., ge=0.0, le=1.0,
        description="Historical delay rate on this corridor (0–1)",
    )
    is_hazardous: bool = False
    is_perishable: bool = False

    model_config = {"json_schema_extra": {
        "examples": [{
            "shipment_id": "SHP-001",
            "origin": "Mumbai",
            "destination": "Rotterdam",
            "transport_mode": "sea",
            "distance_km": 11200,
            "weight_kg": 24500,
            "cargo_value_usd": 185000,
            "port_congestion_index": 0.65,
            "weather_origin": "clear",
            "weather_destination": "rain",
            "day_of_week": 2,
            "hour_of_departure": 14,
            "historical_delay_rate": 0.22,
            "is_hazardous": False,
            "is_perishable": False,
        }],
    }}


class RiskLevel(str, Enum):
    low = "low"
    medium = "medium"
    high = "high"
    critical = "critical"


class PredictionResponse(BaseModel):
    """Prediction result with delay probability and risk classification."""
    shipment_id: str
    delay_probability: float = Field(
        ..., ge=0.0, le=1.0,
        description="Probability of delay (0–1)",
    )
    risk_level: RiskLevel
    estimated_delay_hours: float = Field(
        ..., ge=0.0,
        description="Expected delay in hours if delay occurs",
    )
    confidence: float = Field(
        ..., ge=0.0, le=1.0,
        description="Model confidence in the prediction",
    )
    top_risk_factors: list[str] = Field(
        default_factory=list,
        description="Top contributing features to delay risk",
    )
    recommendation: str = Field(
        ..., description="AI-generated mitigation suggestion",
    )


class HealthResponse(BaseModel):
    """API health check response."""
    status: str = "healthy"
    model_loaded: bool
    model_version: str
    features_count: int
