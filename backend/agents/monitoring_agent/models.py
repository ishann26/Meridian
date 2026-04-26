"""
Meridian Monitoring Agent — Data Models

All domain models used across the monitoring pipeline.
Pure data structures — no business logic here.
"""

from __future__ import annotations

import uuid
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Any, Dict, List, Optional


# ════════════════════════════════════════════════════════════
#  Core Value Objects
# ════════════════════════════════════════════════════════════

@dataclass(frozen=True)
class GeoPoint:
    """Geographic coordinate (WGS-84)."""
    lat: float
    lng: float

    def to_dict(self) -> Dict[str, float]:
        return {"lat": self.lat, "lng": self.lng}

    @classmethod
    def from_dict(cls, data: Dict[str, float]) -> "GeoPoint":
        return cls(lat=float(data["lat"]), lng=float(data["lng"]))


# ════════════════════════════════════════════════════════════
#  Enums
# ════════════════════════════════════════════════════════════

class ShipmentStatus(str, Enum):
    PENDING = "PENDING"
    IN_TRANSIT = "IN_TRANSIT"
    DELAYED = "DELAYED"
    DEVIATED = "DEVIATED"
    AT_REST = "AT_REST"
    COMPLETED = "COMPLETED"
    CANCELLED = "CANCELLED"


class SeverityLevel(str, Enum):
    NORMAL = "NORMAL"
    LOW = "LOW"
    MODERATE = "MODERATE"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"

    @classmethod
    def from_score(cls, score: float) -> "SeverityLevel":
        """Map a 0-100 deviation score to a severity level."""
        if score < 25:
            return cls.NORMAL
        elif score < 45:
            return cls.LOW
        elif score < 65:
            return cls.MODERATE
        elif score < 85:
            return cls.HIGH
        else:
            return cls.CRITICAL


class DisruptionReason(str, Enum):
    HIGH_DELAY_RISK = "HIGH_DELAY_RISK"
    ROUTE_DEVIATION = "ROUTE_DEVIATION"
    WEATHER_HAZARD = "WEATHER_HAZARD"
    CONGESTION = "CONGESTION"
    FLIGHT_DELAY = "FLIGHT_DELAY"
    FLIGHT_CANCELLED = "FLIGHT_CANCELLED"
    COMBINED_RISK = "COMBINED_RISK"
    UNKNOWN = "UNKNOWN"


class TriggerSource(str, Enum):
    PUBSUB_SHIPMENT = "PUBSUB_SHIPMENT"
    PUBSUB_FLIGHT = "PUBSUB_FLIGHT"
    PUBSUB_WEATHER = "PUBSUB_WEATHER"
    SCHEDULED_SCAN = "SCHEDULED_SCAN"
    FIRESTORE_STATE_CHANGE = "FIRESTORE_STATE_CHANGE"
    MANUAL = "MANUAL"


# ════════════════════════════════════════════════════════════
#  Step 1 — Fetch States
# ════════════════════════════════════════════════════════════

@dataclass
class PlannedState:
    """From BigQuery — the planned / expected state of a shipment."""
    shipment_id: str
    planned_departure_time: datetime
    planned_arrival_time: datetime
    planned_route: List[GeoPoint]
    carrier: Optional[str] = None
    flight_number: Optional[str] = None
    ship_imo: Optional[str] = None           # IMO number for vessel tracking
    origin: Optional[GeoPoint] = None
    destination: Optional[GeoPoint] = None

    @property
    def planned_duration_minutes(self) -> float:
        delta = self.planned_arrival_time - self.planned_departure_time
        return delta.total_seconds() / 60.0


@dataclass
class LiveState:
    """From Firestore — the real-time state of a shipment."""
    shipment_id: str
    current_location: GeoPoint
    current_time: datetime
    status: ShipmentStatus
    speed_kmh: Optional[float] = None
    heading: Optional[float] = None          # degrees 0-360
    last_updated: Optional[datetime] = None

    def to_dict(self) -> Dict[str, Any]:
        return {
            "shipment_id": self.shipment_id,
            "current_location": self.current_location.to_dict(),
            "current_time": self.current_time.isoformat(),
            "status": self.status.value,
            "speed_kmh": self.speed_kmh,
            "heading": self.heading,
            "last_updated": self.last_updated.isoformat() if self.last_updated else None,
        }


@dataclass
class ContextData:
    """From external APIs — environmental context."""
    weather_risk_score: float = 0.0     # 0-100 (OpenWeatherMap)
    flight_delay_minutes: float = 0.0   # AviationStack
    visibility_km: Optional[float] = None
    wind_speed_kmh: Optional[float] = None
    temperature_c: Optional[float] = None
    # Live ship tracking fields (MarineTraffic)
    ship_speed_knots: Optional[float] = None
    ship_status: Optional[str] = None
    ship_heading: Optional[float] = None
    ship_vessel_name: Optional[str] = None
    ship_mmsi: Optional[str] = None


# ════════════════════════════════════════════════════════════
#  Step 2 — Deviation Signals
# ════════════════════════════════════════════════════════════

@dataclass
class TimeDeviation:
    """How far off-schedule the shipment is."""
    delay_minutes: float                    # positive = late, negative = early
    percentage_of_total: float              # delay as % of planned journey time
    exceeds_tolerance: bool = False         # True if beyond acceptable threshold

    @property
    def normalized_score(self) -> float:
        """Normalize to 0-100 scale. Caps at 100."""
        # Every 10 minutes of delay = ~5 points, max 100
        return min(100.0, max(0.0, abs(self.delay_minutes) * 0.5))


@dataclass
class RouteDeviation:
    """How far off the planned route the shipment is."""
    distance_from_route_km: float
    nearest_waypoint_index: int = 0
    is_within_tolerance: bool = True

    @property
    def normalized_score(self) -> float:
        """Normalize to 0-100 scale. Caps at 100."""
        # Every 1 km off-route = ~3 points, max 100
        return min(100.0, max(0.0, self.distance_from_route_km * 3.0))


@dataclass
class RiskPrediction:
    """ML-predicted delay risk."""
    predicted_delay_probability: float = 0.0   # 0.0 – 1.0
    predicted_delay_minutes: float = 0.0
    confidence: float = 0.0                    # model confidence 0.0 – 1.0
    model_version: str = "v1.0"

    @property
    def normalized_score(self) -> float:
        """Normalize probability to 0-100 scale."""
        return min(100.0, max(0.0, self.predicted_delay_probability * 100.0))


# ════════════════════════════════════════════════════════════
#  Step 3 & 4 — Combined Score & Result
# ════════════════════════════════════════════════════════════

@dataclass
class MonitoringResult:
    """Complete result of monitoring a single shipment."""
    shipment_id: str
    time_deviation: TimeDeviation
    route_deviation: RouteDeviation
    risk_prediction: RiskPrediction
    deviation_score: float              # weighted combination (0-100)
    severity: SeverityLevel
    is_disruption: bool                 # True if deviation_score > threshold
    trigger_source: TriggerSource = TriggerSource.MANUAL
    evaluated_at: datetime = field(default_factory=datetime.utcnow)


# ════════════════════════════════════════════════════════════
#  Disruption Event (Output)
# ════════════════════════════════════════════════════════════

@dataclass
class DisruptionEvent:
    """
    The structured event emitted when a disruption is detected.
    This is what downstream agents (rerouting, notification) consume.
    """
    event_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    type: str = "DISRUPTION"
    shipment_id: str = ""
    reason: DisruptionReason = DisruptionReason.UNKNOWN
    severity: SeverityLevel = SeverityLevel.NORMAL
    deviation_score: float = 0.0
    trigger_source: TriggerSource = TriggerSource.MANUAL
    current_state: Dict[str, Any] = field(default_factory=dict)
    predictions: Dict[str, Any] = field(default_factory=dict)
    metadata: Dict[str, Any] = field(default_factory=dict)
    timestamp: datetime = field(default_factory=datetime.utcnow)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "event_id": self.event_id,
            "type": self.type,
            "shipment_id": self.shipment_id,
            "reason": self.reason.value,
            "severity": self.severity.value,
            "deviation_score": round(self.deviation_score, 2),
            "trigger_source": self.trigger_source.value,
            "current_state": self.current_state,
            "predictions": self.predictions,
            "metadata": self.metadata,
            "timestamp": self.timestamp.isoformat() + "Z",
        }


# ════════════════════════════════════════════════════════════
#  Monitoring Input (convenience wrapper)
# ════════════════════════════════════════════════════════════

@dataclass
class MonitoringInput:
    """Aggregated input for the monitoring engine."""
    planned: PlannedState
    live: LiveState
    context: ContextData
    trigger_source: TriggerSource = TriggerSource.MANUAL
