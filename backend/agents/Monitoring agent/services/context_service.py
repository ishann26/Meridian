"""
Context Service — External API integrations for environmental data.

Fetches weather risk, traffic congestion, flight delay, and live ship tracking data.
"""

import logging
from typing import Optional
import httpx

from ..config import settings
from ..models import ContextData, GeoPoint

logger = logging.getLogger(__name__)
_API_TIMEOUT = 15.0  # Increased for external API reliability


def _log_api_status():
    """Log which APIs are configured on startup."""
    apis = {
        "Weather (OpenWeatherMap)": settings.weather_api.api_key,
        "Flight (AviationStack)": settings.flight_api.api_key,
        "Ship Tracking (MarineTraffic)": settings.ship_tracking_api.api_key,
    }
    for name, key in apis.items():
        status = "✅ configured" if key and not key.startswith("your-") else "⚠️  not set"
        logger.info("  %s: %s", name, status)


class ContextService:
    """Aggregates context data from external APIs."""

    def __init__(self):
        self._http: Optional[httpx.AsyncClient] = None
        _log_api_status()

    @property
    def http(self) -> httpx.AsyncClient:
        if self._http is None or self._http.is_closed:
            self._http = httpx.AsyncClient(timeout=_API_TIMEOUT)
        return self._http

    async def get_context(
        self,
        location: GeoPoint,
        flight_number: Optional[str] = None,
        ship_imo: Optional[str] = None,
    ) -> ContextData:
        weather_risk, flight_delay = 0.0, 0.0
        visibility, wind_speed, temperature = None, None, None
        ship_data = {}

        try:
            w = await self._fetch_weather(location)
            weather_risk = w.get("risk_score", 0.0)
            visibility = w.get("visibility_km")
            wind_speed = w.get("wind_speed_kmh")
            temperature = w.get("temperature_c")
        except Exception as e:
            logger.warning("Weather API failed: %s", e)

        if flight_number:
            try:
                flight_delay = await self._fetch_flight_delay(flight_number)
            except Exception as e:
                logger.warning("Flight API failed: %s", e)

        if ship_imo:
            try:
                ship_data = await self._fetch_ship_position(ship_imo)
            except Exception as e:
                logger.warning("Ship tracking API failed: %s", e)

        return ContextData(
            weather_risk_score=weather_risk,
            flight_delay_minutes=flight_delay,
            visibility_km=visibility,
            wind_speed_kmh=wind_speed,
            temperature_c=temperature,
            ship_speed_knots=ship_data.get("speed"),
            ship_status=ship_data.get("status"),
            ship_heading=ship_data.get("heading"),
            ship_vessel_name=ship_data.get("vessel_name"),
            ship_mmsi=ship_data.get("mmsi"),
        )

    async def _fetch_weather(self, location: GeoPoint) -> dict:
        if not settings.weather_api.api_key:
            return {"risk_score": 0.0}
        url = f"{settings.weather_api.base_url}/weather"
        params = {"lat": location.lat, "lon": location.lng,
                  "appid": settings.weather_api.api_key, "units": "metric"}
        resp = await self.http.get(url, params=params)
        resp.raise_for_status()
        data = resp.json()

        weather_main = data.get("weather", [{}])[0].get("main", "Clear").lower()
        wind = data.get("wind", {}).get("speed", 0) * 3.6
        vis_km = data.get("visibility", 10000) / 1000.0
        temp = data.get("main", {}).get("temp", 20.0)

        risk = 0.0
        if any(c in weather_main for c in ["thunderstorm", "tornado", "hurricane"]):
            risk += 60
        elif any(c in weather_main for c in ["rain", "snow", "drizzle"]):
            risk += 30
        if vis_km < 1: risk += 30
        elif vis_km < 5: risk += 15
        if wind > 80: risk += 25
        elif wind > 50: risk += 15
        if temp < -15 or temp > 45: risk += 10

        return {"risk_score": min(100.0, risk), "visibility_km": vis_km,
                "wind_speed_kmh": wind, "temperature_c": temp}


    async def _fetch_flight_delay(self, flight_number: str) -> float:
        """
        Fetch flight delay from AviationStack.
        NOTE: Free tier uses http:// (not https://).
        Docs: https://aviationstack.com/documentation
        """
        if not settings.flight_api.api_key:
            return 0.0
        # AviationStack free tier requires http
        base = settings.flight_api.base_url.replace("https://", "http://")
        url = f"{base}/flights"
        params = {
            "access_key": settings.flight_api.api_key,
            "flight_iata": flight_number,
            "flight_status": "active",
        }
        try:
            resp = await self.http.get(url, params=params)
            resp.raise_for_status()
            data = resp.json()
            fd_list = data.get("data", [])
            if not fd_list:
                logger.debug("No active flight data for %s", flight_number)
                return 0.0
            fd = fd_list[0]
            # AviationStack delay fields are in minutes
            dep_delay = fd.get("departure", {}).get("delay") or 0
            arr_delay = fd.get("arrival", {}).get("delay") or 0
            return float(max(dep_delay, arr_delay))
        except httpx.HTTPStatusError as e:
            logger.warning("AviationStack HTTP error for %s: %s", flight_number, e.response.status_code)
            return 0.0
        except Exception as e:
            logger.warning("Flight API error for %s: %s", flight_number, e)
            return 0.0

    async def _fetch_ship_position(self, ship_imo: str) -> dict:
        """
        Fetch real-time vessel data from MarineTraffic Extended API.
        API key is embedded in the URL path (MarineTraffic convention).
        Docs: https://www.marinetraffic.com/en/ais-api-services/documentation
        """
        if not settings.ship_tracking_api.api_key or \
                settings.ship_tracking_api.api_key.startswith("your-"):
            logger.debug("Ship tracking API key not configured")
            return {}

        url = f"{settings.ship_tracking_api.base_url}/{settings.ship_tracking_api.api_key}"
        params = {
            "IMO": ship_imo,          # MarineTraffic uses uppercase IMO
            "msgtype": "simple",
            "protocol": "jsono",
        }

        try:
            resp = await self.http.get(url, params=params)
            resp.raise_for_status()
            data = resp.json()

            # MarineTraffic returns a list of vessel records
            vessel = data[0] if isinstance(data, list) and data else data
            if not vessel:
                logger.warning("No vessel data returned for IMO: %s", ship_imo)
                return {}

            # SPEED is reported in 1/10 knots by MarineTraffic
            speed_raw = vessel.get("SPEED", "0")
            heading_raw = vessel.get("HEADING", "0")
            return {
                "speed": float(speed_raw) / 10.0,
                "heading": float(heading_raw),
                "status": vessel.get("STATUS", "UNKNOWN"),
                "lat": float(vessel.get("LAT", 0)),
                "lng": float(vessel.get("LON", 0)),
                "destination": vessel.get("DESTINATION", ""),
                "eta": vessel.get("ETA", ""),
                "vessel_name": vessel.get("SHIPNAME", ""),
                "mmsi": vessel.get("MMSI", ""),
            }
        except httpx.HTTPStatusError as e:
            logger.warning("MarineTraffic HTTP error for IMO %s: %s", ship_imo, e.response.status_code)
            return {}
        except (IndexError, KeyError, TypeError, ValueError) as e:
            logger.warning("Failed to parse ship tracking response for IMO %s: %s", ship_imo, e)
            return {}

    async def close(self):
        if self._http and not self._http.is_closed:
            await self._http.aclose()
