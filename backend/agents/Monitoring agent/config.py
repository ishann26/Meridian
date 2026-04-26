"""
Meridian Monitoring Agent — Centralized Configuration

Loads all settings from environment variables (.env file).
Single source of truth for every configurable parameter.
"""

import os
from dataclasses import dataclass, field
from pathlib import Path
from dotenv import load_dotenv

# Load .env from the agents directory
_ENV_PATH = Path(__file__).parent / ".env"
load_dotenv(dotenv_path=_ENV_PATH)


def _float(key: str, default: float) -> float:
    return float(os.getenv(key, str(default)))


def _int(key: str, default: int) -> int:
    return int(os.getenv(key, str(default)))


def _str(key: str, default: str = "") -> str:
    return os.getenv(key, default)


# ── GCP Core ────────────────────────────────────────────────
@dataclass(frozen=True)
class GCPConfig:
    project_id: str = _str("GCP_PROJECT_ID")
    region: str = _str("GCP_REGION", "us-central1")
    credentials_path: str = _str("GOOGLE_APPLICATION_CREDENTIALS")


# ── BigQuery ────────────────────────────────────────────────
@dataclass(frozen=True)
class BigQueryConfig:
    dataset: str = _str("BIGQUERY_DATASET", "meridian_logistics")
    shipments_table: str = _str("BIGQUERY_SHIPMENTS_TABLE", "planned_shipments")
    routes_table: str = _str("BIGQUERY_ROUTES_TABLE", "planned_routes")

    @property
    def shipments_full_table(self) -> str:
        return f"{GCPConfig().project_id}.{self.dataset}.{self.shipments_table}"

    @property
    def routes_full_table(self) -> str:
        return f"{GCPConfig().project_id}.{self.dataset}.{self.routes_table}"


# ── Firestore ───────────────────────────────────────────────
@dataclass(frozen=True)
class FirestoreConfig:
    shipments_collection: str = _str("FIRESTORE_COLLECTION_SHIPMENTS", "live_shipments")
    events_collection: str = _str("FIRESTORE_COLLECTION_EVENTS", "disruption_events")


# ── Pub/Sub ─────────────────────────────────────────────────
@dataclass(frozen=True)
class PubSubConfig:
    shipment_topic: str = _str("PUBSUB_SHIPMENT_UPDATES_TOPIC", "shipment-updates")
    flight_topic: str = _str("PUBSUB_FLIGHT_STATUS_TOPIC", "flight-status-changes")
    weather_topic: str = _str("PUBSUB_WEATHER_ALERTS_TOPIC", "weather-alerts")
    disruption_topic: str = _str("PUBSUB_DISRUPTION_EVENTS_TOPIC", "disruption-events")
    subscription_shipment: str = _str("PUBSUB_SUBSCRIPTION_SHIPMENT", "shipment-updates-sub")
    subscription_flight: str = _str("PUBSUB_SUBSCRIPTION_FLIGHT", "flight-status-sub")
    subscription_weather: str = _str("PUBSUB_SUBSCRIPTION_WEATHER", "weather-alerts-sub")


# ── Cloud Scheduler ─────────────────────────────────────────
@dataclass(frozen=True)
class SchedulerConfig:
    interval_minutes: int = _int("SCHEDULER_SCAN_INTERVAL_MINUTES", 5)
    job_name: str = _str("SCHEDULER_JOB_NAME", "monitoring-scan-job")
    timezone: str = _str("SCHEDULER_TIMEZONE", "UTC")


# ── External APIs ───────────────────────────────────────────
@dataclass(frozen=True)
class WeatherAPIConfig:
    api_key: str = _str("WEATHER_API_KEY")
    base_url: str = _str("WEATHER_API_BASE_URL", "https://api.openweathermap.org/data/2.5")


@dataclass(frozen=True)
class FlightAPIConfig:
    api_key: str = _str("FLIGHT_API_KEY")
    base_url: str = _str("FLIGHT_API_BASE_URL", "https://api.aviationstack.com/v1")


# ── Ship Tracking API ───────────────────────────────────────
@dataclass(frozen=True)
class ShipTrackingAPIConfig:
    api_key: str = _str("SHIP_TRACKING_API_KEY")
    base_url: str = _str("SHIP_TRACKING_API_BASE_URL", "https://services.marinetraffic.com/api/exportvessel/v:8")


# ── Monitoring Thresholds ───────────────────────────────────
@dataclass(frozen=True)
class MonitoringWeights:
    w_time: float = _float("WEIGHT_TIME_DEVIATION", 0.4)
    w_route: float = _float("WEIGHT_ROUTE_DEVIATION", 0.35)
    w_risk: float = _float("WEIGHT_RISK_SCORE", 0.25)

    def __post_init__(self):
        total = self.w_time + self.w_route + self.w_risk
        if abs(total - 1.0) > 0.01:
            raise ValueError(
                f"Deviation weights must sum to 1.0, got {total:.3f} "
                f"(w_time={self.w_time}, w_route={self.w_route}, w_risk={self.w_risk})"
            )


@dataclass(frozen=True)
class ThresholdConfig:
    disruption_threshold: float = _float("DISRUPTION_THRESHOLD", 65.0)
    route_tolerance_km: float = _float("ROUTE_TOLERANCE_KM", 15.0)
    time_tolerance_minutes: float = _float("TIME_TOLERANCE_MINUTES", 30.0)


# ── ML / Risk Model ────────────────────────────────────────
@dataclass(frozen=True)
class MLConfig:
    model_endpoint: str = _str("ML_MODEL_ENDPOINT")
    model_api_key: str = _str("ML_MODEL_API_KEY")
    model_local_path: str = _str("ML_MODEL_LOCAL_PATH", "models/risk_predictor.pkl")


# ── App Settings ────────────────────────────────────────────
@dataclass(frozen=True)
class AppConfig:
    log_level: str = _str("LOG_LEVEL", "INFO")
    environment: str = _str("ENVIRONMENT", "development")
    port: int = _int("PORT", 8080)
    host: str = _str("HOST", "0.0.0.0")


# ── Aggregate Config Object ────────────────────────────────
@dataclass(frozen=True)
class Settings:
    gcp: GCPConfig = field(default_factory=GCPConfig)
    bigquery: BigQueryConfig = field(default_factory=BigQueryConfig)
    firestore: FirestoreConfig = field(default_factory=FirestoreConfig)
    pubsub: PubSubConfig = field(default_factory=PubSubConfig)
    scheduler: SchedulerConfig = field(default_factory=SchedulerConfig)
    weather_api: WeatherAPIConfig = field(default_factory=WeatherAPIConfig)
    flight_api: FlightAPIConfig = field(default_factory=FlightAPIConfig)
    ship_tracking_api: ShipTrackingAPIConfig = field(default_factory=ShipTrackingAPIConfig)
    weights: MonitoringWeights = field(default_factory=MonitoringWeights)
    thresholds: ThresholdConfig = field(default_factory=ThresholdConfig)
    ml: MLConfig = field(default_factory=MLConfig)
    app: AppConfig = field(default_factory=AppConfig)


# Singleton — import this everywhere
settings = Settings()
