"""
Monitoring Agent — Public Interface

Exposes: monitor(input_data) -> MonitoringResult

The monitoring_agent has deep GCP dependencies (BigQuery, Firestore, Pub/Sub).
This adapter wraps a lightweight in-process health check that mirrors the
full engine's deviation scoring logic — without cloud service calls.

To run the full cloud-connected engine, start monitoring_agent/main.py directly.
"""

import logging
from datetime import datetime, timedelta
from typing import Any, Dict, Optional

logger = logging.getLogger(__name__)


# ── Types ────────────────────────────────────────────────────

class MonitoringOutput:
    def __init__(self, updated_context: Dict[str, Any]):
        self.updatedContext = updated_context

    def to_dict(self) -> Dict[str, Any]:
        return {"updatedContext": self.updatedContext}


# ── Helpers ──────────────────────────────────────────────────

def _severity_from_score(score: float) -> str:
    if score < 25:
        return "NORMAL"
    elif score < 45:
        return "LOW"
    elif score < 65:
        return "MODERATE"
    elif score < 85:
        return "HIGH"
    return "CRITICAL"


def _compute_deviation_score(
    delay_risk: float,
    execution_status: str,
    best_action: str,
) -> float:
    """
    Lightweight deviation scoring mirroring MonitoringEngine._compute_deviation_score.

    Uses pipeline outputs rather than live GCP data:
      - w_risk:   40% weight  (delay_risk from prediction)
      - w_action: 40% weight  (whether action was a reroute/hold/escalate)
      - w_exec:   20% weight  (whether execution succeeded)
    """
    risk_score = delay_risk * 100.0  # 0-100

    action_score_map = {
        "PROCEED":  10.0,
        "REROUTE":  60.0,
        "HOLD":     75.0,
        "ESCALATE": 90.0,
    }
    action_score = action_score_map.get(best_action, 10.0)

    exec_score = 0.0 if execution_status == "SUCCESS" else 80.0

    return round(
        0.40 * risk_score +
        0.40 * action_score +
        0.20 * exec_score,
        2,
    )


def _needs_rerun(deviation_score: float, severity: str) -> bool:
    """Determines if the pipeline should loop (rerun with updated context)."""
    return severity in ("HIGH", "CRITICAL") or deviation_score >= 65.0


# ── Public Interface ─────────────────────────────────────────

def monitor(input_data: Dict[str, Any]) -> MonitoringOutput:
    """
    Evaluates the pipeline execution result and produces an updated context.

    Computes a deviation score from the pipeline outputs, maps it to a severity
    level, and flags whether the pipeline should be re-run with updated context.

    Args:
        input_data: Merged pipeline context. Key fields used:
                    - delayRisk, predictionScore (from prediction)
                    - bestAction (from decision)
                    - status (from execution)
                    - shipment_id

    Returns:
        MonitoringOutput with updatedContext including severity, score, and
        a `requiresRerun` flag for the orchestrator loop.
    """
    logger.info(
        "[monitoring_agent] Evaluating pipeline result for shipment=%s",
        input_data.get("shipment_id"),
    )

    delay_risk = float(input_data.get("delayRisk", 0.0))
    best_action = str(input_data.get("bestAction", "PROCEED"))
    execution_status = str(input_data.get("status", "SUCCESS"))
    shipment_id = str(input_data.get("shipment_id", "UNKNOWN"))

    deviation_score = _compute_deviation_score(delay_risk, execution_status, best_action)
    severity = _severity_from_score(deviation_score)
    requires_rerun = _needs_rerun(deviation_score, severity)
    is_disruption = deviation_score >= 65.0

    disruption_reason: Optional[str] = None
    if is_disruption:
        if delay_risk >= 0.7:
            disruption_reason = "HIGH_DELAY_RISK"
        elif best_action == "ESCALATE":
            disruption_reason = "ESCALATED"
        elif execution_status != "SUCCESS":
            disruption_reason = "EXECUTION_FAILURE"
        else:
            disruption_reason = "COMBINED_RISK"

    updated_context = {
        "shipment_id": shipment_id,
        "deviationScore": deviation_score,
        "severity": severity,
        "isDisruption": is_disruption,
        "disruptionReason": disruption_reason,
        "requiresRerun": requires_rerun,
        "evaluatedAt": datetime.utcnow().isoformat() + "Z",
        # Pass through key context for the next pipeline iteration
        "delayRisk": delay_risk,
        "bestAction": best_action,
        "executionStatus": execution_status,
    }

    logger.info(
        "[monitoring_agent] shipment=%s score=%.1f severity=%s disruption=%s requiresRerun=%s",
        shipment_id, deviation_score, severity, is_disruption, requires_rerun,
    )

    if is_disruption:
        logger.warning(
            "[monitoring_agent] 🚨 DISRUPTION DETECTED — shipment=%s reason=%s severity=%s",
            shipment_id, disruption_reason, severity,
        )

    return MonitoringOutput(updated_context=updated_context)
