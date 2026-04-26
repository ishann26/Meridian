const WebSocket = require("ws");
require("dotenv").config();

const API_KEY = process.env.AIS_API_KEY || "YOUR_API_KEY";

console.log("Using API Key:", API_KEY === "your-aisstream-api-key" || API_KEY === "YOUR_API_KEY" ? "PLACEHOLDER (Warning)" : "LOADED");

const ws = new WebSocket("wss://stream.aisstream.io/v0/stream");

ws.on("open", () => {
  console.log("Connected ✅");

  ws.send(JSON.stringify({
    APIKey: API_KEY,
    BoundingBoxes: [[[5.0,65.0],[35.0,95.0]]]
  }));
});

ws.on("message", (data) => {
  console.log("DATA RECEIVED 🚢");
  try {
    const parsed = JSON.parse(data);
    console.log(JSON.stringify(parsed, null, 2));
  } catch (e) {
    console.log(data.toString());
  }
  // Close after first message for testing
  // ws.close();
});

ws.on("error", (err) => {
  console.error("Error:", err);
});

ws.on("close", () => {
  console.log("Connection closed.");
});

// Set a timeout to close after 10 seconds so it doesn't run forever in the background
setTimeout(() => {
  console.log("Closing test after 10 seconds...");
  ws.close();
  process.exit(0);
}, 10000);
