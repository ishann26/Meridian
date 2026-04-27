"""
Pub/Sub Service — Event-based trigger ingestion & disruption event publishing.

Handles:
  - Subscribing to shipment updates, flight status, weather alerts
  - Publishing structured disruption events for downstream consumers
"""

import json
import logging
from concurrent.futures import TimeoutError as FuturesTimeoutError
from typing import Any, Callable, Dict, Optional

from google.cloud import pubsub_v1
from google.api_core import retry as api_retry

from ..config import settings
from ..models import DisruptionEvent

logger = logging.getLogger(__name__)


class PubSubService:
    """Cloud Pub/Sub connector for event-driven monitoring triggers."""

    def __init__(self):
        self._publisher: Optional[pubsub_v1.PublisherClient] = None
        self._subscriber: Optional[pubsub_v1.SubscriberClient] = None

    # ── Clients (lazy init) ─────────────────────────────────

    @property
    def publisher(self) -> pubsub_v1.PublisherClient:
        if self._publisher is None:
            # Custom retry for transient errors
            custom_retry = api_retry.Retry(
                initial=0.2,  # seconds
                maximum=60.0,
                multiplier=2.0,
                deadline=120.0,
            )
            self._publisher = pubsub_v1.PublisherClient()
            logger.info("Pub/Sub publisher client initialized (with retry)")
        return self._publisher

    @property
    def subscriber(self) -> pubsub_v1.SubscriberClient:
        if self._subscriber is None:
            self._subscriber = pubsub_v1.SubscriberClient()
            logger.info("Pub/Sub subscriber client initialized")
        return self._subscriber

    # ── Topic / Subscription Paths ──────────────────────────

    def _topic_path(self, topic_name: str) -> str:
        return self.publisher.topic_path(settings.gcp.project_id, topic_name)

    def _subscription_path(self, subscription_name: str) -> str:
        return self.subscriber.subscription_path(settings.gcp.project_id, subscription_name)

    # ── Publish Disruption Event ────────────────────────────

    def publish_disruption_event(self, event: DisruptionEvent) -> str:
        """
        Publish a disruption event to the disruption topic.
        Returns the published message ID.
        """
        topic = self._topic_path(settings.pubsub.disruption_topic)
        payload = json.dumps(event.to_dict()).encode("utf-8")

        try:
            # Reusable retry config
            custom_retry = api_retry.Retry(
                initial=0.2, maximum=60.0, multiplier=2.0, deadline=120.0
            )

            future = self.publisher.publish(
                topic,
                data=payload,
                shipment_id=event.shipment_id,
                severity=event.severity.value,
                event_type=event.type,
                event_id=str(event.event_id),
                timestamp=event.timestamp.isoformat() + "Z",
                retry=custom_retry
            )
            message_id = future.result(timeout=30)
            logger.info(
                "Published disruption event %s (msg: %s) for shipment %s",
                event.event_id, message_id, event.shipment_id,
            )
            return message_id

        except Exception as e:
            logger.error("Failed to publish disruption event %s: %s", event.event_id, e)
            raise

    # ── Subscribe to Event Streams ──────────────────────────

    def subscribe_shipment_updates(
        self,
        callback: Callable[[Dict[str, Any]], None],
        timeout: Optional[float] = None,
    ) -> None:
        """Subscribe to shipment update events."""
        self._subscribe(
            subscription=settings.pubsub.subscription_shipment,
            callback=callback,
            label="shipment-updates",
            timeout=timeout,
        )

    def subscribe_flight_status(
        self,
        callback: Callable[[Dict[str, Any]], None],
        timeout: Optional[float] = None,
    ) -> None:
        """Subscribe to flight status change events."""
        self._subscribe(
            subscription=settings.pubsub.subscription_flight,
            callback=callback,
            label="flight-status",
            timeout=timeout,
        )

    def subscribe_weather_alerts(
        self,
        callback: Callable[[Dict[str, Any]], None],
        timeout: Optional[float] = None,
    ) -> None:
        """Subscribe to weather alert events."""
        self._subscribe(
            subscription=settings.pubsub.subscription_weather,
            callback=callback,
            label="weather-alerts",
            timeout=timeout,
        )

    def _subscribe(
        self,
        subscription: str,
        callback: Callable[[Dict[str, Any]], None],
        label: str,
        timeout: Optional[float] = None,
    ) -> None:
        """
        Internal subscription handler. Wraps raw Pub/Sub messages
        into parsed JSON dicts before passing to the callback.
        """
        sub_path = self._subscription_path(subscription)

        def _message_handler(message):
            try:
                data = json.loads(message.data.decode("utf-8"))
                # Add message attributes to the data
                data["_attributes"] = dict(message.attributes) if message.attributes else {}
                data["_message_id"] = message.message_id

                logger.debug("[%s] Received message %s: %s", label, message.message_id, data)
                callback(data)
                message.ack()

            except json.JSONDecodeError as e:
                logger.error("[%s] Invalid JSON in message %s: %s", label, message.message_id, e)
                message.nack()  # Retry later
            except Exception as e:
                logger.error("[%s] Error processing message %s: %s", label, message.message_id, e)
                message.nack()

        streaming_pull_future = self.subscriber.subscribe(sub_path, callback=_message_handler)
        logger.info("Listening on [%s] subscription: %s", label, sub_path)

        try:
            streaming_pull_future.result(timeout=timeout)
        except FuturesTimeoutError:
            logger.info("[%s] Subscription timed out after %s seconds", label, timeout)
            streaming_pull_future.cancel()
            streaming_pull_future.result()  # Wait for cancellation
        except Exception as e:
            logger.error("[%s] Subscription error: %s", label, e)
            streaming_pull_future.cancel()
            raise

    # ── Cleanup ─────────────────────────────────────────────

    def close(self) -> None:
        """Clean up Pub/Sub clients."""
        if self._publisher:
            self._publisher.transport.close()
        if self._subscriber:
            self._subscriber.close()
        logger.info("Pub/Sub clients closed")
