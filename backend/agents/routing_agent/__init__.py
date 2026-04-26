"""
Routing Agent — Public Interface

Exposes: route(input_data) -> RoutingResult
"""

import logging
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

logger = logging.getLogger(__name__)

# ── Types ────────────────────────────────────────────────────

class RoutingResult:
    def __init__(self, route_options: List[Dict[str, Any]]):
        self.routeOptions = route_options

    def to_dict(self) -> Dict[str, Any]:
        return {"routeOptions": self.routeOptions}


# ── Public Interface ─────────────────────────────────────────

def route(input_data: Dict[str, Any]) -> RoutingResult:
    """
    Finds optimal route options for a shipment using the A* rerouting engine.

    Reads origin, destination, stops, and context from input_data.
    Maps named nodes to graph nodes in the mock network.

    Args:
        input_data: Must contain 'origin', 'destination'. Optional 'context' for
                    weather_risk, congestion, disruption_flag.

    Returns:
        RoutingResult with a list of routeOptions (at minimum the direct A* path).
    """
    logger.info("[routing_agent] Computing routes for shipment=%s", input_data.get("shipment_id"))

    # Ensure internal imports work regardless of cwd
    _agent_dir = str(Path(__file__).resolve().parent)
    if _agent_dir not in sys.path:
        sys.path.insert(0, _agent_dir)

    try:
        from models import EdgeContext, RerouteInput
        from reroute import reroute_shipment
        from graph import build_mock_graph

        ctx_raw = input_data.get("context", {})
        context = EdgeContext(
            weather_risk=float(ctx_raw.get("weather_risk", input_data.get("delayRisk", 0.3))),
            congestion=float(ctx_raw.get("congestion_index", 0.3)),
            disruption_flag=bool(ctx_raw.get("disruption_flag", False)),
        )

        origin = str(input_data.get("origin", "PORT_A")).upper()
        destination = str(input_data.get("destination", "PORT_D")).upper()
        stops = input_data.get("stops", [])

        # Build current route: origin → stops → destination
        current_route = [origin] + [str(s).upper() for s in stops] + [destination]

        reroute_input = RerouteInput(
            shipment_id=str(input_data.get("shipment_id", "UNKNOWN")),
            current_node=origin,
            destination_node=destination,
            current_route=current_route,
            context=context,
        )

        result = reroute_shipment(reroute_input)

        # Build route options list from the reroute result
        route_options = [
            {
                "routeIndex": 0,
                "nodes": result.new_route,
                "action": result.action,
                "estimatedTime": result.estimated_time,
                "improvement": round(result.improvement, 2),
                "reason": result.reason,
                "label": "optimal" if result.action == "REROUTED" else "current",
            }
        ]

        # Also include the original route as a baseline option if it differs
        if result.action == "REROUTED" and result.new_route != current_route:
            route_options.append({
                "routeIndex": 1,
                "nodes": current_route,
                "action": "UNCHANGED",
                "estimatedTime": result.estimated_time + result.improvement,
                "improvement": 0.0,
                "reason": None,
                "label": "baseline",
            })

        logger.info(
            "[routing_agent] action=%s nodes=%s improvement=%.2f",
            result.action, result.new_route, result.improvement,
        )

        return RoutingResult(route_options=route_options)

    except Exception as e:
        logger.error("[routing_agent] Routing failed: %s. Using passthrough fallback.", e)

        # Passthrough fallback: return the raw route from input
        origin = str(input_data.get("origin", "A"))
        destination = str(input_data.get("destination", "D"))
        stops = input_data.get("stops", [])
        passthrough = [origin] + [str(s) for s in stops] + [destination]

        return RoutingResult(route_options=[{
            "routeIndex": 0,
            "nodes": passthrough,
            "action": "PASSTHROUGH",
            "estimatedTime": None,
            "improvement": 0.0,
            "reason": f"routing_error: {e}",
            "label": "fallback",
        }])
