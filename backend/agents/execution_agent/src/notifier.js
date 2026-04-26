/**
 * notifier.js — Firebase Cloud Messaging (FCM) alert sender.
 *
 * Uses topic-based messaging so any device/service subscribed to
 * the "logistics-alerts" topic receives the disruption push notification.
 *
 * Functions:
 *  - sendAlert(event) → Sends an FCM notification to the configured topic
 */

"use strict";

const admin = require("firebase-admin");
const path  = require("path");

// ── Firebase Admin initialisation (singleton) ─────────────────────────────────

let _initialized = false;

function _ensureInitialized() {
  if (_initialized) return;

  const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;

  if (!serviceAccountPath) {
    throw new Error(
      "FIREBASE_SERVICE_ACCOUNT_PATH is not set in environment variables."
    );
  }

  const resolvedPath = path.resolve(serviceAccountPath);

  let serviceAccount;
  try {
    serviceAccount = require(resolvedPath);
  } catch (err) {
    throw new Error(
      `Failed to load Firebase service account from "${resolvedPath}": ${err.message}`
    );
  }

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });

  _initialized = true;
  console.log("[Notifier] Firebase Admin initialized.");
}

// ── Message builder ───────────────────────────────────────────────────────────

/**
 * Build the FCM message payload from a disruption event.
 *
 * @param {Object} event          - DisruptionEvent from the monitoring agent
 * @param {string} event.shipment_id
 * @param {string} event.severity - "LOW" | "MODERATE" | "HIGH" | "CRITICAL"
 * @param {string} event.reason   - e.g. "ROUTE_DEVIATION", "WEATHER_HAZARD"
 * @param {number} [event.deviation_score]
 * @param {Object} [event.predictions]
 * @returns {Object} FCM message object
 */
function _buildMessage(event) {
  const topic     = process.env.FCM_ALERT_TOPIC || "logistics-alerts";
  const score     = event.deviation_score != null
    ? `${event.deviation_score.toFixed(1)}/100`
    : "N/A";
  const delay     = event.predictions?.predicted_delay_minutes != null
    ? `${Math.round(event.predictions.predicted_delay_minutes)} min delay predicted`
    : null;

  const bodyParts = [
    `Shipment ${event.shipment_id}`,
    `Severity: ${event.severity ?? "UNKNOWN"}`,
    `Reason: ${event.reason ?? "UNKNOWN"}`,
    delay,
    `Score: ${score}`,
  ].filter(Boolean);  // drop null/undefined parts

  return {
    topic,

    // Human-readable notification (shown on device lock screen / notification tray)
    notification: {
      title: "🚨 Shipment Disruption Detected",
      body:  bodyParts.join(" | "),
    },

    // Structured data payload for the app to process programmatically
    data: {
      event_type:      "DISRUPTION",
      shipment_id:     String(event.shipment_id  ?? ""),
      severity:        String(event.severity      ?? ""),
      reason:          String(event.reason        ?? ""),
      deviation_score: String(event.deviation_score ?? ""),
      timestamp:       String(event.timestamp     ?? new Date().toISOString()),
    },

    // Android-specific config: high priority so the device wakes immediately
    android: {
      priority: "high",
      notification: {
        sound:       "default",
        channelId:   "shipment-alerts",
        clickAction: "OPEN_SHIPMENT_DETAIL",
      },
    },

    // APNs (iOS) config
    apns: {
      payload: {
        aps: {
          sound: "default",
          badge: 1,
        },
      },
    },
  };
}

// ── sendAlert ─────────────────────────────────────────────────────────────────

/**
 * Send an FCM topic notification for a disruption event.
 *
 * @param {Object} event - DisruptionEvent from the monitoring agent
 * @returns {Promise<string>} FCM message ID
 */
async function sendAlert(event) {
  if (!event || !event.shipment_id) {
    throw new Error("sendAlert: event with shipment_id is required.");
  }

  _ensureInitialized();

  const message = _buildMessage(event);
  const topic   = message.topic;

  try {
    const messageId = await admin.messaging().send(message);
    console.log(
      `[Notifier] Alert sent → topic="${topic}" shipment=${event.shipment_id} ` +
      `severity=${event.severity} msg_id=${messageId}`
    );
    return messageId;
  } catch (err) {
    console.error(
      `[Notifier] Failed to send alert for shipment ${event.shipment_id}: ${err.message}`
    );
    throw err;
  }
}

// ── Exports ───────────────────────────────────────────────────────────────────

module.exports = { sendAlert };
