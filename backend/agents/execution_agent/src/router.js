/**
 * router.js — Shipment rerouting logic for the Execution Agent.
 *
 * Functions:
 *  - rerouteShipment(event) → Returns a rerouting decision based on disruption event
 */

"use strict";

// ── Mock route nodes (simulating a logistics network) ─────────────────────────

const MOCK_ROUTES = {
  LOW:      { nodes: ["N1", "N2", "N3"],          improvement: 10 },
  MODERATE: { nodes: ["N1", "N3", "N5"],          improvement: 25 },
  HIGH:     { nodes: ["N2", "N4", "N6", "N8"],    improvement: 40 },
  CRITICAL: { nodes: ["N1", "N7", "N9", "N10"],   improvement: 60 },
};

const DEFAULT_ROUTE = { nodes: ["N1", "N2", "N3"], improvement: 10 };

// ── rerouteShipment ───────────────────────────────────────────────────────────

/**
 * Decide on a rerouting action for a disrupted shipment.
 *
 * @param {Object} event                    - DisruptionEvent from Pub/Sub
 * @param {string} event.shipment_id
 * @param {string} [event.severity]         - "LOW" | "MODERATE" | "HIGH" | "CRITICAL"
 * @param {Object} [event.current_state]    - { location, status, speed_kmh, ... }
 * @param {Object} [event.predictions]      - { delay_probability, predicted_delay_minutes, ... }
 *
 * @returns {{
 *   action:      string,
 *   shipment_id: string,
 *   new_route:   string[],
 *   improvement: number,
 *   severity:    string,
 *   decided_at:  string
 * }}
 */
function rerouteShipment(event) {
  if (!event || !event.shipment_id) {
    throw new Error("rerouteShipment: event with shipment_id is required.");
  }

  const severity  = (event.severity ?? "LOW").toUpperCase();
  const route     = MOCK_ROUTES[severity] ?? DEFAULT_ROUTE;

  const decision = {
    action:      "REROUTED",
    shipment_id: String(event.shipment_id),
    new_route:   route.nodes,
    improvement: route.improvement,
    severity,
    decided_at:  new Date().toISOString(),
  };

  console.log(
    `[Router] Rerouted shipment ${decision.shipment_id} → ` +
    `route=[${decision.new_route.join(" → ")}] ` +
    `improvement=${decision.improvement}% severity=${severity}`
  );

  return decision;
}

// ── Exports ───────────────────────────────────────────────────────────────────

module.exports = { rerouteShipment };
