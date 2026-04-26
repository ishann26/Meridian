"""
Decision Agent — Hugging Face Inference Backend

Uses Qwen2.5-72B-Instruct via the HuggingFace Hub InferenceClient.
Falls back to deterministic rule-based logic on any failure.
"""

import json
import logging
import os
import re
import time
from typing import Any, Dict
from huggingface_hub import InferenceClient
from huggingface_hub.errors import HfHubHTTPError
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)

# ── Config ───────────────────────────────────────────────────
HF_MODEL = "Qwen/Qwen2.5-72B-Instruct"
HF_API_KEY = os.environ.get("HF_API_KEY", "")

_REQUEST_TIMEOUT = 30       # seconds
_MAX_NEW_TOKENS  = 512


# ── Prompt Builder ───────────────────────────────────────────

def _build_prompt(trip_data: Dict[str, Any]) -> str:
    """
    Construct a system prompt that asks the model to evaluate
    the shipment and return a strict JSON decision object.
    """
    delay_risk        = trip_data.get("delayRisk", 0.0)
    route_options     = trip_data.get("routeOptions", [])
    optimized         = trip_data.get("optimizedSolution", {})
    constraints       = trip_data.get("constraints", {})

    context = json.dumps({
        "delayRisk":        delay_risk,
        "routeOptions":     route_options,
        "optimizedSolution": optimized,
        "constraints":      constraints,
    }, indent=2)

    return (
        "You are an expert logistics decision engine. "
        "Analyse the shipment data below and return ONLY a valid JSON object — no explanation, "
        "no markdown, no extra text.\n\n"
        "Rules:\n"
        "1. If delayRisk >= 0.7 → strongly favour 'reroute'.\n"
        "2. If delayRisk < 0.3  → strongly favour 'proceed'.\n"
        "3. Otherwise           → consider route options and constraints before choosing 'wait'.\n"
        "4. Compare every route option against optimizedSolution (time + cost).\n"
        "5. Verify all constraints are satisfied by your chosen action.\n\n"
        "Required output format (JSON only, no other text):\n"
        "{\n"
        '  "bestAction": "reroute" | "wait" | "proceed",\n'
        '  "reasoning":  "<one concise sentence>",\n'
        '  "confidence": <float 0.0–1.0>\n'
        "}\n\n"
        f"Shipment Data:\n{context}"
    )


# ── Response Parser ──────────────────────────────────────────

def _parse_response(raw_text: str) -> Dict[str, Any]:
    """
    Robustly extract the JSON decision from the model's raw output.
    """
    text = raw_text.strip()

    # Strategy 1 — extract first {...} block via regex
    match = re.search(r"\{[^{}]*\}", text, re.DOTALL)
    if match:
        try:
            return json.loads(match.group())
        except json.JSONDecodeError:
            pass

    # Strategy 2 — direct parse
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass

    # Strategy 3 — manual field extraction
    logger.warning("JSON parse failed; attempting manual key extraction.")
    action_match = re.search(r'"bestAction"\s*:\s*"(reroute|wait|proceed)"', text, re.IGNORECASE)
    reason_match = re.search(r'"reasoning"\s*:\s*"([^"]+)"', text)
    conf_match   = re.search(r'"confidence"\s*:\s*([0-9.]+)', text)

    if action_match:
        return {
            "bestAction":  action_match.group(1).lower(),
            "reasoning":   reason_match.group(1) if reason_match else "Extracted from partial response.",
            "confidence":  float(conf_match.group(1)) if conf_match else 0.5,
        }

    raise ValueError(f"Could not extract a valid decision from model output:\n{raw_text[:500]}")


# ── Rule-Based Fallback ──────────────────────────────────────

def _rule_based_decision(trip_data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Simple deterministic fallback when the HF API is unavailable.
    """
    delay_risk = float(trip_data.get("delayRisk", 0.0))

    if delay_risk > 0.7:
        action, reasoning, confidence = (
            "reroute",
            f"Delay risk {delay_risk:.2f} exceeds threshold (0.7); rerouting recommended.",
            round(delay_risk, 2),
        )
    elif delay_risk < 0.3:
        action, reasoning, confidence = (
            "proceed",
            f"Delay risk {delay_risk:.2f} is low (< 0.3); proceed as planned.",
            round(1.0 - delay_risk, 2),
        )
    else:
        action, reasoning, confidence = (
            "wait",
            f"Delay risk {delay_risk:.2f} is moderate; hold and monitor conditions.",
            0.5,
        )

    logger.info("[decision_agent/fallback] action=%s confidence=%.2f", action, confidence)
    return {"bestAction": action, "reasoning": reasoning, "confidence": confidence}


# ── Public Interface ─────────────────────────────────────────

def get_decision(trip_data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Query Qwen2.5-72B-Instruct via HuggingFace Inference API for a routing decision.

    Args:
        trip_data: Dict containing delayRisk, routeOptions, optimizedSolution, constraints.

    Returns:
        Dict with bestAction, reasoning, confidence.
    """
    if not HF_API_KEY:
        logger.warning("[decision_agent] HF_API_KEY not set. Using rule-based fallback.")
        return _rule_based_decision(trip_data)

    client = InferenceClient(api_key=HF_API_KEY)
    prompt = _build_prompt(trip_data)

    try:
        logger.info("[decision_agent] Calling HuggingFace API — model=%s", HF_MODEL)
        t0 = time.perf_counter()

        response = client.chat.completions.create(
            model=HF_MODEL,
            messages=[{"role": "user", "content": prompt}],
            max_tokens=_MAX_NEW_TOKENS,
            temperature=0.2,
            top_p=0.9
        )

        elapsed = time.perf_counter() - t0
        logger.info("[decision_agent] HF API responded in %.2fs", elapsed)

        raw_text = response.choices[0].message.content
        result = _parse_response(raw_text)

        # Normalise action to lowercase
        result["bestAction"] = str(result.get("bestAction", "proceed")).lower()
        result["confidence"] = float(result.get("confidence", 0.5))
        result["reasoning"]  = str(result.get("reasoning", ""))

        logger.info(
            "[decision_agent] HF decision: action=%s  confidence=%.2f",
            result["bestAction"], result["confidence"],
        )
        return result

    except HfHubHTTPError as e:
        logger.error("[decision_agent] HF API HTTP error: %s. Using fallback.", e)
    except ValueError as e:
        logger.error("[decision_agent] Response parse error: %s. Using fallback.", e)
    except Exception as e:
        logger.error("[decision_agent] Unexpected error: %s. Using fallback.", e)

    return _rule_based_decision(trip_data)
