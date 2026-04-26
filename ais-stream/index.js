/**
 * index.js — Meridian AIS Stream Service Orchestrator
 *
 * Wires together:
 *   AISClient (WebSocket) → publisher (Pub/Sub) + firestore (Firestore)
 *
 * Flow:
 *   1. Verify Pub/Sub topic exists
 *   2. Open AISStream WebSocket
 *   3. For every valid ShipUpdate:
 *      a. Publish to Pub/Sub  (triggers monitoring agent)
 *      b. Upsert to Firestore (live state store)
 *   4. Graceful shutdown on SIGINT / SIGTERM
 */

"use strict";

const config    = require("./config");
const logger    = require("./logger");
const AISClient = require("./aisClient");
const publisher = require("./publisher");
const firestore = require("./firestore");

// ── Stats tracking ────────────────────────────────────────────────────────────

let totalProcessed  = 0;
let totalPubSubOk   = 0;
let totalFirestoreOk = 0;
let totalErrors     = 0;

// ── Main handler (called for every valid AIS message) ─────────────────────────

/**
 * Process a single ShipUpdate:
 *   - Publish to Pub/Sub (non-blocking, retried internally)
 *   - Upsert to Firestore (batched, non-blocking)
 *
 * Both operations run in parallel. Failures are logged but don't
 * crash the stream — reliability > loss of one update.
 *
 * @param {Object} shipUpdate
 */
async function handleShipUpdate(shipUpdate) {
  totalProcessed++;

  const [pubResult, fsResult] = await Promise.allSettled([
    publisher.publish(shipUpdate),
    firestore.upsert(shipUpdate),
  ]);

  if (pubResult.status === "fulfilled") {
    totalPubSubOk++;
  } else {
    totalErrors++;
    logger.error(
      "[Index] Pub/Sub failed for MMSI %s: %s",
      shipUpdate.shipment_id, pubResult.reason?.message
    );
  }

  if (fsResult.status === "fulfilled") {
    totalFirestoreOk++;
  } else {
    totalErrors++;
    logger.error(
      "[Index] Firestore failed for MMSI %s: %s",
      shipUpdate.shipment_id, fsResult.reason?.message
    );
  }
}

// ── Startup ───────────────────────────────────────────────────────────────────

async function main() {
  logger.info("============================================================");
  logger.info("  MERIDIAN AIS STREAM SERVICE");
  logger.info("  Project:   %s", config.gcp.projectId);
  logger.info("  Topic:     %s", config.pubsub.shipmentTopic);
  logger.info("  Firestore: %s", config.firestore.shipmentsCollection);
  logger.info("  AIS URL:   %s", config.ais.apiUrl);
  logger.info("============================================================");

  // 1. Verify Pub/Sub topic before opening the socket
  try {
    await publisher.verifyTopic();
  } catch (err) {
    logger.error("[Index] Pub/Sub setup failed — aborting: %s", err.message);
    process.exit(1);
  }

  // 2. Create AIS client
  const aisClient = new AISClient(handleShipUpdate);

  // 3. Handle max reconnect failure
  process.once("reconnect-failed", async () => {
    logger.error("[Index] AIS client gave up reconnecting. Shutting down.");
    await gracefulShutdown(aisClient);
    process.exit(1);
  });

  // 4. Periodic stats logging every 60 s
  const statsInterval = setInterval(() => {
    const aisStats = aisClient.stats;
    logger.info(
      "[Stats] processed=%d pubsub_ok=%d firestore_ok=%d errors=%d | " +
      "ais_received=%d reconnects=%d",
      totalProcessed, totalPubSubOk, totalFirestoreOk, totalErrors,
      aisStats.messagesReceived, aisStats.reconnects
    );
  }, 60_000);
  statsInterval.unref?.();

  // 5. Connect
  aisClient.connect();
  logger.info("[Index] AIS client started. Streaming...");

  // 6. Graceful shutdown handlers
  const shutdown = async (signal) => {
    logger.info("[Index] Received %s — shutting down gracefully...", signal);
    clearInterval(statsInterval);
    await gracefulShutdown(aisClient);
    process.exit(0);
  };

  process.once("SIGINT",  () => shutdown("SIGINT"));
  process.once("SIGTERM", () => shutdown("SIGTERM"));

  // 7. Catch any unhandled promise rejections
  process.on("unhandledRejection", (reason) => {
    logger.error("[Index] Unhandled rejection: %s", reason?.message ?? reason);
    totalErrors++;
  });
}

// ── Graceful shutdown ────────────────────────────────────────────────────────

async function gracefulShutdown(aisClient) {
  logger.info("[Index] Stopping AIS WebSocket...");
  aisClient.stop();

  logger.info("[Index] Flushing Pub/Sub...");
  await publisher.flush();

  logger.info("[Index] Flushing Firestore batch...");
  await firestore.shutdown();

  logger.info("[Index] Final stats: processed=%d errors=%d", totalProcessed, totalErrors);
  logger.info("[Index] Shutdown complete.");
}

// ── Run ───────────────────────────────────────────────────────────────────────

main().catch((err) => {
  logger.error("[Index] Fatal startup error: %s", err.message);
  logger.error(err.stack);
  process.exit(1);
});
