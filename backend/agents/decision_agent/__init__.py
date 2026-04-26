"""
Decision Agent — Public Interface

Exposes: decide(input_data) -> DecisionResult
Backed by: Mistral-7B-Instruct via HuggingFace Inference API
Fallback:  Rule-based logic in agent.py
"""

import logging
import sys
from pathlib import Path
from typing import Any, Dict

logger = logging.getLogger(__name__)


# ── Types ────────────────────────────────────────────────────

class DecisionResult:
    def __init__(self, best_action: str, reasoning: str, confidence: float, raw: Dict[str, Any]):
        self.bestAction = best_action
        self.reasoning  = reasoning
        self.confidence = confidence
        self._raw       = raw

    def to_dict(self) -> Dict[str, Any]:
        return {
            "bestAction":  self.bestAction,
            "reasoning":   self.reasoning,
            "confidence":  self.confidence,
            # Include any extra fields the model returned
            **{k: v for k, v in self._raw.items()
               if k not in ("bestAction", "reasoning", "confidence")},
        }


# ── Helpers ──────────────────────────────────────────────────

def _build_trip_data(input_data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Build the minimal trip_data dict expected by agent.get_decision().
    Only passes what Mistral needs — keeps the prompt concise.
    """
    route_options = input_data.get("routeOptions", [])
    optimized     = input_data.get("optimizedSolution", {})

    return {
        "delayRisk":   input_data.get("delayRisk", 0.0),
        "routeOptions": [
            {
                "index":         r.get("routeIndex", i),
                "nodes":         r.get("nodes", []),
                "estimatedTime": r.get("estimatedTime"),
                "improvement":   r.get("improvement", 0.0),
                "label":         r.get("label", "option"),
            }
            for i, r in enumerate(route_options)
        ],
        "optimizedSolution": {
            "route":         optimized.get("route", []),
            "totalDistance": optimized.get("totalDistance"),
            "totalTime":     optimized.get("totalTime"),
        },
        "constraints": input_data.get("constraints", {}),
    }


# ── Public Interface ─────────────────────────────────────────

def decide(input_data: Dict[str, Any]) -> DecisionResult:
    """
    Query Mistral-7B-Instruct via HuggingFace Inference API for a routing decision.

    Falls back automatically to rule-based logic on any API failure.

    Args:
        input_data: Merged pipeline context. Key fields:
            - delayRisk        (float)
            - routeOptions     (list)
            - optimizedSolution(dict)
            - constraints      (dict, optional)

    Returns:
        DecisionResult with bestAction ("reroute"|"wait"|"proceed"),
        reasoning, and confidence.
    """
    logger.info("[decision_agent] Making decision for shipment=%s", input_data.get("shipment_id"))

    _agent_dir = str(Path(__file__).resolve().parent)
    if _agent_dir not in sys.path:
        sys.path.insert(0, _agent_dir)

    from agent import get_decision

    trip_data = _build_trip_data(input_data)
    raw = get_decision(trip_data)   # never raises — has internal fallback

    logger.info(
        "[decision_agent] action=%s  confidence=%.2f",
        raw.get("bestAction"), raw.get("confidence", 0.0),
    )

    return DecisionResult(
        best_action=raw.get("bestAction", "proceed"),
        reasoning=raw.get("reasoning", ""),
        confidence=float(raw.get("confidence", 0.5)),
        raw=raw,
    )
