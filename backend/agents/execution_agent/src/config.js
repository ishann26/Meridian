require('dotenv').config();

module.exports = {
  gcpProjectId: process.env.GCP_PROJECT_ID,
  pubsub: {
    disruptionTopic: process.env.PUBSUB_DISRUPTION_EVENTS_TOPIC,
    disruptionSub: process.env.PUBSUB_DISRUPTION_EVENTS_SUB,
  },
  firestore: {
    eventsCollection: process.env.FIRESTORE_COLLECTION_EVENTS,
    shipmentsCollection: process.env.FIRESTORE_COLLECTION_SHIPMENTS,
  }
};
