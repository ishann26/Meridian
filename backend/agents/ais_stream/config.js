/**
 * config.js — Load and validate all environment variables.
 * Single source of truth for configuration.
 */

"use strict";

const path = require("path");
require("dotenv").config({ path: path.resolve(__dirname, ".env") });

function required(key) {
  const val = process.env[key];
  if (!val) throw new Error(`Missing required env var: ${key}`);
  return val;
}

function optional(key, defaultVal) {
  return process.env[key] ?? defaultVal;
}

const config = {
  // AISStream
  ais: {
    apiKey: required("AIS_API_KEY"),
    apiUrl: optional("AIS_API_URL", "wss://stream.aisstream.io/v0/stream"),
    // Bounding box: [SW, NE] = Indian Ocean + Bay of Bengal + Arabian Sea region
    boundingBoxes: JSON.parse(
      optional("AIS_BOUNDING_BOXES", "[[[5.0,65.0],[35.0,95.0]]]")
    ),
  },

  // Google Cloud
  gcp: {
    projectId: required("GCP_PROJECT_ID"),
  },

  // Pub/Sub
  pubsub: {
    shipmentTopic: required("PUBSUB_SHIPMENT_UPDATES_TOPIC"),
  },

  // Firestore
  firestore: {
    shipmentsCollection: required("FIRESTORE_COLLECTION_SHIPMENTS"),
  },

  // Reconnect behaviour
  reconnect: {
    delayMs: parseInt(optional("RECONNECT_DELAY_MS", "5000"), 10),
    maxAttempts: parseInt(optional("MAX_RECONNECT_ATTEMPTS", "10"), 10),
  },

  // Logging
  logLevel: optional("LOG_LEVEL", "info"),
};

module.exports = config;
