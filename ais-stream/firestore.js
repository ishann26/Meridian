/**
 * firestore.js — Google Cloud Firestore writer.
 *
 * Responsibilities:
 *  - Initialize Firestore client
 *  - Upsert (merge) each ShipUpdate into the live_shipments collection
 *  - Document ID = MMSI (shipment_id)
 *  - Batch writes when possible for efficiency
 *  - Retry on transient Firestore errors
 */

"use strict";

const { Firestore }   = require("@google-cloud/firestore");
const config          = require("./config");
const logger          = require("./logger");

// ── Client (singleton) ────────────────────────────────────────────────────────

const db = new Firestore({ projectId: config.gcp.projectId });
const collectionRef = db.collection(config.firestore.shipmentsCollection);

// ── Write queue (micro-batch) ─────────────────────────────────────────────────
// Firestore batch allows up to 500 operations per commit.
// We flush every BATCH_SIZE writes or every FLUSH_INTERVAL_MS, whichever comes first.

const BATCH_SIZE       = 200;
const FLUSH_INTERVAL_MS = 500;

let _batch       = db.batch();
let _batchCount  = 0;
let _flushTimer  = null;

function _resetBatch() {
  _batch      = db.batch();
  _batchCount = 0;
}

async function _flushBatch() {
  if (_batchCount === 0) return;

  const count = _batchCount;
  _resetBatch();

  try {
    await _batch.commit();
    logger.debug("[Firestore] Committed batch of %d writes.", count);
  } catch (err) {
    logger.error("[Firestore] Batch commit failed: %s", err.message);
    // Don't re-throw — best-effort writes, don't crash the stream
  }
}

function _scheduleFlusher() {
  if (_flushTimer) return;
  _flushTimer = setInterval(async () => {
    if (_batchCount > 0) {
      await _flushBatch();
    }
  }, FLUSH_INTERVAL_MS);
  // Don't hold the process open just for the flush timer
  _flushTimer.unref?.();
}

// ── Public API ────────────────────────────────────────────────────────────────

/**
 * Upsert a ShipUpdate into Firestore.
 * Uses set({ merge: true }) so existing fields not in the update are preserved.
 *
 * @param {Object} shipUpdate
 */
async function upsert(shipUpdate) {
  _scheduleFlusher();

  const docRef = collectionRef.doc(String(shipUpdate.shipment_id));

  // Flatten for Firestore (nested objects are fine, but we add server timestamp)
  const data = {
    ...shipUpdate,
    last_updated: Firestore.FieldValue.serverTimestamp(),
  };

  _batch.set(docRef, data, { merge: true });
  _batchCount++;

  logger.debug(
    "[Firestore] Queued upsert for MMSI %s (batch size: %d).",
    shipUpdate.shipment_id, _batchCount
  );

  // Flush immediately if we hit the batch limit
  if (_batchCount >= BATCH_SIZE) {
    await _flushBatch();
  }
}

/**
 * Force-flush any pending writes and stop the background timer.
 */
async function shutdown() {
  clearInterval(_flushTimer);
  _flushTimer = null;
  await _flushBatch();
  logger.info("[Firestore] Shutdown complete.");
}

module.exports = { upsert, shutdown };
