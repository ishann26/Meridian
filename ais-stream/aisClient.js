/**
 * aisClient.js — WebSocket connection to AISStream.
 *
 * Responsibilities:
 *  - Connect via WebSocket (ws library)
 *  - Subscribe with API key + bounding boxes on open
 *  - Parse incoming AIS messages
 *  - Extract and normalize ship fields
 *  - Emit normalized ShipUpdate objects via callback
 *  - Auto-reconnect with exponential backoff on close/error
 */

"use strict";

const WebSocket = require("ws");
const config    = require("./config");
const logger    = require("./logger");

// ── Field extraction helpers ──────────────────────────────────────────────────

/**
 * AISStream wraps messages in a MetaData envelope.
 * Different message types store position in different sub-fields.
 *
 * Structure examples:
 *  { MessageType: "PositionReport",   Message: { PositionReport:   { ... } }, MetaData: { ... } }
 *  { MessageType: "StandardClassBCS", Message: { StandardClassBCS: { ... } }, MetaData: { ... } }
 *  { MessageType: "SingleSlotBinaryMessage", ... }
 */
function extractPosition(raw) {
  const meta    = raw.MetaData    ?? {};
  const msgType = raw.MessageType ?? "";
  const msg     = (raw.Message    ?? {})[msgType] ?? {};

  // Latitude & Longitude — prefer MetaData (already decoded), fall back to message body
  const lat = meta.latitude  ?? msg.Latitude  ?? msg.Lat ?? null;
  const lng = meta.longitude ?? msg.Longitude ?? msg.Lon ?? null;

  // MMSI is always in MetaData
  const mmsi = meta.MMSI ?? msg.UserID ?? null;

  // Speed over ground (tenths of knot in raw AIS, already decoded by AISStream)
  const speed = msg.SpeedOverGround ?? msg.Speed ?? meta.speed_over_ground ?? 0;

  // Course over ground
  const heading = msg.CourseOverGround ?? msg.Heading ?? msg.TrueHeading ?? null;

  // Vessel name — only present in some message types
  const vesselName = meta.ShipName
    ?? msg.Name
    ?? msg.VesselName
    ?? null;

  return { mmsi, lat, lng, speed, heading, vesselName, msgType };
}

/**
 * Normalize raw AIS fields into the internal ShipUpdate format
 * that the rest of the system (Pub/Sub, Firestore) expects.
 */
function toShipUpdate({ mmsi, lat, lng, speed, heading, vesselName, msgType }) {
  return {
    shipment_id:      String(mmsi),
    current_location: { lat, lng },
    speed_knots:      speed,
    heading,
    vessel_name:      vesselName,
    message_type:     msgType,
    status:           "IN_TRANSIT",
    timestamp:        new Date().toISOString(),
  };
}

// ── AIS Client class ─────────────────────────────────────────────────────────

class AISClient {
  /**
   * @param {Function} onShipUpdate  - async (shipUpdate) => void
   */
  constructor(onShipUpdate) {
    this._onShipUpdate     = onShipUpdate;
    this._ws               = null;
    this._reconnectAttempt = 0;
    this._reconnectTimer   = null;
    this._stopped          = false;

    // Stats
    this._stats = {
      messagesReceived: 0,
      messagesProcessed: 0,
      errors: 0,
      reconnects: 0,
    };
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /** Start the WebSocket connection. */
  connect() {
    if (this._stopped) return;
    this._openSocket();
  }

  /** Gracefully shut down — no more reconnects. */
  stop() {
    this._stopped = true;
    clearTimeout(this._reconnectTimer);
    if (this._ws) {
      this._ws.removeAllListeners();
      this._ws.terminate();
      this._ws = null;
    }
    logger.info("[AISClient] Stopped.");
  }

  get stats() {
    return { ...this._stats };
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  _openSocket() {
    logger.info("[AISClient] Connecting to %s ...", config.ais.apiUrl);

    const ws = new WebSocket(config.ais.apiUrl);
    this._ws = ws;

    ws.on("open",    () => this._onOpen());
    ws.on("message", (data) => this._onMessage(data));
    ws.on("close",   (code, reason) => this._onClose(code, reason));
    ws.on("error",   (err) => this._onError(err));
  }

  _onOpen() {
    logger.info("[AISClient] Connected. Subscribing...");
    this._reconnectAttempt = 0;

    const subscription = {
      APIKey:       config.ais.apiKey,
      BoundingBoxes: config.ais.boundingBoxes,
    };

    try {
      this._ws.send(JSON.stringify(subscription));
      logger.info(
        "[AISClient] Subscribed with bounding boxes: %j",
        config.ais.boundingBoxes
      );
    } catch (err) {
      logger.error("[AISClient] Failed to send subscription: %s", err.message);
    }
  }

  _onMessage(data) {
    this._stats.messagesReceived++;

    // ── 1. Parse JSON safely ──────────────────────────────────────────────
    let raw;
    try {
      raw = JSON.parse(data.toString());
    } catch {
      logger.warn("[AISClient] Received invalid JSON — ignoring.");
      this._stats.errors++;
      return;
    }

    // ── 2. Validate structure ─────────────────────────────────────────────
    if (!raw || typeof raw !== "object") {
      logger.debug("[AISClient] Non-object message — ignoring.");
      return;
    }

    // Skip non-position messages (e.g., heartbeats, errors from server)
    if (!raw.MessageType || !raw.MetaData) {
      logger.debug("[AISClient] Skipping message without MessageType/MetaData: %j", raw);
      return;
    }

    // ── 3. Extract fields ─────────────────────────────────────────────────
    const fields = extractPosition(raw);

    if (!fields.mmsi) {
      logger.debug("[AISClient] No MMSI in message — skipping.");
      return;
    }

    if (fields.lat === null || fields.lng === null) {
      logger.debug("[AISClient] MMSI %s has no position — skipping.", fields.mmsi);
      return;
    }

    // Basic sanity check on coordinates
    if (
      typeof fields.lat !== "number" || typeof fields.lng !== "number" ||
      fields.lat < -90 || fields.lat > 90 ||
      fields.lng < -180 || fields.lng > 180
    ) {
      logger.warn(
        "[AISClient] MMSI %s has invalid coordinates (%s, %s) — skipping.",
        fields.mmsi, fields.lat, fields.lng
      );
      return;
    }

    // ── 4. Transform & forward ────────────────────────────────────────────
    const shipUpdate = toShipUpdate(fields);
    this._stats.messagesProcessed++;

    logger.debug(
      "[AISClient] MMSI %s | lat=%.4f lng=%.4f speed=%.1f kn type=%s",
      fields.mmsi, fields.lat, fields.lng, fields.speed, fields.msgType
    );

    // Fire and forget — errors handled inside the callback
    this._onShipUpdate(shipUpdate).catch((err) => {
      logger.error("[AISClient] onShipUpdate callback error: %s", err.message);
      this._stats.errors++;
    });
  }

  _onClose(code, reason) {
    logger.warn(
      "[AISClient] Connection closed (code=%d reason=%s).",
      code, reason?.toString() || "none"
    );
    this._scheduleReconnect();
  }

  _onError(err) {
    logger.error("[AISClient] WebSocket error: %s", err.message);
    this._stats.errors++;
    // "error" is always followed by "close", so reconnect is handled there
  }

  _scheduleReconnect() {
    if (this._stopped) return;

    this._reconnectAttempt++;
    const max = config.reconnect.maxAttempts;

    if (this._reconnectAttempt > max) {
      logger.error(
        "[AISClient] Max reconnect attempts (%d) reached. Giving up.",
        max
      );
      process.emit("reconnect-failed");
      return;
    }

    // Exponential backoff: base * 2^attempt, capped at 60 s
    const base  = config.reconnect.delayMs;
    const delay = Math.min(base * Math.pow(2, this._reconnectAttempt - 1), 60_000);

    logger.info(
      "[AISClient] Reconnecting in %d ms (attempt %d/%d)...",
      delay, this._reconnectAttempt, max
    );

    this._stats.reconnects++;
    this._reconnectTimer = setTimeout(() => this._openSocket(), delay);
  }
}

module.exports = AISClient;
