"""
Routing Agent — Free Local Version
===================================
Stack:
  - FastAPI        : web server (receives routing requests via HTTP POST)
  - OSRM           : free routing API (no key needed)
  - SQLite         : local database (stores route results)
  - python-dotenv  : loads secrets from .env file

Run with:
    python main.py

Then send requests to:
    POST http://localhost:8000/route
"""

import json
import logging
import os
import sqlite3
from datetime import datetime, timedelta, timezone
from typing import Optional

import requests
import uvicorn
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

# Load environment variables from .env file
load_dotenv()

# ---------------------------------------------------------------------------
# Logging setup
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger("routing-agent")

# ---------------------------------------------------------------------------
# Config from .env
# ---------------------------------------------------------------------------
OSRM_BASE_URL = os.environ.get("OSRM_BASE_URL", "http://router.project-osrm.org")
DB_PATH       = os.environ.get("DB_PATH", "routes.db")
APP_HOST      = os.environ.get("APP_HOST", "0.0.0.0")
APP_PORT      = int(os.environ.get("APP_PORT", "8000"))

# ---------------------------------------------------------------------------
# FastAPI app
# ---------------------------------------------------------------------------
app = FastAPI(title="Routing Agent", version="1.0.0")

# ---------------------------------------------------------------------------
# Database setup
# ---------------------------------------------------------------------------

def init_db():
    """Create the SQLite database and trips table if they don't exist."""
    conn = sqlite3.connect(DB_PATH)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS trips (
            trip_id         TEXT PRIMARY KEY,
            origin_lat      REAL,
            origin_lng      REAL,
            dest_lat        REAL,
            dest_lng        REAL,
            departure_time  TEXT,
            route_options   TEXT,       -- JSON string
            status          TEXT,
            created_at      TEXT,
            updated_at      TEXT
        )
    """)
    conn.commit()
    conn.close()
    logger.info("Database ready at: %s", DB_PATH)


def save_trip(trip_id: str, payload: dict, route_options: list):
    """Save or update a trip record in SQLite."""
    now = datetime.now(tz=timezone.utc).isoformat()
    conn = sqlite3.connect(DB_PATH)
    conn.execute("""
        INSERT INTO trips
            (trip_id, origin_lat, origin_lng, dest_lat, dest_lng,
             departure_time, route_options, status, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(trip_id) DO UPDATE SET
            route_options = excluded.route_options,
            status        = excluded.status,
            updated_at    = excluded.updated_at
    """, (
        trip_id,
        payload["origin"]["lat"],
        payload["origin"]["lng"],
        payload["destination"]["lat"],
        payload["destination"]["lng"],
        payload.get("departure_time", now),
        json.dumps(route_options),
        "routes_ready",
        now,
        now,
    ))
    conn.commit()
    conn.close()
    logger.info("Saved trip %s to database with %d routes.", trip_id, len(route_options))


def get_trip(trip_id: str) -> Optional[dict]:
    """Fetch a trip record from SQLite by trip_id."""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    row = conn.execute(
        "SELECT * FROM trips WHERE trip_id = ?", (trip_id,)
    ).fetchone()
    conn.close()
    if not row:
        return None
    result = dict(row)
    result["route_options"] = json.loads(result["route_options"])
    return result


# ---------------------------------------------------------------------------
# OSRM routing helper
# ---------------------------------------------------------------------------

def build_osrm_coordinates(origin: dict, destination: dict, waypoints: list) -> str:
    """
    Build the OSRM coordinate string.
    OSRM format: lng,lat;lng,lat;...  (longitude FIRST — same as Mappls)

    Example: "72.8777,19.0760;79.0882,21.1458;77.2090,28.6139"
    """
    points = [origin] + (waypoints or []) + [destination]
    return ";".join(f"{p['lng']},{p['lat']}" for p in points)


def call_osrm(origin: dict, destination: dict, waypoints: list,
              avoid_tolls: bool, avoid_highways: bool) -> dict:
    """
    Call the free OSRM public routing API.

    Endpoint:
        GET http://router.project-osrm.org/route/v1/driving/{coordinates}
            ?alternatives=2
            &geometries=polyline
            &overview=full
            &steps=false

    No API key required.
    Returns raw OSRM JSON response.
    """
    coords = build_osrm_coordinates(origin, destination, waypoints)
    url = f"{OSRM_BASE_URL}/route/v1/driving/{coords}"

    params = {
        "alternatives": "true",      # request alternative routes
        "geometries":   "polyline",  # encoded polyline (Google-compatible)
        "overview":     "full",      # full route geometry
        "steps":        "false",     # no turn-by-turn (not needed for now)
    }

    # Note: OSRM public server does not support toll/highway exclusion filters.
    # We log these preferences for now. When self-hosting Valhalla/ORS later,
    # these can be passed as proper exclusion parameters.
    if avoid_tolls:
        logger.info("avoid_tolls=True noted (not enforced by OSRM public server)")
    if avoid_highways:
        logger.info("avoid_highways=True noted (not enforced by OSRM public server)")

    logger.info("Calling OSRM: %s | coords: %s", url, coords)

    response = requests.get(url, params=params, timeout=30)
    response.raise_for_status()

    data = response.json()

    if data.get("code") != "Ok":
        raise ValueError(f"OSRM error: {data.get('code')} — {data.get('message', 'unknown error')}")

    logger.info("OSRM returned %d route(s).", len(data.get("routes", [])))
    return data


# ---------------------------------------------------------------------------
# Route enrichment
# ---------------------------------------------------------------------------

def meters_to_km(meters: float) -> str:
    """Convert metres to a readable km string. E.g. '342.7 km'"""
    return f"{meters / 1000:.1f} km"


def seconds_to_duration(seconds: float) -> str:
    """Convert seconds to readable string. E.g. '2 hr 15 min'"""
    total_min = int(seconds // 60)
    hours, mins = divmod(total_min, 60)
    if hours > 0:
        return f"{hours} hr {mins} min"
    return f"{mins} min"


def parse_routes(osrm_response: dict, departure_time: str) -> list:
    """
    Convert raw OSRM routes into our canonical routeOptions schema.

    This schema is kept identical to what the GCP version produces,
    so swapping back to GCP/Mappls later requires zero changes downstream.

    Each route:
    {
        "routeIndex":       0,
        "label":            "Optimal Route",
        "distanceMeters":   1423000,
        "distanceText":     "1423.0 km",
        "durationSeconds":  54000,
        "durationText":     "15 hr 0 min",
        "encodedPolyline":  "abc123...",
        "summary":          "Optimal Route: 1423.0 km, 15 hr 0 min",
        "departureTime":    "2026-04-27T08:00:00Z",
        "estimatedArrival": "2026-04-27T23:00:00+00:00",
        "source":           "osrm"
    }
    """
    raw_routes = osrm_response.get("routes", [])
    labels = ["Optimal Route", "Alternative 1", "Alternative 2"]

    try:
        dep_dt = datetime.fromisoformat(departure_time.replace("Z", "+00:00"))
    except (ValueError, AttributeError):
        dep_dt = datetime.now(tz=timezone.utc)

    parsed = []
    for idx, route in enumerate(raw_routes[:3]):
        distance_m  = route.get("distance", 0)
        duration_s  = route.get("duration", 0)
        # OSRM returns geometry under route["geometry"]
        geometry    = route.get("geometry", "")
        label       = labels[idx] if idx < len(labels) else f"Alternative {idx}"
        arrival_dt  = dep_dt + timedelta(seconds=int(duration_s))

        parsed.append({
            "routeIndex":       idx,
            "label":            label,
            "distanceMeters":   int(distance_m),
            "distanceText":     meters_to_km(distance_m),
            "durationSeconds":  int(duration_s),
            "durationText":     seconds_to_duration(duration_s),
            "encodedPolyline":  geometry,
            "summary":          f"{label}: {meters_to_km(distance_m)}, {seconds_to_duration(duration_s)}",
            "departureTime":    departure_time,
            "estimatedArrival": arrival_dt.isoformat(),
            "source":           "osrm",
        })

    return parsed


# ---------------------------------------------------------------------------
# Request / Response models
# ---------------------------------------------------------------------------

class LatLng(BaseModel):
    lat: float
    lng: float

class RouteRequest(BaseModel):
    trip_id:        str
    origin:         LatLng
    destination:    LatLng
    waypoints:      Optional[list[LatLng]] = None
    departure_time: Optional[str]          = None
    avoid_tolls:    Optional[bool]         = False
    avoid_highways: Optional[bool]         = False


# ---------------------------------------------------------------------------
# API endpoints
# ---------------------------------------------------------------------------

@app.on_event("startup")
def on_startup():
    init_db()
    logger.info("Routing Agent started on http://%s:%s", APP_HOST, APP_PORT)


@app.get("/health")
def health():
    """Simple health check — visit this in your browser to confirm it's running."""
    return {"status": "ok", "service": "routing-agent", "version": "1.0.0"}


@app.post("/route")
def compute_route(req: RouteRequest):
    """
    Main endpoint. Receives a trip routing request, calls OSRM,
    saves results to SQLite, and returns the enriched route options.

    Example request body:
    {
        "trip_id": "trip_001",
        "origin":      {"lat": 19.0760, "lng": 72.8777},
        "destination": {"lat": 28.6139, "lng": 77.2090},
        "waypoints":   [{"lat": 21.1458, "lng": 79.0882}],
        "departure_time": "2026-04-27T08:00:00Z",
        "avoid_tolls": false,
        "avoid_highways": false
    }
    """
    logger.info("Received route request for trip_id=%s", req.trip_id)

    departure_time = req.departure_time or datetime.now(tz=timezone.utc).isoformat()

    # Convert pydantic models to plain dicts for our helper functions
    origin      = {"lat": req.origin.lat,      "lng": req.origin.lng}
    destination = {"lat": req.destination.lat, "lng": req.destination.lng}
    waypoints   = [{"lat": w.lat, "lng": w.lng} for w in (req.waypoints or [])]

    # Call OSRM
    try:
        osrm_response = call_osrm(
            origin, destination, waypoints,
            req.avoid_tolls, req.avoid_highways
        )
    except requests.HTTPError as e:
        logger.error("OSRM HTTP error: %s", e)
        raise HTTPException(status_code=502, detail=f"Routing API error: {e}")
    except ValueError as e:
        logger.error("OSRM returned an error: %s", e)
        raise HTTPException(status_code=502, detail=str(e))
    except requests.Timeout:
        logger.error("OSRM request timed out")
        raise HTTPException(status_code=504, detail="Routing API timed out")

    # Parse into canonical schema
    route_options = parse_routes(osrm_response, departure_time)

    if not route_options:
        raise HTTPException(status_code=404, detail="No routes found between given points")

    # Save to SQLite
    payload = {
        "origin":         origin,
        "destination":    destination,
        "departure_time": departure_time,
    }
    save_trip(req.trip_id, payload, route_options)

    # Return response (same structure as GCP version's Pub/Sub message)
    return {
        "trip_id":      req.trip_id,
        "routeOptions": route_options,
        "origin":       origin,
        "destination":  destination,
        "departure_time": departure_time,
        "timestamp":    datetime.now(tz=timezone.utc).isoformat(),
    }


@app.get("/trip/{trip_id}")
def get_trip_routes(trip_id: str):
    """Fetch previously computed routes for a trip from the database."""
    trip = get_trip(trip_id)
    if not trip:
        raise HTTPException(status_code=404, detail=f"Trip '{trip_id}' not found")
    return trip


@app.get("/trips")
def list_trips():
    """List all trips in the database (useful for debugging)."""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    rows = conn.execute(
        "SELECT trip_id, status, created_at, updated_at FROM trips ORDER BY created_at DESC"
    ).fetchall()
    conn.close()
    return {"trips": [dict(r) for r in rows]}


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    uvicorn.run("main:app", host=APP_HOST, port=APP_PORT, reload=True)