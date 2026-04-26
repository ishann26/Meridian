"""
Firestore Service — Live state reads/writes + disruption event storage.

Handles:
  - Reading real-time shipment locations (LiveState)
  - Writing disruption events for downstream consumers
  - Listing all active shipments in Firestore
"""

import logging
from datetime import datetime
from typing import Any, Dict, List, Optional

from google.cloud import firestore

from ..config import settings
from ..models import (
    DisruptionEvent,
    GeoPoint,
    LiveState,
    ShipmentStatus,
)

logger = logging.getLogger(__name__)


class FirestoreService:
    """Connects to Cloud Firestore for live state and event storage."""

    def __init__(self):
        self._client: Optional[firestore.Client] = None

    @property
    def client(self) -> firestore.Client:
        if self._client is None:
            self._client = firestore.Client(project=settings.gcp.project_id)
            logger.info("Firestore client initialized for project: %s", settings.gcp.project_id)
        return self._client

    # ── Read Live State ─────────────────────────────────────

    def get_live_state(self, shipment_id: str) -> Optional[LiveState]:
        """Fetch real-time shipment state from Firestore."""
        try:
            doc_ref = (
                self.client
                .collection(settings.firestore.shipments_collection)
                .document(shipment_id)
            )
            doc = doc_ref.get()

            if not doc.exists:
                logger.warning("No live state found for shipment: %s", shipment_id)
                return None

            data = doc.to_dict()
            return self._parse_live_state(shipment_id, data)

        except Exception as e:
            logger.error("Firestore read failed for shipment %s: %s", shipment_id, e)
            raise

    def get_all_live_states(self) -> List[LiveState]:
        """Fetch all live shipment states (used by scheduled scan)."""
        try:
            docs = (
                self.client
                .collection(settings.firestore.shipments_collection)
                .where("status", "not-in", ["COMPLETED", "CANCELLED"])
                .stream()
            )
            states = []
            for doc in docs:
                data = doc.to_dict()
                state = self._parse_live_state(doc.id, data)
                if state:
                    states.append(state)

            logger.info("Fetched %d active live states from Firestore", len(states))
            return states

        except Exception as e:
            logger.error("Failed to fetch all live states: %s", e)
            return []

    # ── Write Disruption Events ─────────────────────────────

    def store_disruption_event(self, event: DisruptionEvent) -> str:
        """Persist a disruption event to Firestore for audit trail."""
        try:
            doc_ref = (
                self.client
                .collection(settings.firestore.events_collection)
                .document(event.event_id)
            )
            doc_ref.set(event.to_dict())
            logger.info(
                "Stored disruption event %s for shipment %s (severity: %s)",
                event.event_id, event.shipment_id, event.severity.value,
            )
            return event.event_id

        except Exception as e:
            logger.error("Failed to store disruption event %s: %s", event.event_id, e)
            raise

    def update_shipment_status(self, shipment_id: str, status: ShipmentStatus) -> None:
        """Update the live shipment status in Firestore."""
        try:
            doc_ref = (
                self.client
                .collection(settings.firestore.shipments_collection)
                .document(shipment_id)
            )
            doc_ref.update({
                "status": status.value,
                "last_updated": datetime.utcnow().isoformat(),
            })
            logger.info("Updated shipment %s status to %s", shipment_id, status.value)

        except Exception as e:
            logger.error("Failed to update status for shipment %s: %s", shipment_id, e)

    # ── Helpers ─────────────────────────────────────────────

    @staticmethod
    def _parse_live_state(shipment_id: str, data: Dict[str, Any]) -> Optional[LiveState]:
        """Parse a Firestore document into a LiveState object."""
        try:
            location_data = data.get("current_location", {})
            return LiveState(
                shipment_id=shipment_id,
                current_location=GeoPoint(
                    lat=float(location_data.get("lat", 0)),
                    lng=float(location_data.get("lng", 0)),
                ),
                current_time=_parse_datetime(data.get("current_time")),
                status=ShipmentStatus(data.get("status", "PENDING")),
                speed_kmh=data.get("speed_kmh"),
                heading=data.get("heading"),
                last_updated=_parse_datetime(data.get("last_updated")),
            )
        except Exception as e:
            logger.error("Failed to parse live state for %s: %s", shipment_id, e)
            return None


def _parse_datetime(value) -> datetime:
    """Safely parse a datetime from Firestore (could be string or datetime)."""
    if value is None:
        return datetime.utcnow()
    if isinstance(value, datetime):
        return value
    if isinstance(value, str):
        # Handle ISO format with or without timezone
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    return datetime.utcnow()
