"""
Meridian Monitoring Agent — Main Entry Point

Starts all three trigger sources:
  1. Pub/Sub event listeners (primary)
  2. Scheduled scan loop (backup safety net)
  3. Firestore state change listener
"""

import asyncio
import logging
import signal
import sys

from .config import settings
from .engine import MonitoringEngine
from .triggers import EventTriggerHandler, ScheduledScanHandler, StateChangeHandler

# ── Logging Setup ───────────────────────────────────────────
logging.basicConfig(
    level=getattr(logging, settings.app.log_level, logging.INFO),
    format="%(asctime)s │ %(levelname)-8s │ %(name)-30s │ %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("meridian.monitor")


async def main():
    """Start the monitoring agent with all trigger sources."""
    logger.info("=" * 60)
    logger.info("  MERIDIAN MONITORING AGENT")
    logger.info("  Environment: %s", settings.app.environment)
    logger.info("  Disruption threshold: %.1f", settings.thresholds.disruption_threshold)
    logger.info("  Weights: time=%.2f route=%.2f risk=%.2f",
                settings.weights.w_time, settings.weights.w_route, settings.weights.w_risk)
    logger.info("=" * 60)

    # Initialize the engine
    engine = MonitoringEngine()

    # Initialize trigger handlers
    event_handler = EventTriggerHandler(engine)
    scan_handler = ScheduledScanHandler(engine)
    state_handler = StateChangeHandler(engine)

    # Graceful shutdown
    shutdown_event = asyncio.Event()

    def _signal_handler(sig, frame):
        logger.info("Received signal %s — shutting down...", sig)
        shutdown_event.set()

    signal.signal(signal.SIGINT, _signal_handler)
    signal.signal(signal.SIGTERM, _signal_handler)

    try:
        # 1. Start Pub/Sub event listeners (background threads)
        logger.info("Starting Pub/Sub event listeners...")
        event_handler.start_listeners()

        # 2. Start Firestore state change listener
        logger.info("Starting Firestore state change listener...")
        state_handler.start_listener()

        # 3. Start scheduled scan loop
        scan_interval = settings.scheduler.interval_minutes * 60
        logger.info("Starting scheduled scan (every %d seconds)...", scan_interval)

        scan_task = asyncio.create_task(
            scan_handler.run_periodic(interval_seconds=scan_interval)
        )

        # Wait for shutdown signal
        logger.info("✅ Monitoring agent is running. Press Ctrl+C to stop.")
        await shutdown_event.wait()

    except Exception as e:
        logger.error("Fatal error: %s", e, exc_info=True)
    finally:
        logger.info("Shutting down monitoring agent...")
        state_handler.stop_listener()
        await engine.close()
        logger.info("Monitoring agent stopped.")


def run():
    """Entry point for command line."""
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Interrupted by user")
        sys.exit(0)


if __name__ == "__main__":
    run()
