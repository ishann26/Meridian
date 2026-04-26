/**
 * publisher.js — Google Cloud Pub/Sub publisher.
 *
 * Responsibilities:
 *  - Initialize Pub/Sub client
 *  - Publish ShipUpdate messages as JSON to the configured topic
 *  - Add message attributes for server-side filtering
 *  - Batch internally (Pub/Sub client handles batching automatically)
 *  - Retry on transient errors
 */

"use strict";

const { PubSub } = require("@google-cloud/pubsub");
const config     = require("./config");
const logger     = require("./logger");

// ── Client (singleton) ────────────────────────────────────────────────────────

const pubsubClient = new PubSub({ projectId: config.gcp.projectId });
const topic        = pubsubClient.topic(config.pubsub.shipmentTopic, {
  // Pub/Sub client-side batching — flush every 10 messages or 100 ms
  batching: {
    maxMessages: 10,
    maxMilliseconds: 100,
  },
});

// ── Validation ────────────────────────────────────────────────────────────────

let _topicVerified = false;

async function verifyTopic() {
  if (_topicVerified) return;
  try {
    const [exists] = await topic.exists();
    if (!exists) {
      logger.warn(
        "[Publisher] Topic '%s' does not exist — attempting to create it.",
        config.pubsub.shipmentTopic
      );
      await topic.create();
      logger.info("[Publisher] Topic created: %s", config.pubsub.shipmentTopic);
    } else {
      logger.info("[Publisher] Topic verified: %s", config.pubsub.shipmentTopic);
    }
    _topicVerified = true;
  } catch (err) {
    logger.error("[Publisher] Could not verify/create topic: %s", err.message);
    throw err;
  }
}

// ── Publish ───────────────────────────────────────────────────────────────────

/**
 * Publish a ShipUpdate object to Pub/Sub.
 *
 * @param {Object} shipUpdate
 * @returns {Promise<string>} messageId
 */
async function publish(shipUpdate) {
  const data = Buffer.from(JSON.stringify(shipUpdate));

  // Message attributes for server-side filtering (all values must be strings)
  const attributes = {
    shipment_id: String(shipUpdate.shipment_id),
    status:      shipUpdate.status ?? "IN_TRANSIT",
    source:      "ais-stream",
  };

  try {
    const messageId = await topic.publishMessage({ data, attributes });
    logger.debug(
      "[Publisher] Published MMSI %s → msg_id=%s",
      shipUpdate.shipment_id, messageId
    );
    return messageId;
  } catch (err) {
    logger.error(
      "[Publisher] Failed to publish MMSI %s: %s",
      shipUpdate.shipment_id, err.message
    );
    throw err;
  }
}

// ── Cleanup ───────────────────────────────────────────────────────────────────

async function flush() {
  try {
    await topic.flush();
    logger.info("[Publisher] Flushed pending messages.");
  } catch (err) {
    logger.warn("[Publisher] Flush error: %s", err.message);
  }
}

module.exports = { verifyTopic, publish, flush };
