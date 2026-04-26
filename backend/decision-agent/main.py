import logging
from fastapi import FastAPI, HTTPException
from typing import Dict, Any
import uvicorn
from agent import get_decision

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Decision Agent API")

@app.get("/")
def read_root():
    return {"message": "Decision Agent is active."}

@app.post("/decide")
def decide(payload: Dict[str, Any]):
    """
    Accepts trip data and returns an AI-driven decision.
    """
    logger.info("Received decision request.")
    
    # Validate required fields
    required_fields = ["delayRisk", "predictionScore", "routeOptions", "optimizedSolution"]
    for field in required_fields:
        if field not in payload:
            raise HTTPException(status_code=400, detail=f"Missing required field: {field}")
            
    try:
        decision = get_decision(payload)
        logger.info("Decision generated successfully.")
        return decision
    except Exception as e:
        logger.error(f"Failed to generate decision: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8001, reload=True)
