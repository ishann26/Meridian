/**
 * subscriber.js — Pub/Sub subscriber for the Execution Agent.
 *
 * Connects to Google Cloud Pub/Sub, pulls messages from the disruption
 * events subscription, parses JSON, and delegates to processEvent().
 *
 * Design note: processEvent is passed as a callback to avoid a circular
 * dependency (index.js defines processEvent and owns the wiring).
 */

"use strict";

const { PubSub } = require("@google-cloud/pubsub");
const config     = require("./config");

// ── Process-level safety net ──────────────────────────────────────────────────
// Prevents unhandled rejections from crashing the process.
process.on("unhandledRejection", (reason) => {
  console.error("[Subscriber] Unhandled rejection:", reason?.message ?? reason);
});

// ── Pub/Sub client (singleton) ────────────────────────────────────────────────

const pubsub = new PubSub({ projectId: config.gcpProjectId });

// ── Stats ─────────────────────────────────────────────────────────────────────

const stats = {
  received:  0,
  processed: 0,
  acked:     0,
  nacked:    0,
  errors:    0,
};

// ── startListening ────────────────────────────────────────────────────────────

/**
 * Open the Pub/Sub subscription and start streaming messages.
 *
 * The subscription is derived from PUBSUB_DISRUPTION_EVENTS_SUB (env).
 * Messages are parsed, handed off to processEvent(), then acked/nacked.
 *
 * @param {Function} processEvent  - async (event: Object) => any
 * @returns {import('@google-cloud/pubsub').Subscription}
 */
function startListening(processEvent) {
  const topicName = process.env.PUBSUB_DISRUPTION_EVENTS_TOPIC;
  const subName   = config.pubsub.disruptionSub;

  if (!topicName) throw new Error("PUBSUB_DISRUPTION_EVENTS_TOPIC is not set.");
  if (!subName)   throw new Error("PUBSUB_DISRUPTION_EVENTS_SUB is not set.");

  const subscription = pubsub.subscription(subName);

  console.log(
    `[Subscriber] Listening on subscription "${subName}" ` +
    `(topic: "${topicName}")`
  );

  // ── Message handler ─────────────────────────────────────────────────────────
  subscription.on("message", async (message) => {
    stats.received++;
    const msgId = message.id;

    // 1. Parse JSON safely
    let event;
    try {
      event = JSON.parse(message.data.toString("utf8"));
    } catch (parseErr) {
      stats.errors++;
      console.error(
        `[Subscriber] msg_id=${msgId} — Invalid JSON, nacking: ${parseErr.message}`
      );
      message.nack();
      stats.nacked++;
      return;
    }

    // 2. Basic validation
    if (!event || typeof event !== "object" || !event.shipment_id) {
      stats.errors++;
      console.warn(
        `[Subscriber] msg_id=${msgId} — Missing shipment_id, nacking.`
      );
      message.nack();
      stats.nacked++;
      return;
    }

    console.log(
      `[Subscriber] msg_id=${msgId} received → ` +
      `shipment=${event.shipment_id} severity=${event.severity ?? "?"}`
    );

    // 3. Delegate to processEvent
    try {
      const result = await processEvent(event);
      stats.processed++;

      console.log(
        `[Subscriber] msg_id=${msgId} processed → ` +
        `actions=[${result?.actions_taken?.join(", ") ?? "none"}]`
      );

      // 4. Ack only after successful processing
      message.ack();
      stats.acked++;
    } catch (processingErr) {
      stats.errors++;
      console.error(
        `[Subscriber] msg_id=${msgId} processing failed — nacking: ${processingErr.message}`
      );
      // Nack so Pub/Sub redelivers (up to subscription retry policy)
      message.nack();
      stats.nacked++;
    }
  });

  // ── Error handler ───────────────────────────────────────────────────────────
  subscription.on("error", (err) => {
    stats.errors++;
    console.error(`[Subscriber] Subscription error: ${err.message}`);
    // Non-fatal — Pub/Sub client auto-reconnects
  });

  // ── Close handler ────────────────────────────────────────────────────────────
  subscription.on("close", () => {
    console.warn("[Subscriber] Subscription stream closed.");
  });

  return subscription;
}

// ── Exports ───────────────────────────────────────────────────────────────────

module.exports = { startListening, stats };
