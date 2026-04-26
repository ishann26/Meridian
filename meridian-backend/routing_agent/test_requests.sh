#!/usr/bin/env bash
# ============================================================
# Test commands for the Routing Agent
# Run each command in your terminal after the server is started
# ============================================================

BASE_URL="http://localhost:8000"

echo "=== 1. Health check ==="
curl -s "$BASE_URL/health" | python3 -m json.tool

echo ""
echo "=== 2. Compute route: Mumbai to Delhi via Nagpur ==="
curl -s -X POST "$BASE_URL/route" \
  -H "Content-Type: application/json" \
  -d '{
    "trip_id": "trip_001",
    "origin":      {"lat": 19.0760, "lng": 72.8777},
    "destination": {"lat": 28.6139, "lng": 77.2090},
    "waypoints":   [{"lat": 21.1458, "lng": 79.0882}],
    "departure_time": "2026-04-27T08:00:00Z",
    "avoid_tolls": false,
    "avoid_highways": false
  }' | python3 -m json.tool

echo ""
echo "=== 3. Compute route: Chennai to Bengaluru (no waypoints) ==="
curl -s -X POST "$BASE_URL/route" \
  -H "Content-Type: application/json" \
  -d '{
    "trip_id": "trip_002",
    "origin":      {"lat": 13.0827, "lng": 80.2707},
    "destination": {"lat": 12.9716, "lng": 77.5946},
    "departure_time": "2026-04-27T06:00:00Z",
    "avoid_tolls": false,
    "avoid_highways": false
  }' | python3 -m json.tool

echo ""
echo "=== 4. Fetch saved trip from database ==="
curl -s "$BASE_URL/trip/trip_001" | python3 -m json.tool

echo ""
echo "=== 5. List all trips ==="
curl -s "$BASE_URL/trips" | python3 -m json.tool
