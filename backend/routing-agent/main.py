from models import EdgeContext, RerouteInput
from reroute import reroute_shipment
import json

def main() -> None:
    # 2. Sample input exactly as requested
    input_data = {
      "shipment_id": "SHP001",
      "current_node": "PORT_A",
      "destination_node": "PORT_D",
      "current_route": ["PORT_A", "PORT_B", "PORT_D"],
      "context": {
        "weather_risk": 0.8,
        "congestion": 0.2,
        "disruption_flag": False
      }
    }
    
    reroute_input = RerouteInput(
        shipment_id=input_data["shipment_id"],
        current_node=input_data["current_node"],
        destination_node=input_data["destination_node"],
        current_route=input_data["current_route"],
        context=EdgeContext(**input_data["context"])
    )

    # 1. Calls reroute_shipment()
    result = reroute_shipment(reroute_input)
    
    # 3. Prints output clearly
    print("=== RESULT ===")
    print(json.dumps({
        "shipment_id": result.shipment_id,
        "action": result.action,
        "new_route": result.new_route,
        "estimated_time": result.estimated_time,
        "improvement": result.improvement,
        "reason": result.reason
    }, indent=2))

if __name__ == "__main__":
    main()
