"use strict";

require("dotenv").config();

const subscriber          = require("./subscriber");
const { updateShipment }  = require("./firestore");
const { sendAlert }       = require("./notifier");
const { rerouteShipment } = require("./router");
const { withRetry }       = require("./utils");

// ── processEvent ──────────────────────────────────────────────────────────────

async function processEvent(event) {
  const severity = (event.severity ?? "LOW").toUpperCase();
  const id       = event.shipment_id;

  // ── Log incoming event ──────────────────────────────────────────────────────
  console.log(`\n[Event] ────────────────────────────────────`);
  console.log(`[Event] Received   : shipment_id=${id}`);
  console.log(`[Event] Severity   : ${severity}`);
  console.log(`[Event] Reason     : ${event.reason ?? "N/A"}`);
  console.log(`[Event] Score      : ${event.deviation_score ?? "N/A"}`);
  console.log(`[Event] Delay pred : ${event.predictions?.predicted_delay_minutes ?? "N/A"} min`);
  console.log(`[Event] ────────────────────────────────────`);

  const result = { shipment_id: id, severity, actions_taken: [], errors: [] };
  const fsData = {
    severity,
    delay_prediction: event.predictions?.delay_minutes ?? null,
    current_location: event.current_state?.location ?? null,
  };

  // ── Action helpers ──────────────────────────────────────────────────────────

  async function tryUpdateShipment() {
    console.log(`[Action] updateShipment → START  (shipment=${id})`);
    try {
      await withRetry(() => updateShipment(id, fsData));
      result.actions_taken.push("updateShipment");
      console.log(`[Action] updateShipment → OK     (shipment=${id})`);
    } catch (err) {
      result.errors.push(`updateShipment: ${err.message}`);
      console.error(`[Action] updateShipment → FAILED (shipment=${id}): ${err.message}`);
      throw err;   // fatal — trigger nack
    }
  }

  async function trySendAlert() {
    console.log(`[Action] sendAlert      → START  (shipment=${id})`);
    try {
      await withRetry(() => sendAlert(event));
      result.actions_taken.push("sendAlert");
      console.log(`[Action] sendAlert      → OK     (shipment=${id})`);
    } catch (err) {
      result.errors.push(`sendAlert: ${err.message}`);
      console.error(`[Action] sendAlert      → FAILED (shipment=${id}): ${err.message} [non-fatal]`);
    }
  }

  async function tryReroute() {
    console.log(`[Action] rerouteShipment→ START  (shipment=${id})`);
    try {
      result.rerouting = await rerouteShipment({
        shipment_id: id,
        current_state: event.current_state,
        predictions: event.predictions
      });
      result.actions_taken.push("rerouteShipment");
      console.log(
        `[Action] rerouteShipment→ OK     (shipment=${id}) ` +
        `route=[${result.rerouting.new_route.join(" → ")}] improvement=${result.rerouting.improvement}`
      );
      
      // Add routing result to Firestore update data
      fsData.new_route = result.rerouting.new_route;
      fsData.estimated_time = result.rerouting.estimated_time;
    } catch (err) {
      result.errors.push(`rerouteShipment: ${err.message}`);
      console.error(`[Action] rerouteShipment→ FAILED (shipment=${id}): ${err.message} [non-fatal]`);
    }
  }

  // ── Severity routing ────────────────────────────────────────────────────────

  if (severity === "LOW") {
    await tryUpdateShipment();

  } else if (severity === "MEDIUM" || severity === "MODERATE") {
    await tryUpdateShipment();
    await trySendAlert();

  } else if (severity === "HIGH" || severity === "CRITICAL") {
    await tryReroute();
    await tryUpdateShipment();
    await trySendAlert();

  } else {
    console.warn(`[Event] Unknown severity "${severity}" — defaulting to updateShipment.`);
    await tryUpdateShipment();
  }

  // ── Summary log ─────────────────────────────────────────────────────────────
  const ok = result.errors.length === 0;
  console.log(`[Event] ────────────────────────────────────`);
  console.log(`[Event] Done       : shipment=${id}`);
  console.log(`[Event] Actions    : ${result.actions_taken.join(", ") || "none"}`);
  if (result.errors.length > 0) {
    console.warn(`[Event] Errors     : ${result.errors.join(" | ")}`);
  }
  console.log(`[Event] Status     : ${ok ? "SUCCESS" : "PARTIAL"}`);
  console.log(`[Event] ────────────────────────────────────\n`);

  return result;
}

module.exports = { processEvent };

// ── Start ─────────────────────────────────────────────────────────────────────

if (require.main === module) {
  subscriber.startListening(processEvent);
  console.log("Execution Agent Running");
}
