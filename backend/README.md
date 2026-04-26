# Meridian Logistics Backend

This directory contains the various AI-driven agents and routing systems for the Meridian logistics platform.

## Agent Directory Structure

### [Routing Agent](./routing-agent)
- **Purpose**: Core graph-based routing engine.
- **Algorithm**: A* pathfinding.
- **Interface**: FastAPI.

### [Optimization Agent](./optimization-agent)
- **Purpose**: Solves the Capacitated Vehicle Routing Problem (CVRP).
- **Technology**: Google OR-Tools.
- **Interface**: FastAPI.

### [Decision Agent](./decision-agent)
- **Purpose**: AI-driven decision making for rerouting and alerts.
- **Technology**: Gemini 1.5 Flash.
- **Interface**: FastAPI.

## Getting Started

Each agent is a standalone Python application with its own `requirements.txt`. To run any agent:

1. Navigate to the agent's directory.
2. Create a virtual environment: `python -m venv venv`.
3. Activate the environment: `venv\Scripts\activate` (Windows).
4. Install dependencies: `pip install -r requirements.txt`.
5. Run the application: `python main.py` or `uvicorn main:app`.
