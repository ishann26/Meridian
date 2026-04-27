"use strict";

require("dotenv").config({ path: "../../.env" });
const http = require("http");
const WebSocket = require("ws");
const cors = require("cors");
const { Firestore } = require("@google-cloud/firestore");

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });
const port = process.env.PORT || 3000;

// ── Firestore Setup ──────────────────────────────────────────────────────────

const db = new Firestore({
  projectId: process.env.GCP_PROJECT_ID,
});

const SHIPMENTS_COLLECTION = process.env.FIRESTORE_COLLECTION_SHIPMENTS || "live_shipments";
const EVENTS_COLLECTION = process.env.FIRESTORE_COLLECTION_EVENTS || "disruption_events";

// ── Real-time Updates (Firestore Listener + WebSocket) ───────────────────────

/**
 * Listen for changes in the live_shipments collection.
 * When a document changes, broadcast the update to all connected WS clients.
 */
db.collection(SHIPMENTS_COLLECTION).onSnapshot((snapshot) => {
  snapshot.docChanges().forEach((change) => {
    const shipmentData = {
      id: change.doc.id,
      ...change.doc.data(),
      _update_type: change.type, // 'added', 'modified', or 'removed'
    };

    const message = JSON.stringify({
      type: "SHIPMENT_UPDATE",
      data: shipmentData,
    });

    // Broadcast to all active WebSocket clients
    wss.clients.forEach((client) => {
      if (client.readyState === WebSocket.OPEN) {
        client.send(message);
      }
    });
  });
}, (err) => {
  console.error("[Realtime] Firestore listener error:", err);
});

wss.on("connection", (ws) => {
  console.log("[WS] Client connected");
  ws.send(JSON.stringify({ type: "WELCOME", message: "Meridian Real-time Feed Connected" }));
  
  ws.on("close", () => console.log("[WS] Client disconnected"));
});

// ── Middleware ───────────────────────────────────────────────────────────────

app.use(cors());
app.use(express.json());

// ── Routes ───────────────────────────────────────────────────────────────────

/**
 * GET /shipments
 * List all shipments in the live_shipments collection.
 */
app.get("/shipments", async (req, res) => {
  try {
    const snapshot = await db.collection(SHIPMENTS_COLLECTION).get();
    const shipments = [];
    snapshot.forEach((doc) => {
      shipments.push({ id: doc.id, ...doc.data() });
    });
    res.json(shipments);
  } catch (err) {
    console.error("Error fetching shipments:", err);
    res.status(500).json({ error: "Failed to fetch shipments" });
  }
});

/**
 * GET /shipments/:id
 * Get detailed data for a specific shipment.
 */
app.get("/shipments/:id", async (req, res) => {
  try {
    const doc = await db.collection(SHIPMENTS_COLLECTION).doc(req.params.id).get();
    if (!doc.exists) {
      return res.status(404).json({ error: "Shipment not found" });
    }
    res.json({ id: doc.id, ...doc.data() });
  } catch (err) {
    console.error("Error fetching shipment detail:", err);
    res.status(500).json({ error: "Failed to fetch shipment detail" });
  }
});

/**
 * GET /events
 * List all disruption events.
 */
app.get("/events", async (req, res) => {
  try {
    const snapshot = await db.collection(EVENTS_COLLECTION).orderBy("timestamp", "desc").limit(100).get();
    const events = [];
    snapshot.forEach((doc) => {
      events.push({ id: doc.id, ...doc.data() });
    });
    res.json(events);
  } catch (err) {
    console.error("Error fetching events:", err);
    res.status(500).json({ error: "Failed to fetch events" });
  }
});

// ── Health Check ─────────────────────────────────────────────────────────────

app.get("/health", (req, res) => {
  res.json({ status: "ok", timestamp: new Date().toISOString() });
});

// ── Start ────────────────────────────────────────────────────────────────────

server.listen(port, () => {
  console.log(`[API] Meridian Express API running on port ${port}`);
  console.log(`[API] Shipments collection: ${SHIPMENTS_COLLECTION}`);
  console.log(`[API] Events collection: ${EVENTS_COLLECTION}`);
});
