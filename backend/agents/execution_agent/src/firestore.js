/**
 * firestore.js — Firestore module for the Execution Agent.
 *
 * Functions:
 *  - updateShipment(shipment_id, data) → Upsert shipment document with disruption state
 */

"use strict";

const { Firestore } = require("@google-cloud/firestore");
const config = require("./config");

// ── Singleton client ──────────────────────────────────────────────────────────

const db = new Firestore({ projectId: config.gcpProjectId });

// ── updateShipment ────────────────────────────────────────────────────────────

/**
 * Upsert a shipment document in Firestore with disruption state.
 *
 * @param {string} shipment_id     - The MMSI or shipment identifier (document ID)
 * @param {Object} data            - Disruption payload from the monitoring agent
 * @param {string} data.severity   - e.g. "HIGH", "CRITICAL"
 * @param {number} data.delay_prediction - Predicted delay in minutes
 *
 * @returns {Promise<void>}
 */
async function updateShipment(shipment_id, data) {
  if (!shipment_id) {
    throw new Error("updateShipment: shipment_id is required");
  }

  const collection = process.env.FIRESTORE_COLLECTION_SHIPMENTS;
  if (!collection) {
    throw new Error("FIRESTORE_COLLECTION_SHIPMENTS env variable is not set");
  }

  const docRef = db.collection(collection).doc(String(shipment_id));

  const payload = {
    status:           "DISRUPTED",
    severity:         data.severity         ?? null,
    delay_prediction: data.delay_prediction ?? null,
    last_updated:     Firestore.FieldValue.serverTimestamp(),
  };

  // merge: true → upsert (preserves any existing fields not in this payload)
  await docRef.set(payload, { merge: true });

  console.log(
    `[Firestore] Shipment ${shipment_id} updated → status=DISRUPTED severity=${payload.severity}`
  );
}

// ── Exports ───────────────────────────────────────────────────────────────────

module.exports = { db, updateShipment };
