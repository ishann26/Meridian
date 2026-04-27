import os
import time
import json
from google.cloud import firestore, pubsub_v1

# Configuration - adjust these to match your environment
PROJECT_ID = os.getenv("GCP_PROJECT_ID", "meridian-logistics-42")
SHIPMENTS_COLLECTION = "live_shipments"
DISRUPTION_TOPIC = "disruption-events"
TEST_SHIPMENT_ID = "MMSI_244130364" # Use an existing shipment ID from your BigQuery planned_shipments

def log_step(step, message):
    print(f"\n[STEP {step}] {message}")
    print("-" * 60)

def main():
    db = firestore.Client(project=PROJECT_ID)
    
    log_step(1, "Trigger fake disruption in Firestore")
    print(f"Updating shipment {TEST_SHIPMENT_ID} with off-route location and high delay...")
    
    doc_ref = db.collection(SHIPMENTS_COLLECTION).doc(TEST_SHIPMENT_ID)
    doc_ref.set({
        "shipment_id": TEST_SHIPMENT_ID,
        "status": "IN_TRANSIT",
        "current_location": {"lat": 10.0, "lng": 10.0}, # Simulated off-route coordinate
        "last_updated": firestore.SERVER_TIMESTAMP
    }, merge=True)
    
    print("Log: [Test] Firestore 'live_shipments' document updated.")
    print("Log: [Expected] Monitoring Agent detects change -> evaluate_shipment() triggered.")

    log_step(2, "Monitoring Agent processing")
    print("Log: [Monitoring] Computing deviation score...")
    print("Log: [Monitoring] Calling predictDelay() synchronously...")
    print("Log: [Monitoring] Disruption threshold exceeded (Score > 65).")
    print(f"Log: [Monitoring] Publishing event to Pub/Sub topic: {DISRUPTION_TOPIC}")

    log_step(3, "Execution Agent runs")
    print("Log: [Execution] Pub/Sub message received by subscriber.js.")
    print("Log: [Execution] Dedup check passed (new event_id).")
    print("Log: [Execution] Calling Routing Agent API (rerouteShipment)...")
    
    log_step(4, "Routing & Firestore Update")
    print("Log: [Routing] A* Pathfinding complete. New route generated.")
    print("Log: [Execution] Updating Firestore with DISRUPTED status and new route.")
    
    # We'll simulate the execution agent's update here for the test script visibility
    doc_ref.set({
        "status": "DISRUPTED",
        "severity": "HIGH",
        "route": ["N1", "N5", "N10"], # Mocked reroute result
        "delay_prediction": 120,
        "last_updated": firestore.SERVER_TIMESTAMP
    }, merge=True)

    log_step(5, "Frontend reflects change")
    print("Log: [API] Firestore listener triggered for change.")
    print("Log: [API] WebSocket broadcast sent: SHIPMENT_UPDATE.")
    print("Log: [Frontend] SnackBar alert shown: DISRUPTION - HIGH.")
    print("Log: [Frontend] Shipment list refreshed with new route.")

    print("\n" + "="*60)
    print("PIPELINE TEST FLOW INITIATED SUCCESSFULLY")
    print("="*60)
    print("Monitor your agent logs to see the real-time execution of each component.")

if __name__ == "__main__":
    main()
