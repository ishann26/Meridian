"""
Meridian Orchestrator
=====================

Runs the full multi-agent logistics pipeline in sequence:

  monitor → predict → route → optimize → decide → execute

Monitoring runs first to establish environmental context (weather risk,
deviation scores, severity) before the prediction model is invoked.

Usage
-----
    from orchestrator import run_pipeline

    result = run_pipeline({
        "shipment_id": "SHP001",
        "origin": "PORT_A",
        "destination": "PORT_D",
        "stops": ["PORT_B"],
    })
"""

import logging
import sys
import time
from pathlib import Path
from typing import Any, Dict

from dotenv import load_dotenv
load_dotenv(Path(__file__).resolve().parent / ".env")

# ── Logging ──────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s │ %(levelname)-8s │ %(name)-30s │ %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("meridian.orchestrator")

# ── Agent Imports ─────────────────────────────────────────────
# Each agent's __init__.py exposes its public interface.
# Agent directories are added to sys.path so they can resolve their own internals.

_AGENTS_DIR = Path(__file__).resolve().parent / "agents"


def _add_to_path(agent_name: str) -> None:
    p = str(_AGENTS_DIR / agent_name)
    if p not in sys.path:
        sys.path.insert(0, p)


for _agent in [
    "monitoring_agent",
    "prediction_agent",
    "routing_agent",
    "optimization_agent",
    "decision_agent",
    "execution_agent",
]:
    _add_to_path(_agent)

import agents.monitoring_agent as monitoring_agent
import agents.prediction_agent as prediction_agent
import agents.routing_agent as routing_agent
import agents.optimization_agent as optimization_agent
import agents.decision_agent as decision_agent
import agents.execution_agent as execution_agent


# ── Pipeline Steps ────────────────────────────────────────────

def _step(label: str, fn, ctx: Dict[str, Any]) -> Dict[str, Any]:
    """Run a single pipeline step with timing and error logging."""
    logger.info("━━ %s", label)
    t0 = time.perf_counter()
    try:
        result = fn(ctx)
        elapsed = time.perf_counter() - t0
        data = result.to_dict()
        logger.info("  ✓ done (%.2fs)", elapsed)
        return data
    except Exception as e:
        elapsed = time.perf_counter() - t0
        logger.error("  ✗ failed after %.2fs: %s", elapsed, e, exc_info=True)
        raise


# ── Orchestrator ──────────────────────────────────────────────

def run_pipeline(input_data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Execute the Meridian multi-agent pipeline.

    Flow:
        1. monitoring  — establishes environmental context & deviation score
        2. prediction  — delay risk using monitoring context
        3. routing     — A* route options using prediction context
        4. optimization— OR-Tools CVRP using routing options
        5. decision    — Gemini selects best action from all upstream data
        6. execution   — dispatches the decision

    Args:
        input_data: Shipment data dict. Required keys:
            - shipment_id (str)
            - origin      (str)  e.g. "PORT_A"
            - destination (str)  e.g. "PORT_D"
          Optional:
            - stops       (list[str])
            - context     (dict)  weather, congestion, disruption_flag, etc.
            - vehicle     (dict)  capacity_kg, max_driving_minutes
            - cargo_weight_kg, cargo_value_inr, cargo_type

    Returns:
        {
            monitoring,
            prediction,
            routing,
            optimization,
            decision,
            execution,
        }
    """
    pipeline_start = time.perf_counter()
    shipment_id = input_data.get("shipment_id", "UNKNOWN")

    logger.info("=" * 60)
    logger.info("  MERIDIAN PIPELINE  shipment=%s", shipment_id)
    logger.info("  %s → %s  stops=%s",
                input_data.get("origin"),
                input_data.get("destination"),
                input_data.get("stops", []))
    logger.info("=" * 60)

    # Rolling context — each step merges its output in so every
    # downstream agent sees all upstream data.
    ctx: Dict[str, Any] = {**input_data}

    # ── Step 1: Monitoring ────────────────────────────────────
    # Runs first to enrich the context with environmental state
    # (deviation score, severity, disruption flags) before the
    # prediction model is invoked.
    monitoring = _step(
        "[1/6] Monitoring Agent  ─ environment & deviation context",
        monitoring_agent.monitor,
        ctx,
    )
    # Merge updatedContext fields directly into ctx so downstream
    # agents can see severity, deviationScore, etc. as top-level keys.
    ctx.update(monitoring.get("updatedContext", {}))
    ctx["monitoring"] = monitoring

    logger.info("       severity=%s  score=%.1f  disruption=%s",
                ctx.get("severity"), ctx.get("deviationScore"), ctx.get("isDisruption"))

    # ── Step 2: Prediction ────────────────────────────────────
    prediction = _step(
        "[2/6] Prediction Agent  ─ delay risk score",
        prediction_agent.predict,
        ctx,
    )
    ctx.update(prediction)

    logger.info("       delayRisk=%.3f  riskLevel=%s",
                prediction.get("delayRisk"), prediction.get("context", {}).get("risk_level"))

    # ── Step 3: Routing ───────────────────────────────────────
    routing = _step(
        "[3/6] Routing Agent     ─ A* route options",
        routing_agent.route,
        ctx,
    )
    ctx.update(routing)

    best_route = routing.get("routeOptions", [{}])[0]
    logger.info("       action=%s  nodes=%s  improvement=%.2f",
                best_route.get("action"), best_route.get("nodes"), best_route.get("improvement", 0))

    # ── Step 4: Optimization ──────────────────────────────────
    optimization = _step(
        "[4/6] Optimization Agent ─ OR-Tools CVRP",
        optimization_agent.optimize,
        ctx,
    )
    ctx.update(optimization)

    sol = optimization.get("optimizedSolution", {})
    logger.info("       route=%s  distance=%s km  time=%s min",
                sol.get("route"), sol.get("totalDistance"), sol.get("totalTime"))

    # ── Step 5: Decision ──────────────────────────────────────
    # Receives the full merged context: input + monitoring +
    # prediction + routing + optimization.
    decision = _step(
        "[5/6] Decision Agent    ─ Gemini action selection",
        decision_agent.decide,
        ctx,
    )
    ctx.update(decision)

    logger.info("       bestAction=%s  confidence=%.2f",
                decision.get("bestAction"), decision.get("confidence"))

    # ── Step 6: Execution ─────────────────────────────────────
    # Only receives the decision output + minimal shipment info.
    execution_ctx: Dict[str, Any] = {
        "shipment_id": shipment_id,
        "bestAction": decision.get("bestAction"),
        "chosenRouteIndex": decision.get("chosenRouteIndex", 0),
        "alertMessage": decision.get("alertMessage", ""),
        "routeOptions": routing.get("routeOptions", []),
    }
    execution = _step(
        "[6/6] Execution Agent   ─ dispatch decision",
        execution_agent.execute,
        execution_ctx,
    )

    logger.info("       status=%s  action=%s",
                execution.get("status"), execution.get("actionTaken"))

    # ── Result ────────────────────────────────────────────────
    total_time = round(time.perf_counter() - pipeline_start, 3)

    logger.info("=" * 60)
    logger.info("  PIPELINE COMPLETE  shipment=%s  time=%.3fs", shipment_id, total_time)
    logger.info("=" * 60)

    return {
        "monitoring":   monitoring,
        "prediction":   prediction,
        "routing":      routing,
        "optimization": optimization,
        "decision":     decision,
        "execution":    execution,
    }
