import os
import json
import logging
import google.generativeai as genai
from typing import Dict, Any
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = """
You are an advanced logistics Decision Agent for a real-time shipment routing system.

Your role is to evaluate incoming trip data and produce a precise, actionable decision.

Input Fields:
- delayRisk: A float between 0 and 1 (higher = greater chance of delay)
- predictionScore: A float between 0 and 1 (model confidence in the prediction)
- routeOptions: A list of candidate routes with their estimated time and cost
- optimizedSolution: The route suggested by the route optimizer (A* / OR-Tools)
- constraints: Business or operational constraints (vehicle capacity, time windows, etc.)

Your task:
1. Evaluate the delay risk — if >= 0.7, strongly consider rerouting.
2. Compare all route options against the optimizedSolution on time and cost.
3. Verify the optimizedSolution satisfies all given constraints.
4. Choose the single best action from: PROCEED, REROUTE, HOLD, ESCALATE.
5. Choose the best route by its 0-based index from the routeOptions list.
6. Estimate how many minutes would be saved versus the baseline (index 0) route.
7. Generate a brief, human-readable alert message for the driver/dispatcher.

Respond ONLY with a valid JSON object:
{
  "bestAction": "<PROCEED | REROUTE | HOLD | ESCALATE>",
  "chosenRouteIndex": <integer>,
  "reasoning": "<concise explanation, max 3 sentences>",
  "confidence": <float 0.0–1.0>,
  "expectedImprovementMinutes": <integer>,
  "alertMessage": "<driver/dispatcher-facing message, max 20 words>"
}
"""

def get_decision(trip_data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Calls Gemini API to get a routing decision based on trip data.
    """
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        raise ValueError("GEMINI_API_KEY environment variable not set.")
    
    genai.configure(api_key=api_key)
    model = genai.GenerativeModel("gemini-1.5-flash") # Using 1.5 flash as 2.5 flash-lite isn't standard yet
    
    prompt = f"{SYSTEM_PROMPT}\n\nTrip Data:\n{json.dumps(trip_data, indent=2)}"
    
    try:
        response = model.generate_content(
            prompt,
            generation_config=genai.types.GenerationConfig(
                temperature=0.2,
                response_mime_type="application/json",
            )
        )
        
        result = json.loads(response.text.strip())
        return result
    except Exception as e:
        logger.error(f"Error calling Gemini: {e}")
        raise
