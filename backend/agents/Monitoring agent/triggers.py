"""
Trigger Handlers — Three trigger sources for the Monitoring Agent.

1. Event-based (Pub/Sub) — Primary: shipment updates, flight status, weather alerts
2. Scheduled Scan (Cloud Scheduler) — Backup safety net every 5-10 minutes
3. State Change Listener (Firestore triggers via Cloud Functions)
"""

import asyncio
import json
import logging
from typing import Any, Dict

from .engine import MonitoringEngine
from .models import TriggerSource

logger = logging.getLogger(__name__)


# ════════════════════════════════════════════════════════════
#  1. EVENT-BASED TRIGGERS (Pub/Sub)
# ════════════════════════════════════════════════════════════

class EventTriggerHandler:
    """
    Primary trigger — listens to Pub/Sub topics for:
      - Shipment updates
      - Flight status changes
      - Weather alerts
    """

    def __init__(self, engine: MonitoringEngine):
        self.engine = engine
        self._loop = asyncio.get_event_loop()

    def start_listeners(self):
        """Start all Pub/Sub subscription listeners in background threads."""
        import threading

        threads = [
            threading.Thread(
                target=self.engine.pubsub.subscribe_shipment_updates,
                args=(self._on_shipment_update,),
                daemon=True,
                name="pubsub-shipment",
            ),
            threading.Thread(
                target=self.engine.pubsub.subscribe_flight_status,
                args=(self._on_flight_status,),
                daemon=True,
                name="pubsub-flight",
            ),
            threading.Thread(
                target=self.engine.pubsub.subscribe_weather_alerts,
                args=(self._on_weather_alert,),
                daemon=True,
                name="pubsub-weather",
            ),
        ]

        for t in threads:
            t.start()
            logger.info("Started listener thread: %s", t.name)

        return threads

    def _on_shipment_update(self, data: Dict[str, Any]):
        """Handle incoming shipment update event."""
        shipment_id = data.get("shipment_id")
        if not shipment_id:
            logger.warning("Shipment update missing shipment_id: %s", data)
            return

        logger.info("Shipment update trigger for: %s", shipment_id)
        future = asyncio.run_coroutine_threadsafe(
            self.engine.evaluate_shipment(shipment_id, TriggerSource.PUBSUB_SHIPMENT),
            self._loop,
        )
        try:
            result = future.result(timeout=60)
            if result:
                logger.info("Disruption emitted for %s from shipment update", shipment_id)
        except Exception as e:
            logger.error("Shipment update evaluation failed for %s: %s", shipment_id, e)

    def _on_flight_status(self, data: Dict[str, Any]):
        """Handle incoming flight status change event."""
        flight_number = data.get("flight_number") or data.get("flight_iata")
        shipment_id = data.get("shipment_id")

        if not shipment_id:
            logger.warning("Flight status event missing shipment_id: %s", data)
            return

        logger.info("Flight status trigger for: %s (flight: %s)", shipment_id, flight_number)
        future = asyncio.run_coroutine_threadsafe(
            self.engine.evaluate_shipment(shipment_id, TriggerSource.PUBSUB_FLIGHT),
            self._loop,
        )
        try:
            future.result(timeout=60)
        except Exception as e:
            logger.error("Flight status evaluation failed for %s: %s", shipment_id, e)

    def _on_weather_alert(self, data: Dict[str, Any]):
        """
        Handle incoming weather alert.
        Weather alerts may affect multiple shipments in a region —
        trigger evaluation for all affected shipments.
        """
        affected_ids = data.get("affected_shipment_ids", [])
        region = data.get("region", "unknown")

        if not affected_ids:
            logger.info("Weather alert for region %s — no affected shipments listed", region)
            return

        logger.info("Weather alert for region %s — %d shipments affected", region, len(affected_ids))
        for sid in affected_ids:
            future = asyncio.run_coroutine_threadsafe(
                self.engine.evaluate_shipment(sid, TriggerSource.PUBSUB_WEATHER),
                self._loop,
            )
            try:
                future.result(timeout=60)
            except Exception as e:
                logger.error("Weather alert evaluation failed for %s: %s", sid, e)


# ════════════════════════════════════════════════════════════
#  2. SCHEDULED SCAN TRIGGER (Cloud Scheduler)
# ════════════════════════════════════════════════════════════

class ScheduledScanHandler:
    """
    Backup safety net — runs every 5-10 minutes to catch missed anomalies.
    Can be invoked by Cloud Scheduler via HTTP or Pub/Sub.
    """

    def __init__(self, engine: MonitoringEngine):
        self.engine = engine

    async def run_scan(self) -> Dict[str, Any]:
        """
        Execute a full scan of all active shipments.
        Returns a summary of findings.
        """
        logger.info("⏰ Scheduled scan triggered")

        events = await self.engine.evaluate_all_active(
            trigger=TriggerSource.SCHEDULED_SCAN
        )

        summary = {
            "trigger": "SCHEDULED_SCAN",
            "disruptions_found": len(events),
            "disruption_ids": [e.event_id for e in events],
            "shipments_affected": [e.shipment_id for e in events],
            "severities": {
                s.value: sum(1 for e in events if e.severity == s)
                for s in set(e.severity for e in events)
            } if events else {},
        }

        logger.info("⏰ Scheduled scan complete: %s", json.dumps(summary, indent=2))
        return summary

    async def run_periodic(self, interval_seconds: int = 300):
        """Run the scan periodically (for local development)."""
        logger.info("Starting periodic scan every %d seconds", interval_seconds)
        while True:
            try:
                await self.run_scan()
            except Exception as e:
                logger.error("Periodic scan failed: %s", e)
            await asyncio.sleep(interval_seconds)


# ════════════════════════════════════════════════════════════
#  3. STATE CHANGE LISTENER (Firestore Triggers)
# ════════════════════════════════════════════════════════════

class StateChangeHandler:
    """
    Firestore state change listener.

    In production, this runs as a Cloud Function triggered by Firestore
    document writes. For local development, it uses Firestore watch.
    """

    def __init__(self, engine: MonitoringEngine):
        self.engine = engine
        self._watch = None

    def start_listener(self):
        """Start listening for Firestore document changes (local dev)."""
        from google.cloud import firestore

        collection = self.engine.firestore.client.collection(
            "live_shipments"
        )

        def _on_snapshot(doc_snapshot, changes, read_time):
            for change in changes:
                if change.type.name in ("ADDED", "MODIFIED"):
                    shipment_id = change.document.id
                    logger.info(
                        "Firestore state change detected for: %s (type: %s)",
                        shipment_id, change.type.name,
                    )
                    # Run evaluation in the event loop
                    try:
                        loop = asyncio.get_event_loop()
                        asyncio.run_coroutine_threadsafe(
                            self.engine.evaluate_shipment(
                                shipment_id, TriggerSource.FIRESTORE_STATE_CHANGE
                            ),
                            loop,
                        )
                    except Exception as e:
                        logger.error("Firestore trigger eval failed for %s: %s", shipment_id, e)

        self._watch = collection.on_snapshot(_on_snapshot)
        logger.info("Firestore state change listener started")
        return self._watch

    def stop_listener(self):
        """Stop the Firestore listener."""
        if self._watch:
            self._watch.unsubscribe()
            logger.info("Firestore state change listener stopped")


# ════════════════════════════════════════════════════════════
#  Cloud Function Entry Points
# ════════════════════════════════════════════════════════════

def cloud_function_firestore_trigger(event, context):
    """
    Cloud Function entry point for Firestore triggers.
    Deploy with: gcloud functions deploy monitoring_firestore_trigger \
        --trigger-event providers/cloud.firestore/eventTypes/document.update \
        --trigger-resource "projects/{project}/databases/(default)/documents/live_shipments/{shipmentId}"
    """
    shipment_id = context.resource.split("/")[-1]
    logger.info("Cloud Function: Firestore trigger for %s", shipment_id)

    engine = MonitoringEngine()
    loop = asyncio.new_event_loop()
    try:
        result = loop.run_until_complete(
            engine.evaluate_shipment(shipment_id, TriggerSource.FIRESTORE_STATE_CHANGE)
        )
        return {"status": "ok", "disruption": result is not None}
    finally:
        loop.run_until_complete(engine.close())
        loop.close()


def cloud_function_scheduled_scan(request):
    """
    Cloud Function entry point for Cloud Scheduler.
    Deploy as an HTTP-triggered function called by Cloud Scheduler.
    """
    logger.info("Cloud Function: Scheduled scan triggered")

    engine = MonitoringEngine()
    handler = ScheduledScanHandler(engine)
    loop = asyncio.new_event_loop()
    try:
        summary = loop.run_until_complete(handler.run_scan())
        return json.dumps(summary), 200
    finally:
        loop.run_until_complete(engine.close())
        loop.close()
