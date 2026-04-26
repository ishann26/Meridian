"""
Optimization Agent — Public Interface

Exposes: optimize(input_data) -> OptimizationResult
"""

import logging
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

logger = logging.getLogger(__name__)

# ── Types ────────────────────────────────────────────────────

class OptimizationResult:
    def __init__(self, optimized_solution: Dict[str, Any]):
        self.optimizedSolution = optimized_solution

    def to_dict(self) -> Dict[str, Any]:
        return {"optimizedSolution": self.optimizedSolution}


# ── Helpers ──────────────────────────────────────────────────

def _build_ortools_input(input_data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Convert the canonical pipeline input into the format expected by optimizer.py.

    The optimizer.py requires:
      - origin: {latitude, longitude}
      - stops: [{name, location: {latitude, longitude}, demand_kg, time_window}]
      - vehicle: {capacity_kg, max_driving_minutes}

    We do a best-effort mapping from the pipeline's node-ID-based schema.
    """
    # Default geo: New York area (used when nodes are symbolic IDs like "PORT_A")
    _default_coords: Dict[str, Dict[str, float]] = {
        "A":      {"latitude": 40.7128, "longitude": -74.0060},
        "PORT_A": {"latitude": 10.0, "longitude": 10.0},
        "B":      {"latitude": 40.7306, "longitude": -73.9352},
        "PORT_B": {"latitude": 20.0, "longitude": 20.0},
        "C":      {"latitude": 40.6782, "longitude": -73.9442},
        "PORT_C": {"latitude": 25.0, "longitude": 25.0},
        "D":      {"latitude": 40.7282, "longitude": -73.7949},
        "PORT_D": {"latitude": 30.0, "longitude": 30.0},
    }

    def _geo(node_id: str) -> Dict[str, float]:
        uid = str(node_id).upper()
        return _default_coords.get(uid, {"latitude": 0.0, "longitude": 0.0})

    origin_key = str(input_data.get("origin", "A"))
    destination_key = str(input_data.get("destination", "D"))
    raw_stops = input_data.get("stops", [])

    # If routeOptions are present, use the optimal route's nodes as stops
    route_options = input_data.get("routeOptions", [])
    if route_options:
        optimal = route_options[0]
        nodes: List[str] = optimal.get("nodes", [])
        # Exclude origin and destination from intermediate stops
        raw_stops = [n for n in nodes if n not in (origin_key.upper(), destination_key.upper())]

    stops = []
    for i, stop in enumerate(raw_stops):
        if isinstance(stop, dict):
            loc = stop.get("location", _geo(stop.get("name", "A")))
            stops.append({
                "name": stop.get("name", f"Stop-{i+1}"),
                "location": loc,
                "demand_kg": stop.get("demand_kg", 100),
                "time_window": stop.get("time_window", [0, 480]),
            })
        else:
            # stop is a node ID string
            stops.append({
                "name": str(stop),
                "location": _geo(str(stop)),
                "demand_kg": 100,
                "time_window": [0, 480],
            })

    vehicle = input_data.get("vehicle", {})

    # Auto-scale max_driving_minutes: OR-Tools needs the window to be >= the
    # actual travel time. Compute a rough estimate (haversine at 60 km/h) and
    # add a 20% buffer, then use whichever is larger.
    import math

    def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        R = 6371.0
        dlat, dlon = math.radians(lat2 - lat1), math.radians(lon2 - lon1)
        a = math.sin(dlat / 2) ** 2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2) ** 2
        return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

    origin_geo = _geo(origin_key)
    total_km = 0.0
    prev = origin_geo
    for s in stops:
        loc = s["location"]
        total_km += _haversine_km(prev["latitude"], prev["longitude"], loc["latitude"], loc["longitude"])
        prev = loc
    dest_geo = _geo(destination_key)
    total_km += _haversine_km(prev["latitude"], prev["longitude"], dest_geo["latitude"], dest_geo["longitude"])

    min_required_minutes = int(total_km / 60.0 * 60 * 1.2) + 60  # km/h=60, +20% buffer, +60 min slack
    configured_minutes = vehicle.get("max_driving_minutes", 480)
    effective_minutes = max(configured_minutes, min_required_minutes)

    # Widen every stop's time_window to match effective_minutes
    for s in stops:
        tw = s["time_window"]
        s["time_window"] = [tw[0], max(tw[1], effective_minutes)]

    return {
        "origin": _geo(origin_key),
        "stops": stops,
        "vehicle": {
            "capacity_kg": vehicle.get("capacity_kg", 2000),
            "max_driving_minutes": effective_minutes,
        },
    }


# ── Public Interface ─────────────────────────────────────────

def optimize(input_data: Dict[str, Any]) -> OptimizationResult:
    """
    Runs OR-Tools CVRP optimization on the shipment route.

    Args:
        input_data: Merged pipeline context. Uses 'routeOptions' from the routing
                    agent if present to seed the stop list.

    Returns:
        OptimizationResult with optimizedSolution (route, total_distance, total_time).
    """
    logger.info("[optimization_agent] Optimizing route for shipment=%s", input_data.get("shipment_id"))

    _agent_dir = str(Path(__file__).resolve().parent)
    if _agent_dir not in sys.path:
        sys.path.insert(0, _agent_dir)

    try:
        from optimizer import optimize_route

        ortools_input = _build_ortools_input(input_data)
        result = optimize_route(ortools_input)

        if "error" in result:
            raise RuntimeError(result["error"])

        solution = {
            "route": result.get("route", []),
            "totalDistance": result.get("total_distance", 0.0),
            "totalTime": result.get("total_time", 0),
            "improvementPercentage": result.get("improvement_percentage", 0.0),
        }

        logger.info(
            "[optimization_agent] distance=%.1fkm time=%dmin route=%s",
            solution["totalDistance"], solution["totalTime"], solution["route"],
        )

        return OptimizationResult(optimized_solution=solution)

    except Exception as e:
        logger.error("[optimization_agent] OR-Tools optimization failed: %s. Using passthrough.", e)

        # Fallback: return the route from routing agent as-is
        route_options = input_data.get("routeOptions", [])
        fallback_route = route_options[0].get("nodes", []) if route_options else [
            input_data.get("origin", "A"), input_data.get("destination", "D")
        ]

        return OptimizationResult(optimized_solution={
            "route": fallback_route,
            "totalDistance": None,
            "totalTime": None,
            "improvementPercentage": 0.0,
            "source": f"fallback: {e}",
        })
