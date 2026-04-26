"""
BigQuery Service — Fetches planned shipment state.

Reads from BigQuery tables to get the planned departure/arrival times
and the expected route waypoints for each shipment.
"""

import logging
from datetime import datetime
from typing import List, Optional

from google.cloud import bigquery

from ..config import settings
from ..models import GeoPoint, PlannedState

logger = logging.getLogger(__name__)


class BigQueryService:
    """Connects to BigQuery to fetch planned shipment data."""

    def __init__(self):
        self._client: Optional[bigquery.Client] = None

    @property
    def client(self) -> bigquery.Client:
        if self._client is None:
            self._client = bigquery.Client(project=settings.gcp.project_id)
            logger.info("BigQuery client initialized for project: %s", settings.gcp.project_id)
        return self._client

    def get_planned_state(self, shipment_id: str) -> Optional[PlannedState]:
        """Fetch the planned state for a single shipment."""
        query = f"""
            SELECT
                s.shipment_id,
                s.planned_departure_time,
                s.planned_arrival_time,
                s.carrier,
                s.flight_number,
                s.origin_lat, s.origin_lng,
                s.destination_lat, s.destination_lng
            FROM `{settings.bigquery.shipments_full_table}` s
            WHERE s.shipment_id = @shipment_id
            LIMIT 1
        """
        job_config = bigquery.QueryJobConfig(
            query_parameters=[
                bigquery.ScalarQueryParameter("shipment_id", "STRING", shipment_id)
            ]
        )

        try:
            results = self.client.query(query, job_config=job_config).result()
            row = next(iter(results), None)
            if row is None:
                logger.warning("No planned state found for shipment: %s", shipment_id)
                return None

            # Fetch route waypoints
            route = self._get_planned_route(shipment_id)

            return PlannedState(
                shipment_id=row.shipment_id,
                planned_departure_time=row.planned_departure_time,
                planned_arrival_time=row.planned_arrival_time,
                planned_route=route,
                carrier=row.carrier,
                flight_number=getattr(row, "flight_number", None),
                origin=GeoPoint(lat=row.origin_lat, lng=row.origin_lng),
                destination=GeoPoint(lat=row.destination_lat, lng=row.destination_lng),
            )
        except Exception as e:
            logger.error("BigQuery fetch failed for shipment %s: %s", shipment_id, e)
            raise

    def _get_planned_route(self, shipment_id: str) -> List[GeoPoint]:
        """Fetch the planned route waypoints for a shipment."""
        query = f"""
            SELECT lat, lng, waypoint_order
            FROM `{settings.bigquery.routes_full_table}`
            WHERE shipment_id = @shipment_id
            ORDER BY waypoint_order ASC
        """
        job_config = bigquery.QueryJobConfig(
            query_parameters=[
                bigquery.ScalarQueryParameter("shipment_id", "STRING", shipment_id)
            ]
        )

        try:
            results = self.client.query(query, job_config=job_config).result()
            return [GeoPoint(lat=row.lat, lng=row.lng) for row in results]
        except Exception as e:
            logger.error("Failed to fetch route for shipment %s: %s", shipment_id, e)
            return []

    def get_all_active_shipment_ids(self) -> List[str]:
        """
        Fetch all shipment IDs that are currently active
        (not COMPLETED or CANCELLED). Used by the scheduled scan.
        """
        query = f"""
            SELECT DISTINCT s.shipment_id
            FROM `{settings.bigquery.shipments_full_table}` s
            WHERE s.planned_arrival_time > CURRENT_TIMESTAMP()
              AND s.shipment_id NOT IN (
                  SELECT shipment_id FROM `{settings.bigquery.shipments_full_table}`
                  WHERE status IN ('COMPLETED', 'CANCELLED')
              )
        """
        try:
            results = self.client.query(query).result()
            ids = [row.shipment_id for row in results]
            logger.info("Found %d active shipments for scan", len(ids))
            return ids
        except Exception as e:
            logger.error("Failed to fetch active shipment IDs: %s", e)
            return []
