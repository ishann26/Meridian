"""
Execution Agent — Public Interface

Exposes: execute(input_data) -> ExecutionResult

The execution agent is a Node.js service. This Python adapter handles:
  1. Calling the Node.js HTTP API if it's running.
  2. Falling back to a deterministic in-process simulation if not.
"""

import logging
import os
from typing import Any, Dict

logger = logging.getLogger(__name__)

# Default port matches execution_agent's package.json / config
_EXECUTION_AGENT_URL = os.environ.get("EXECUTION_AGENT_URL", "http://localhost:3002")


# ── Types ────────────────────────────────────────────────────

class ExecutionResult:
    def __init__(self, status: str, action_taken: str, details: Dict[str, Any]):
        self.status = status
        self.actionTaken = action_taken
        self._details = details

    def to_dict(self) -> Dict[str, Any]:
        return {
            "status": self.status,
            "actionTaken": self.actionTaken,
            **self._details,
        }


# ── Helpers ──────────────────────────────────────────────────

def _simulate_execution(input_data: Dict[str, Any]) -> ExecutionResult:
    """Deterministic in-process execution simulation."""
    best_action = input_data.get("bestAction", "PROCEED")
    shipment_id = input_data.get("shipment_id", "UNKNOWN")
    chosen_route_index = input_data.get("chosenRouteIndex", 0)
    route_options = input_data.get("routeOptions", [])

    chosen_route = (
        route_options[chosen_route_index].get("nodes", [])
        if chosen_route_index < len(route_options)
        else []
    )

    action_map = {
        # Uppercase (legacy Gemini format)
        "PROCEED":  f"Shipment {shipment_id} proceeding on current route.",
        "REROUTE":  f"Shipment {shipment_id} rerouted to route index {chosen_route_index}: {chosen_route}.",
        "HOLD":     f"Shipment {shipment_id} placed on hold pending review.",
        "ESCALATE": f"Shipment {shipment_id} escalated to operations team.",
        # Lowercase (HuggingFace / Mistral format)
        "proceed":  f"Shipment {shipment_id} proceeding on current route.",
        "reroute":  f"Shipment {shipment_id} rerouted to route index {chosen_route_index}: {chosen_route}.",
        "wait":     f"Shipment {shipment_id} placed on hold; monitoring conditions.",
    }

    action_taken = action_map.get(best_action, f"Unknown action: {best_action}")
    logger.info("[execution_agent] %s", action_taken)

    return ExecutionResult(
        status="SUCCESS",
        action_taken=action_taken,
        details={
            "shipment_id": shipment_id,
            "executedAction": best_action,
            "chosenRoute": chosen_route,
            "source": "in_process_simulation",
        },
    )


# ── Public Interface ─────────────────────────────────────────

def execute(input_data: Dict[str, Any]) -> ExecutionResult:
    """
    Executes the decision produced by the decision agent.

    Attempts to call the Node.js execution_agent HTTP service first.
    Falls back to in-process simulation if the service is unavailable.

    Args:
        input_data: Merged pipeline context. Must include 'bestAction'.

    Returns:
        ExecutionResult with status and actionTaken.
    """
    logger.info(
        "[execution_agent] Executing action=%s for shipment=%s",
        input_data.get("bestAction"), input_data.get("shipment_id"),
    )

    try:
        import httpx

        payload = {
            "shipment_id": input_data.get("shipment_id"),
            "action": input_data.get("bestAction", "PROCEED"),
            "chosenRouteIndex": input_data.get("chosenRouteIndex", 0),
            "routeOptions": input_data.get("routeOptions", []),
            "alertMessage": input_data.get("alertMessage", ""),
        }

        response = httpx.post(
            f"{_EXECUTION_AGENT_URL}/execute",
            json=payload,
            timeout=httpx.Timeout(connect=1.0, read=5.0, write=5.0, pool=5.0),
        )
        response.raise_for_status()
        data = response.json()

        logger.info("[execution_agent] Node.js service responded with status=%s", data.get("status"))

        return ExecutionResult(
            status=data.get("status", "SUCCESS"),
            action_taken=data.get("actionTaken", str(data)),
            details=data,
        )

    except ImportError:
        logger.warning("[execution_agent] httpx not installed. Using in-process simulation.")
    except Exception as e:
        logger.warning("[execution_agent] Node.js service unavailable (%s). Using simulation.", e)

    return _simulate_execution(input_data)
