"""
Meridian Monitoring Agent — Test Suite
=======================================
Tests all layers:
  1. Config loading from .env
  2. Real API calls (Weather, Flight, Ship Tracking)
  3. Deviation computation (deterministic logic)
  4. Full engine pipeline (with mocked GCP services)
  5. Disruption event output format

Run from agents/ directory:
  python test_agent.py
"""

import asyncio
import sys
import os
import json
import traceback
from datetime import datetime, timedelta
from pathlib import Path
from unittest.mock import MagicMock, patch

# Force UTF-8 output on Windows
if sys.platform == "win32":
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

# ── Setup path so imports work ─────────────────────────────
sys.path.insert(0, str(Path(__file__).parent.parent))

PASS = "✅ PASS"
FAIL = "❌ FAIL"
SKIP = "⏭️  SKIP"
INFO = "ℹ️  INFO"


def header(title: str):
    print(f"\n{'═' * 60}")
    print(f"  {title}")
    print(f"{'═' * 60}")


def result(label: str, ok: bool, detail: str = ""):
    icon = PASS if ok else FAIL
    msg = f"  {icon}  {label}"
    if detail:
        msg += f"\n         {detail}"
    print(msg)
    return ok


results = []


# ════════════════════════════════════════════════════════════
#  SECTION 1 — Config Loading
# ════════════════════════════════════════════════════════════

def test_config():
    header("SECTION 1 — Configuration Loading")
    from agents.config import settings

    checks = [
        ("Weather API key loaded",    bool(settings.weather_api.api_key and not settings.weather_api.api_key.startswith("your-"))),
        ("Flight API key loaded",     bool(settings.flight_api.api_key and not settings.flight_api.api_key.startswith("your-"))),
        ("Ship tracking key loaded",  bool(settings.ship_tracking_api.api_key and not settings.ship_tracking_api.api_key.startswith("your-"))),
        ("Weights sum to 1.0",        abs(settings.weights.w_time + settings.weights.w_route + settings.weights.w_risk - 1.0) < 0.01),
        ("Disruption threshold set",  settings.thresholds.disruption_threshold > 0),
        ("Route tolerance set",       settings.thresholds.route_tolerance_km > 0),
        ("Time tolerance set",        settings.thresholds.time_tolerance_minutes > 0),
    ]

    print(f"\n  Weights: time={settings.weights.w_time} route={settings.weights.w_route} risk={settings.weights.w_risk}")
    print(f"  Disruption threshold: {settings.thresholds.disruption_threshold}")
    print(f"  Weather base URL: {settings.weather_api.base_url}")
    print(f"  Flight base URL:  {settings.flight_api.base_url}")
    print(f"  Ship base URL:    {settings.ship_tracking_api.base_url}")

    all_ok = True
    for label, ok in checks:
        r = result(label, ok)
        all_ok = all_ok and r
    results.append(("Config Loading", all_ok))


# ════════════════════════════════════════════════════════════
#  SECTION 2 — Model Validation
# ════════════════════════════════════════════════════════════

def test_models():
    header("SECTION 2 — Data Models")
    from agents.models import (
        GeoPoint, SeverityLevel, DisruptionEvent, DisruptionReason,
        TimeDeviation, RouteDeviation, RiskPrediction, TriggerSource
    )

    all_ok = True

    # GeoPoint
    try:
        p = GeoPoint(lat=28.6139, lng=77.2090)
        d = p.to_dict()
        p2 = GeoPoint.from_dict(d)
        r = result("GeoPoint creation & serialization", p == p2, f"lat={p.lat}, lng={p.lng}")
        all_ok = all_ok and r
    except Exception as e:
        result("GeoPoint creation & serialization", False, str(e))
        all_ok = False

    # SeverityLevel.from_score
    severity_cases = [
        (10,  "NORMAL"),
        (30,  "LOW"),
        (55,  "MODERATE"),
        (75,  "HIGH"),
        (90,  "CRITICAL"),
    ]
    for score, expected in severity_cases:
        sv = SeverityLevel.from_score(score)
        r = result(f"SeverityLevel.from_score({score}) == {expected}", sv.value == expected)
        all_ok = all_ok and r

    # Deviation normalized scores
    td = TimeDeviation(delay_minutes=60.0, percentage_of_total=25.0, exceeds_tolerance=True)
    r = result("TimeDeviation.normalized_score (60 min → 30 pts)", td.normalized_score == 30.0,
               f"got {td.normalized_score}")
    all_ok = all_ok and r

    rd = RouteDeviation(distance_from_route_km=10.0, is_within_tolerance=False)
    r = result("RouteDeviation.normalized_score (10 km → 30 pts)", rd.normalized_score == 30.0,
               f"got {rd.normalized_score}")
    all_ok = all_ok and r

    rp = RiskPrediction(predicted_delay_probability=0.8)
    r = result("RiskPrediction.normalized_score (0.8 → 80 pts)", rp.normalized_score == 80.0,
               f"got {rp.normalized_score}")
    all_ok = all_ok and r

    # DisruptionEvent serialization
    event = DisruptionEvent(
        shipment_id="TEST-001",
        reason=DisruptionReason.HIGH_DELAY_RISK,
        severity=SeverityLevel.HIGH,
        deviation_score=73.5,
        trigger_source=TriggerSource.SCHEDULED_SCAN,
        current_state={"location": {"lat": 28.6, "lng": 77.2}, "status": "IN_TRANSIT"},
        predictions={"delay_probability": 0.75},
        metadata={"weather_risk": 25.0},
    )
    d = event.to_dict()
    expected_keys = {"event_id", "type", "shipment_id", "reason", "severity",
                     "deviation_score", "trigger_source", "current_state",
                     "predictions", "metadata", "timestamp"}
    r = result("DisruptionEvent.to_dict() has all keys", expected_keys == set(d.keys()),
               f"Got: {set(d.keys())}")
    all_ok = all_ok and r
    r = result("DisruptionEvent type == DISRUPTION", d["type"] == "DISRUPTION")
    all_ok = all_ok and r
    print(f"\n  Sample DisruptionEvent:\n{json.dumps(d, indent=4)}")

    results.append(("Data Models", all_ok))


# ════════════════════════════════════════════════════════════
#  SECTION 3 — Deviation Scoring Engine (no GCP needed)
# ════════════════════════════════════════════════════════════

def test_deviation_scoring():
    header("SECTION 3 — Deviation Scoring Engine")
    from agents.models import (
        GeoPoint, PlannedState, LiveState, ShipmentStatus,
        TimeDeviation, RouteDeviation, RiskPrediction,
        ContextData, TriggerSource,
    )
    from agents.engine import MonitoringEngine

    all_ok = True

    now = datetime.utcnow()
    planned = PlannedState(
        shipment_id="TEST-S001",
        planned_departure_time=now - timedelta(hours=3),
        planned_arrival_time=now + timedelta(hours=2),
        planned_route=[
            GeoPoint(lat=28.6139, lng=77.2090),
            GeoPoint(lat=28.7041, lng=77.1025),
            GeoPoint(lat=28.9000, lng=77.0000),
        ],
        carrier="TEST_CARRIER",
    )

    live_ontrack = LiveState(
        shipment_id="TEST-S001",
        current_location=GeoPoint(lat=28.7041, lng=77.1025),  # exactly on route
        current_time=now,
        status=ShipmentStatus.IN_TRANSIT,
        speed_kmh=80.0,
    )

    live_deviated = LiveState(
        shipment_id="TEST-S001",
        current_location=GeoPoint(lat=29.5000, lng=78.5000),  # far off route
        current_time=now,
        status=ShipmentStatus.IN_TRANSIT,
        speed_kmh=0.0,
    )

    engine = MonitoringEngine.__new__(MonitoringEngine)

    # Time deviation
    td_on = engine._compute_time_deviation(planned, live_ontrack)
    result("Time deviation (on-track shipment)", td_on.delay_minutes >= 0,
           f"delay={td_on.delay_minutes:.1f} min, pct={td_on.percentage_of_total:.1f}%")

    td_late = engine._compute_time_deviation(
        PlannedState(
            shipment_id="S002",
            planned_departure_time=now - timedelta(hours=5),
            planned_arrival_time=now - timedelta(hours=1),   # already passed arrival
            planned_route=[GeoPoint(28.6, 77.2), GeoPoint(28.9, 77.0)],
        ),
        LiveState(
            shipment_id="S002",
            current_location=GeoPoint(28.7, 77.1),
            current_time=now,
            status=ShipmentStatus.IN_TRANSIT,
        )
    )
    r = result("Time deviation (overdue shipment → delay > 0)", td_late.delay_minutes > 0,
               f"delay={td_late.delay_minutes:.1f} min")
    all_ok = all_ok and r

    # Route deviation
    rd_on = engine._compute_route_deviation(planned, live_ontrack)
    r = result("Route deviation (on-route → within tolerance)", rd_on.is_within_tolerance,
               f"distance={rd_on.distance_from_route_km:.2f} km")
    all_ok = all_ok and r

    rd_off = engine._compute_route_deviation(planned, live_deviated)
    r = result("Route deviation (off-route → outside tolerance)", not rd_off.is_within_tolerance,
               f"distance={rd_off.distance_from_route_km:.2f} km")
    all_ok = all_ok and r

    # Weighted deviation score
    td = TimeDeviation(delay_minutes=60.0, percentage_of_total=25.0, exceeds_tolerance=True)
    rd = RouteDeviation(distance_from_route_km=20.0, is_within_tolerance=False)
    rp = RiskPrediction(predicted_delay_probability=0.7)
    score = engine._compute_deviation_score(td, rd, rp)
    r = result("Weighted deviation score computed", 0 <= score <= 100, f"score={score:.2f}")
    all_ok = all_ok and r

    # High-severity scenario → should exceed threshold (65)
    td_high = TimeDeviation(delay_minutes=200.0, percentage_of_total=80.0, exceeds_tolerance=True)
    rd_high = RouteDeviation(distance_from_route_km=50.0, is_within_tolerance=False)
    rp_high = RiskPrediction(predicted_delay_probability=0.95)
    score_high = engine._compute_deviation_score(td_high, rd_high, rp_high)
    r = result("High-severity scenario exceeds disruption threshold (65)",
               score_high > 65.0, f"score={score_high:.2f}")
    all_ok = all_ok and r

    # Low-severity scenario → should be below threshold
    td_low = TimeDeviation(delay_minutes=5.0, percentage_of_total=2.0, exceeds_tolerance=False)
    rd_low = RouteDeviation(distance_from_route_km=1.0, is_within_tolerance=True)
    rp_low = RiskPrediction(predicted_delay_probability=0.05)
    score_low = engine._compute_deviation_score(td_low, rd_low, rp_low)
    r = result("Low-severity scenario below threshold (65)",
               score_low < 65.0, f"score={score_low:.2f}")
    all_ok = all_ok and r

    # Haversine
    p1, p2 = GeoPoint(28.6139, 77.2090), GeoPoint(28.7041, 77.1025)
    dist = engine._haversine_km(p1, p2)
    r = result("Haversine distance realistic (10–20 km for Delhi area)",
               10 < dist < 20, f"dist={dist:.2f} km")
    all_ok = all_ok and r

    results.append(("Deviation Scoring", all_ok))


# ════════════════════════════════════════════════════════════
#  SECTION 4 — Real API Calls
# ════════════════════════════════════════════════════════════

async def test_weather_api():
    header("SECTION 4a — Weather API (OpenWeatherMap)")
    from agents.services.context_service import ContextService
    from agents.models import GeoPoint

    svc = ContextService()
    # Delhi coordinates
    location = GeoPoint(lat=28.6139, lng=77.2090)
    all_ok = True
    try:
        data = await svc._fetch_weather(location)
        r = result("Weather API responds", "risk_score" in data,
                   f"risk={data.get('risk_score'):.1f}, temp={data.get('temperature_c')}°C, "
                   f"wind={data.get('wind_speed_kmh'):.1f}km/h, vis={data.get('visibility_km')}km")
        all_ok = all_ok and r
        r = result("Risk score in valid range [0-100]",
                   0 <= data.get("risk_score", -1) <= 100)
        all_ok = all_ok and r
    except Exception as e:
        result("Weather API call", False, str(e))
        all_ok = False
    finally:
        await svc.close()

    results.append(("Weather API", all_ok))
    return all_ok


async def test_flight_api():
    header("SECTION 4b — Flight API (AviationStack)")
    from agents.services.context_service import ContextService
    all_ok = True
    svc = ContextService()
    # Test with a common flight code
    test_flight = "AI101"  # Air India Delhi-Mumbai
    try:
        delay = await svc._fetch_flight_delay(test_flight)
        r = result(f"Flight API responds for {test_flight}",
                   delay >= 0, f"delay={delay} min")
        all_ok = all_ok and r
        print(f"  {INFO}  Delay returned: {delay} min (0 = on-time or not found)")
    except Exception as e:
        result(f"Flight API call for {test_flight}", False, str(e))
        all_ok = False
    finally:
        await svc.close()

    results.append(("Flight API", all_ok))
    return all_ok


async def test_ship_api():
    header("SECTION 4c — Ship Tracking API (MarineTraffic)")
    from agents.services.context_service import ContextService
    all_ok = True
    svc = ContextService()
    # Evergreen Marine's "Ever Given" — famous vessel, likely to have data
    test_imo = "9811000"
    try:
        data = await svc._fetch_ship_position(test_imo)
        if data:
            r = result(f"Ship API responds for IMO {test_imo}",
                       "speed" in data,
                       f"vessel={data.get('vessel_name','?')}, speed={data.get('speed',0):.1f}kn, "
                       f"status={data.get('status','?')}, heading={data.get('heading',0):.0f}°")
            all_ok = all_ok and r
        else:
            print(f"  {INFO}  No vessel data returned — API key may need a paid plan or IMO not found")
            print(f"  {SKIP}  Ship tracking (empty response — not a failure)")
    except Exception as e:
        result(f"Ship API call for IMO {test_imo}", False, str(e))
        all_ok = False
    finally:
        await svc.close()

    results.append(("Ship Tracking API", all_ok))
    return all_ok


# ════════════════════════════════════════════════════════════
#  SECTION 5 — Full Engine Pipeline (mocked GCP)
# ════════════════════════════════════════════════════════════

async def test_full_pipeline():
    header("SECTION 5 — Full Engine Pipeline (GCP mocked)")
    from agents.models import (
        GeoPoint, PlannedState, LiveState, ShipmentStatus,
        SeverityLevel, TriggerSource, ContextData
    )
    from agents.engine import MonitoringEngine

    now = datetime.utcnow()
    all_ok = True

    # ── Mock data ───────────────────────────────────────────
    mock_planned = PlannedState(
        shipment_id="MOCK-S001",
        planned_departure_time=now - timedelta(hours=6),
        planned_arrival_time=now - timedelta(hours=1),   # overdue
        planned_route=[
            GeoPoint(lat=19.0760, lng=72.8777),  # Mumbai
            GeoPoint(lat=20.2961, lng=85.8245),  # Bhubaneswar
            GeoPoint(lat=22.5726, lng=88.3639),  # Kolkata
        ],
        carrier="MOCK_SHIPPING_CO",
        ship_imo="9811000",
    )

    mock_live = LiveState(
        shipment_id="MOCK-S001",
        current_location=GeoPoint(lat=21.0000, lng=86.0000),  # slightly off route
        current_time=now,
        status=ShipmentStatus.IN_TRANSIT,
        speed_kmh=30.0,
        heading=90.0,
        last_updated=now,
    )

    mock_context = ContextData(
        weather_risk_score=45.0,
        flight_delay_minutes=0.0,
        visibility_km=3.0,
        wind_speed_kmh=55.0,
        temperature_c=32.0,
        ship_speed_knots=12.0,
        ship_status="Underway using Engine",
        ship_heading=90.0,
        ship_vessel_name="MOCK VESSEL",
        ship_mmsi="123456789",
    )

    # ── Patch GCP services ──────────────────────────────────
    engine = MonitoringEngine.__new__(MonitoringEngine)

    mock_bq = MagicMock()
    mock_bq.get_planned_state.return_value = mock_planned

    mock_fs = MagicMock()
    mock_fs.get_live_state.return_value = mock_live
    mock_fs.store_disruption_event.return_value = "mock-event-id"
    mock_fs.update_shipment_status.return_value = None

    mock_pubsub = MagicMock()
    mock_pubsub.publish_disruption_event.return_value = "mock-msg-id"

    mock_context_svc = MagicMock()
    mock_context_svc.get_context = asyncio.coroutine(lambda **kw: mock_context) \
        if sys.version_info < (3, 11) else None

    async def _mock_get_context(**kwargs):
        return mock_context

    mock_context_svc.get_context = _mock_get_context

    mock_risk_svc = MagicMock()
    async def _mock_predict(**kwargs):
        from agents.models import RiskPrediction
        return RiskPrediction(
            predicted_delay_probability=0.82,
            predicted_delay_minutes=75.0,
            confidence=0.85,
            model_version="mock-v1",
        )
    mock_risk_svc.predict = _mock_predict

    engine.bq = mock_bq
    engine.firestore = mock_fs
    engine.pubsub = mock_pubsub
    engine.context_svc = mock_context_svc
    engine.risk_svc = mock_risk_svc

    # ── Run pipeline ────────────────────────────────────────
    try:
        event = await engine.evaluate_shipment("MOCK-S001", TriggerSource.MANUAL)

        r = result("Engine pipeline completes without error", True)
        all_ok = all_ok and r

        r = result("Disruption event emitted (overdue + off-route + high risk)",
                   event is not None, "Expected disruption for overdue + off-route shipment")
        all_ok = all_ok and r

        if event:
            r = result("Event has correct shipment_id",
                       event.shipment_id == "MOCK-S001")
            all_ok = all_ok and r

            r = result("Severity is HIGH or CRITICAL",
                       event.severity in (SeverityLevel.HIGH, SeverityLevel.CRITICAL),
                       f"Got: {event.severity.value}")
            all_ok = all_ok and r

            r = result("Event type == DISRUPTION", event.type == "DISRUPTION")
            all_ok = all_ok and r

            r = result("Pub/Sub publish was called", mock_pubsub.publish_disruption_event.called)
            all_ok = all_ok and r

            r = result("Firestore store was called", mock_fs.store_disruption_event.called)
            all_ok = all_ok and r

            d = event.to_dict()
            print(f"\n  📦 Disruption Event Output:")
            print(json.dumps(d, indent=4, default=str))

    except Exception as e:
        result("Engine pipeline", False, f"{type(e).__name__}: {e}")
        traceback.print_exc()
        all_ok = False

    results.append(("Full Engine Pipeline", all_ok))


# ════════════════════════════════════════════════════════════
#  SECTION 6 — Risk Prediction (heuristic fallback)
# ════════════════════════════════════════════════════════════

async def test_risk_prediction():
    header("SECTION 6 — Risk Prediction (heuristic fallback)")
    from agents.services.risk_service import RiskPredictionService
    from agents.models import ContextData

    svc = RiskPredictionService()
    all_ok = True

    context_bad = ContextData(weather_risk_score=70.0, flight_delay_minutes=90.0)
    context_good = ContextData(weather_risk_score=5.0, flight_delay_minutes=0.0)

    pred_bad = svc._predict_heuristic(context_bad, delay=120.0, route_dev=30.0)
    pred_good = svc._predict_heuristic(context_good, delay=5.0, route_dev=1.0)

    r = result("High-risk heuristic probability > 0.5",
               pred_bad.predicted_delay_probability > 0.5,
               f"prob={pred_bad.predicted_delay_probability:.3f}")
    all_ok = all_ok and r

    r = result("Low-risk heuristic probability < 0.3",
               pred_good.predicted_delay_probability < 0.3,
               f"prob={pred_good.predicted_delay_probability:.3f}")
    all_ok = all_ok and r

    r = result("Model version is heuristic-v1",
               pred_bad.model_version == "heuristic-v1")
    all_ok = all_ok and r

    results.append(("Risk Prediction", all_ok))


# ════════════════════════════════════════════════════════════
#  MAIN RUNNER
# ════════════════════════════════════════════════════════════

async def run_all():
    print("\n" + "=" * 60)
    print("  MERIDIAN MONITORING AGENT — TEST SUITE")
    print("=" * 60)

    # Sync tests
    test_config()
    test_models()
    test_deviation_scoring()
    await test_risk_prediction()

    # Async API tests
    await test_weather_api()
    await test_flight_api()
    await test_ship_api()

    # Full pipeline
    await test_full_pipeline()

    # ── Summary ─────────────────────────────────────────────
    header("SUMMARY")
    total_pass = sum(1 for _, ok in results if ok)
    total = len(results)

    for section, ok in results:
        icon = "✅" if ok else "❌"
        print(f"  {icon}  {section}")

    print(f"\n  {'─' * 40}")
    print(f"  Result: {total_pass}/{total} sections passed")
    if total_pass == total:
        print("  🎉  All tests passed!")
    else:
        print(f"  ⚠️   {total - total_pass} section(s) need attention")
    print()


if __name__ == "__main__":
    asyncio.run(run_all())
