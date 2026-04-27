/**
 * router.js — Shipment rerouting logic for the Execution Agent.
 *
 * Functions:
 *  - rerouteShipment(event) → Returns a rerouting decision based on disruption event
 */

"use strict";

const ROUTING_AGENT_URL = process.env.ROUTING_AGENT_URL || "http://127.0.0.1:8001/reroute";

/**
 * Call real routing logic
 * @param {Object} params
 * @param {string} params.shipment_id
 * @param {Object} params.current_state
 * @param {Object} params.predictions
 */
async function rerouteShipment({ shipment_id, current_state, predictions }) {
  if (!shipment_id) {
    throw new Error("rerouteShipment: shipment_id is required.");
  }

  // Construct the payload for the Routing Agent
  // Based on RerouteInput in models.py
  const payload = {
    shipment_id: String(shipment_id),
    current_node: "N2", // Mapping mocked since Execution Agent lacks graph nodes natively
    destination_node: "N10",
    current_route: ["N1", "N2", "N3", "N4"],
    context: {
      weather_risk: predictions?.delay_probability ?? 0.5,
      congestion: 0.2,
      disruption_flag: true
    }
  };

  try {
    const response = await fetch(ROUTING_AGENT_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload)
    });

    if (!response.ok) {
      const txt = await response.text();
      throw new Error(`Routing agent error: ${response.status} ${txt}`);
    }

    const data = await response.json();
    console.log(
      `[Router] Rerouted shipment ${data.shipment_id} → ` +
      `route=[${data.new_route.join(" → ")}] ` +
      `improvement=${data.improvement}`
    );

    return {
      action: data.action,
      shipment_id: data.shipment_id,
      new_route: data.new_route,
      estimated_time: data.estimated_time,
      improvement: data.improvement,
      reason: data.reason
    };
  } catch (err) {
    console.error(`[Router] Failed to reroute shipment ${shipment_id}: ${err.message}`);
    throw err;
  }
}

module.exports = { rerouteShipment };
