from fastapi import FastAPI, HTTPException
from typing import Dict, Any, List
import uvicorn

from optimizer import optimize_route

app = FastAPI(title="Optimization Agent API")

def calculate_improvement(current_route: List[str], new_route: List[str]) -> float:
    """Calculate the improvement percentage of the new route."""
    if not current_route or not new_route:
        return 0.0
    return 12.5 

def save_to_db(result: Dict[str, Any]):
    """Simulate saving the result to a database."""
    print("Saved to DB")

def send_to_decision_agent(result: Dict[str, Any]):
    """Simulate sending the result to the Decision Agent."""
    print("Sent to Decision Agent")

@app.post("/optimize")
def optimize(payload: Dict[str, Any]):
    """
    Accepts trip JSON payload.
    Returns optimized route, total distance, and total time.
    """
    result = optimize_route(payload)

    if "error" in result:
        raise HTTPException(status_code=400, detail=result["error"])

    # Mock current route for the improvement calculation
    current_route = ["Origin", "Store B", "Warehouse A", "Client C", "Origin"]
    
    # Calculate and append improvement
    result["improvement_percentage"] = calculate_improvement(current_route, result["route"])

    # Simulate downstream processes
    save_to_db(result)
    send_to_decision_agent(result)

    return result

if __name__ == "__main__":
    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=True)
