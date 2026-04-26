"""
Monitoring Engine — The "Agent Brain"

Pure deterministic logic. No LLM/Gemini needed.

Pipeline:
  Step 1: Fetch states (planned, live, context)
  Step 2: Compute deviations (time, route, risk)
  Step 3: Combine into weighted deviation score
  Step 4: Evaluate threshold → emit DISRUPTION_EVENT or not
"""

import logging
import math
from datetime import datetime
from typing import List, Optional, Tuple

from .config import settings
from .models import (
    ContextData, DisruptionEvent, DisruptionReason, GeoPoint,
    LiveState, MonitoringInput, MonitoringResult, PlannedState,
    RiskPrediction, RouteDeviation, SeverityLevel, ShipmentStatus,
    TimeDeviation, TriggerSource,
)
from .services.bigquery_service import BigQueryService
from .services.context_service import ContextService
from .services.firestore_service import FirestoreService
from .services.pubsub_service import PubSubService
from .services.risk_service import RiskPredictionService

logger = logging.getLogger(__name__)


class MonitoringEngine:
    """
    The core monitoring brain.
    Orchestrates: fetch → compute → score → decide → emit.
    """

    def __init__(self):
        self.bq = BigQueryService()
        self.firestore = FirestoreService()
        self.pubsub = PubSubService()
        self.context_svc = ContextService()
        self.risk_svc = RiskPredictionService()

    # ════════════════════════════════════════════════════════
    #  Main Entry Point
    # ════════════════════════════════════════════════════════

    async def evaluate_shipment(
        self,
        shipment_id: str,
        trigger: TriggerSource = TriggerSource.MANUAL,
    ) -> Optional[DisruptionEvent]:
        """
        Full monitoring pipeline for a single shipment.
        Returns a DisruptionEvent if threshold is exceeded, else None.
        """
        logger.info("[%s] Evaluating shipment %s", trigger.value, shipment_id)

        # ── Step 1: Fetch States ────────────────────────────
        planned = self.bq.get_planned_state(shipment_id)
        if planned is None:
            logger.warning("No planned state for %s — skipping", shipment_id)
            return None

        live = self.firestore.get_live_state(shipment_id)
        if live is None:
            logger.warning("No live state for %s — skipping", shipment_id)
            return None

        context = await self.context_svc.get_context(
            location=live.current_location,
            flight_number=planned.flight_number,
            ship_imo=planned.ship_imo,
        )

        # ── Step 2: Compute Deviations ──────────────────────
        time_dev = self._compute_time_deviation(planned, live)
        route_dev = self._compute_route_deviation(planned, live)

        risk_pred = await self.risk_svc.predict(
            planned=planned, live=live, context=context,
            time_delay_minutes=time_dev.delay_minutes,
            route_deviation_km=route_dev.distance_from_route_km,
        )

        # ── Step 3: Combine into Score ──────────────────────
        deviation_score = self._compute_deviation_score(time_dev, route_dev, risk_pred)
        severity = SeverityLevel.from_score(deviation_score)
        is_disruption = deviation_score > settings.thresholds.disruption_threshold

        result = MonitoringResult(
            shipment_id=shipment_id,
            time_deviation=time_dev,
            route_deviation=route_dev,
            risk_prediction=risk_pred,
            deviation_score=deviation_score,
            severity=severity,
            is_disruption=is_disruption,
            trigger_source=trigger,
        )

        logger.info(
            "[%s] Shipment %s — score=%.1f severity=%s disruption=%s",
            trigger.value, shipment_id, deviation_score, severity.value, is_disruption,
        )

        # ── Step 4: Emit if Disrupted ───────────────────────
        if is_disruption:
            event = self._build_disruption_event(result, planned, live, context, risk_pred)
            await self._emit_disruption(event)

            # Update shipment status in Firestore
            if severity in (SeverityLevel.HIGH, SeverityLevel.CRITICAL):
                self.firestore.update_shipment_status(shipment_id, ShipmentStatus.DELAYED)

            return event

        return None

    async def evaluate_all_active(
        self,
        trigger: TriggerSource = TriggerSource.SCHEDULED_SCAN,
    ) -> List[DisruptionEvent]:
        """Scan all active shipments — used by scheduled scan trigger."""
        logger.info("Starting full scan of all active shipments")
        shipment_ids = self.bq.get_all_active_shipment_ids()
        events = []

        for sid in shipment_ids:
            try:
                event = await self.evaluate_shipment(sid, trigger=trigger)
                if event:
                    events.append(event)
            except Exception as e:
                logger.error("Failed to evaluate shipment %s: %s", sid, e)

        logger.info("Scan complete: %d/%d shipments flagged", len(events), len(shipment_ids))
        return events

    # ════════════════════════════════════════════════════════
    #  Step 2 — Deviation Computations
    # ════════════════════════════════════════════════════════

    def _compute_time_deviation(self, planned: PlannedState, live: LiveState) -> TimeDeviation:
        """Signal 1: How far off-schedule is the shipment?"""
        now = live.current_time or datetime.utcnow()

        # Calculate expected progress based on elapsed time
        total_planned = planned.planned_duration_minutes
        elapsed = (now - planned.planned_departure_time).total_seconds() / 60.0

        # If shipment hasn't departed yet
        if elapsed < 0:
            return TimeDeviation(delay_minutes=0.0, percentage_of_total=0.0, exceeds_tolerance=False)

        # Expected arrival: planned_arrival_time
        # Current delay estimate
        if now > planned.planned_arrival_time:
            delay = (now - planned.planned_arrival_time).total_seconds() / 60.0
        else:
            # Estimate based on progress vs expected progress
            if total_planned > 0:
                expected_progress = min(1.0, elapsed / total_planned)
                # Use route position to estimate actual progress
                actual_progress = self._estimate_progress(planned, live)
                if actual_progress < expected_progress and expected_progress > 0:
                    delay = (expected_progress - actual_progress) * total_planned
                else:
                    delay = 0.0
            else:
                delay = 0.0

        pct = (delay / total_planned * 100.0) if total_planned > 0 else 0.0
        exceeds = delay > settings.thresholds.time_tolerance_minutes

        return TimeDeviation(delay_minutes=delay, percentage_of_total=pct, exceeds_tolerance=exceeds)

    def _compute_route_deviation(self, planned: PlannedState, live: LiveState) -> RouteDeviation:
        """Signal 2: How far off the planned route is the shipment?"""
        if not planned.planned_route:
            return RouteDeviation(distance_from_route_km=0.0, nearest_waypoint_index=0, is_within_tolerance=True)

        min_dist = float("inf")
        nearest_idx = 0

        for i, waypoint in enumerate(planned.planned_route):
            dist = self._haversine_km(live.current_location, waypoint)
            if dist < min_dist:
                min_dist = dist
                nearest_idx = i

        # Also check distance to line segments between waypoints
        for i in range(len(planned.planned_route) - 1):
            seg_dist = self._point_to_segment_distance(
                live.current_location, planned.planned_route[i], planned.planned_route[i + 1]
            )
            if seg_dist < min_dist:
                min_dist = seg_dist
                nearest_idx = i

        within_tolerance = min_dist <= settings.thresholds.route_tolerance_km

        return RouteDeviation(
            distance_from_route_km=round(min_dist, 2),
            nearest_waypoint_index=nearest_idx,
            is_within_tolerance=within_tolerance,
        )

    # ════════════════════════════════════════════════════════
    #  Step 3 — Weighted Score
    # ════════════════════════════════════════════════════════

    def _compute_deviation_score(
        self, time_dev: TimeDeviation, route_dev: RouteDeviation, risk: RiskPrediction
    ) -> float:
        """
        deviation_score = w1*time_score + w2*route_score + w3*risk_score
        All scores normalized to 0-100 before weighting.
        """
        w = settings.weights
        score = (
            w.w_time * time_dev.normalized_score
            + w.w_route * route_dev.normalized_score
            + w.w_risk * risk.normalized_score
        )
        return round(min(100.0, max(0.0, score)), 2)

    # ════════════════════════════════════════════════════════
    #  Step 4 — Event Construction & Emission
    # ════════════════════════════════════════════════════════

    def _build_disruption_event(
        self, result: MonitoringResult, planned: PlannedState,
        live: LiveState, context: ContextData, risk: RiskPrediction,
    ) -> DisruptionEvent:
        """Build a structured disruption event from monitoring result."""
        reason = self._determine_reason(result, context)

        return DisruptionEvent(
            shipment_id=result.shipment_id,
            reason=reason,
            severity=result.severity,
            deviation_score=result.deviation_score,
            trigger_source=result.trigger_source,
            current_state={
                "location": live.current_location.to_dict(),
                "status": live.status.value,
                "speed_kmh": live.speed_kmh,
                "time": live.current_time.isoformat(),
                "ship": {
                    "vessel_name": context.ship_vessel_name,
                    "speed_knots": context.ship_speed_knots,
                    "heading": context.ship_heading,
                    "status": context.ship_status,
                    "mmsi": context.ship_mmsi,
                } if context.ship_vessel_name or context.ship_status else None,
            },
            predictions={
                "delay_probability": round(risk.predicted_delay_probability, 3),
                "predicted_delay_minutes": round(risk.predicted_delay_minutes, 1),
                "model_version": risk.model_version,
                "confidence": round(risk.confidence, 3),
            },
            metadata={
                "time_delay_minutes": round(result.time_deviation.delay_minutes, 1),
                "route_deviation_km": round(result.route_deviation.distance_from_route_km, 2),
                "weather_risk": round(context.weather_risk_score, 1),
                "flight_delay_minutes": round(context.flight_delay_minutes, 1),
                "planned_arrival": planned.planned_arrival_time.isoformat(),
            },
        )

    @staticmethod
    def _determine_reason(result: MonitoringResult, context: ContextData) -> DisruptionReason:
        """Determine the primary reason for disruption."""
        scores = {
            DisruptionReason.HIGH_DELAY_RISK: result.time_deviation.normalized_score,
            DisruptionReason.ROUTE_DEVIATION: result.route_deviation.normalized_score,
            DisruptionReason.WEATHER_HAZARD: context.weather_risk_score,
        }
        if context.flight_delay_minutes > 30:
            scores[DisruptionReason.FLIGHT_DELAY] = 80.0
        # Flag if ship is stopped/anchored unexpectedly
        if context.ship_status and "anchor" in context.ship_status.lower():
            scores[DisruptionReason.HIGH_DELAY_RISK] = max(
                scores[DisruptionReason.HIGH_DELAY_RISK], 70.0
            )

        top = max(scores, key=scores.get)

        # If multiple signals are high, it's a combined risk
        high_signals = sum(1 for v in scores.values() if v > 50)
        if high_signals >= 3:
            return DisruptionReason.COMBINED_RISK

        return top

    async def _emit_disruption(self, event: DisruptionEvent) -> None:
        """Emit disruption event to Pub/Sub + persist in Firestore."""
        logger.warning(
            "🚨 DISRUPTION DETECTED — shipment=%s reason=%s severity=%s score=%.1f",
            event.shipment_id, event.reason.value, event.severity.value, event.deviation_score,
        )
        # Persist to Firestore (audit trail)
        self.firestore.store_disruption_event(event)
        # Publish to Pub/Sub (downstream consumers)
        self.pubsub.publish_disruption_event(event)

    # ════════════════════════════════════════════════════════
    #  Geo Utilities
    # ════════════════════════════════════════════════════════

    @staticmethod
    def _haversine_km(p1: GeoPoint, p2: GeoPoint) -> float:
        """Haversine distance between two geo points in km."""
        R = 6371.0
        lat1, lat2 = math.radians(p1.lat), math.radians(p2.lat)
        dlat = math.radians(p2.lat - p1.lat)
        dlng = math.radians(p2.lng - p1.lng)
        a = math.sin(dlat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlng / 2) ** 2
        return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

    @staticmethod
    def _estimate_progress(planned: PlannedState, live: LiveState) -> float:
        """Estimate journey progress 0.0-1.0 based on position along route."""
        if not planned.planned_route or len(planned.planned_route) < 2:
            return 0.5
        origin = planned.planned_route[0]
        dest = planned.planned_route[-1]
        total = MonitoringEngine._haversine_km(origin, dest)
        if total == 0:
            return 1.0
        remaining = MonitoringEngine._haversine_km(live.current_location, dest)
        return max(0.0, min(1.0, 1.0 - remaining / total))

    @staticmethod
    def _point_to_segment_distance(p: GeoPoint, a: GeoPoint, b: GeoPoint) -> float:
        """Approximate distance from point p to line segment a-b in km."""
        d_ab = MonitoringEngine._haversine_km(a, b)
        if d_ab < 0.001:
            return MonitoringEngine._haversine_km(p, a)
        d_ap = MonitoringEngine._haversine_km(a, p)
        d_bp = MonitoringEngine._haversine_km(b, p)
        # Use triangle approximation
        s = (d_ab + d_ap + d_bp) / 2
        area_sq = s * (s - d_ab) * (s - d_ap) * (s - d_bp)
        if area_sq <= 0:
            return min(d_ap, d_bp)
        area = math.sqrt(area_sq)
        height = 2 * area / d_ab
        # Check if projection falls within segment
        if d_ap ** 2 > d_bp ** 2 + d_ab ** 2:
            return d_bp
        if d_bp ** 2 > d_ap ** 2 + d_ab ** 2:
            return d_ap
        return height

    # ── Cleanup ─────────────────────────────────────────────

    async def close(self):
        await self.context_svc.close()
        await self.risk_svc.close()
        self.pubsub.close()
