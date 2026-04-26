# Meridian

A multi-agent logistics routing and prediction system.

## Project Structure

- **frontend/**: Flutter-based mobile and web application.
  - `lib/core/`: Core utilities and base classes.
  - `lib/data/`: Data sources and repositories.
  - `lib/features/`: Feature-specific logic and UI.
  - `lib/shared/`: Shared widgets and components.
- **backend/**: Python-based microservices and agents.
  - `agents/`: Individual specialized agents.
    - `decision_agent/`: Logic for high-level decision making.
    - `optimization_agent/`: Route optimization algorithms.
    - `prediction_agent/`: XGBoost-based delay prediction.
    - `routing_agent/`: Pathfinding and rerouting engine.
  - `requirements.txt`: Shared backend dependencies.

## Getting Started

### Backend
1. Navigate to `backend/`
2. Create a virtual environment: `python -m venv venv`
3. Install dependencies: `pip install -r requirements.txt`

### Frontend
1. Navigate to `frontend/`
2. Install Flutter dependencies: `flutter pub get`
3. Run the app: `flutter run`

## License
MIT
