"""Feature engineering for Meridian's Prediction Agent.

Loads the DataCo Supply Chain dataset and transforms it into a
feature matrix ready for XGBoost training.

Usage
-----
    from feature_engineering import load_dataco_data, engineer_features

    raw_df = load_dataco_data()
    X, y   = engineer_features(raw_df)

Feature map (DataCo column → engineered feature)
-------------------------------------------------
| Engineered feature          | Source column(s)                            |
|-----------------------------|---------------------------------------------|
| historical_route_delay_rate | Late_delivery_risk grouped by route corridor|
| weather_score               | Order Region × monsoon_flag                 |
| congestion_index            | Shipping Mode + Order Region delay density  |
| route_deviation_meters      | Lat/Lon Haversine vs scheduled days delta   |
| time_of_day_bin             | order date (DateOrders) hour                |
| day_of_week                 | order date (DateOrders) weekday             |
| monsoon_flag                | order date month (Jun–Sep)                  |
| cargo_weight_kg             | Order Item Quantity × Product Price (proxy) |
| cargo_value_inr             | Sales × 83.5 (USD→INR)                     |
| cargo_type_encoded          | Department Name label-encoded               |
| carrier_score               | Shipping Mode ordinal score                 |
| distance_to_next_hub_km     | Haversine(Lat, Lon, hub coords)             |
"""

from __future__ import annotations

import math
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.preprocessing import LabelEncoder

# ── Constants ────────────────────────────────────────────────
_LOCAL_PATH = Path(__file__).resolve().parent / "data" / "DataCoSupplyChainDataset.csv"
_FALLBACK_URL = (
    "https://raw.githubusercontent.com/ashishpatel26/DataCo-SMART-SUPPLY-"
    "CHAIN-FOR-BIG-DATA-ANALYSIS/main/DataCoSupplyChainDataset.csv"
)

# USD → INR conversion (fixed for reproducibility)
_USD_TO_INR: float = 83.5

# Approximate coordinates of major logistics hubs (lat, lon)
_HUB_COORDS: list[tuple[float, float]] = [
    (19.0760, 72.8777),   # Mumbai
    (1.3521, 103.8198),   # Singapore
    (51.5074, -0.1278),   # London
    (40.7128, -74.0060),  # New York
    (22.3193, 114.1694),  # Hong Kong
    (-33.8688, 151.2093), # Sydney
    (25.2048, 55.2708),   # Dubai
]

# Months considered monsoon season (India-centric)
_MONSOON_MONTHS: frozenset[int] = frozenset({6, 7, 8, 9})

# Ordinal shipping mode → carrier quality score (higher = better)
_CARRIER_SCORE_MAP: dict[str, float] = {
    "Same Day": 1.0,
    "First Class": 0.85,
    "Second Class": 0.60,
    "Standard Class": 0.40,
}

# Baseline delay rates per region (estimated from dataset patterns)
_REGION_DELAY_RATE: dict[str, float] = {
    "South Asia": 0.58,
    "Eastern Asia": 0.52,
    "Southeast Asia": 0.55,
    "West Asia": 0.50,
    "Oceania": 0.48,
    "Western Europe": 0.45,
    "Northern Europe": 0.42,
    "Central America": 0.62,
    "South America": 0.60,
    "Caribbean": 0.65,
    "West Africa": 0.70,
    "Central Africa": 0.72,
    "North Africa": 0.68,
    "West of USA ": 0.38,
    "US Center ": 0.35,
}

# Weather risk per region (0–1; higher = more weather disruption)
_REGION_WEATHER_BASE: dict[str, float] = {
    "South Asia": 0.65,
    "Southeast Asia": 0.70,
    "Eastern Asia": 0.55,
    "West Asia": 0.30,
    "Oceania": 0.45,
    "Western Europe": 0.50,
    "Northern Europe": 0.55,
    "Central America": 0.60,
    "South America": 0.55,
    "Caribbean": 0.65,
    "West Africa": 0.60,
    "Central Africa": 0.65,
    "North Africa": 0.40,
    "West of USA ": 0.35,
    "US Center ": 0.40,
}


# ─────────────────────────────────────────────────────────────
# DATA LOADING
# ─────────────────────────────────────────────────────────────

def load_dataco_data() -> pd.DataFrame:
    """Load the DataCo Supply Chain dataset.

    Tries the local file first; falls back to the public GitHub
    URL if the file is not found on disk.

    Returns
    -------
    pd.DataFrame
        Raw dataset with all 53 original columns.

    Raises
    ------
    RuntimeError
        If the dataset cannot be loaded from either source.
    """
    if _LOCAL_PATH.exists():
        print(f"[load_dataco_data] Loading from local path: {_LOCAL_PATH}")
        try:
            df = pd.read_csv(_LOCAL_PATH, encoding="latin-1", low_memory=False)
            print(f"  → {len(df):,} rows loaded from disk.")
            return df
        except Exception as exc:
            print(f"  ! Local load failed ({exc}), trying URL …")

    print(f"[load_dataco_data] Fetching from URL:\n  {_FALLBACK_URL}")
    try:
        df = pd.read_csv(_FALLBACK_URL, encoding="latin-1", low_memory=False)
        print(f"  → {len(df):,} rows loaded from URL.")
        return df
    except Exception as exc:
        raise RuntimeError(
            f"Could not load DataCo dataset from disk or URL. "
            f"Reason: {exc}"
        ) from exc


# ─────────────────────────────────────────────────────────────
# HELPER FUNCTIONS
# ─────────────────────────────────────────────────────────────

def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Return the great-circle distance in km between two points."""
    r = 6371.0  # Earth radius km
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (
        math.sin(dlat / 2) ** 2
        + math.cos(math.radians(lat1))
        * math.cos(math.radians(lat2))
        * math.sin(dlon / 2) ** 2
    )
    return 2 * r * math.asin(math.sqrt(a))


def _nearest_hub_distance(lat: float, lon: float) -> float:
    """Return the distance in km to the nearest logistics hub."""
    return min(
        _haversine_km(lat, lon, h_lat, h_lon)
        for h_lat, h_lon in _HUB_COORDS
    )


def _time_of_day_bin(hour: int) -> int:
    """Encode hour into 4 time-of-day bins.

    0 = Night (00–05), 1 = Morning (06–11),
    2 = Afternoon (12–17), 3 = Evening (18–23).
    """
    if hour < 6:
        return 0
    if hour < 12:
        return 1
    if hour < 18:
        return 2
    return 3


def _parse_order_dates(df: pd.DataFrame) -> pd.DataFrame:
    """Parse order and shipping date columns into datetime."""
    df = df.copy()
    df["_order_dt"] = pd.to_datetime(
        df["order date (DateOrders)"], format="%m/%d/%Y %H:%M", errors="coerce"
    )
    df["_ship_dt"] = pd.to_datetime(
        df["shipping date (DateOrders)"], format="%m/%d/%Y %H:%M", errors="coerce"
    )
    return df


def _historical_route_delay_rate(df: pd.DataFrame) -> pd.Series:
    """Compute per-route historical delay rate.

    Route is defined as (Order Region, Shipping Mode). Each row
    gets the mean Late_delivery_risk of all rows on the same
    corridor (including itself; acceptable at this dataset size).

    Returns
    -------
    pd.Series of float in [0, 1].
    """
    corridor = df.groupby(["Order Region", "Shipping Mode"])["Late_delivery_risk"].transform("mean")
    return corridor.fillna(df["Late_delivery_risk"].mean())


def _weather_score(df: pd.DataFrame) -> pd.Series:
    """Derive a 0–1 weather disruption score.

    Combines the region's baseline weather risk with a monsoon
    flag amplifier (+0.15 during Jun–Sep).
    """
    base = df["Order Region"].map(_REGION_WEATHER_BASE).fillna(0.50)
    monsoon = df["_order_dt"].dt.month.isin(_MONSOON_MONTHS).astype(float) * 0.15
    return (base + monsoon).clip(upper=1.0)


def _congestion_index(df: pd.DataFrame) -> pd.Series:
    """Proxy congestion from shipping mode speed and regional delay density.

    Slower modes in high-delay regions → higher congestion index.
    """
    mode_congestion = df["Shipping Mode"].map({
        "Standard Class": 0.80,
        "Second Class": 0.60,
        "First Class": 0.35,
        "Same Day": 0.15,
    }).fillna(0.50)

    region_delay_density = df["Order Region"].map(_REGION_DELAY_RATE).fillna(0.55)
    return ((mode_congestion + region_delay_density) / 2).clip(0.0, 1.0)


def _route_deviation_meters(df: pd.DataFrame) -> pd.Series:
    """Proxy for route deviation using the gap between real and scheduled days.

    A larger gap suggests unexpected routing. Scaled so 1 day ≈ 50 km deviation.
    """
    day_delta = (
        df["Days for shipping (real)"] - df["Days for shipment (scheduled)"]
    ).clip(lower=0)
    # ~50 km per day of deviation (logistics heuristic), converted to meters
    return (day_delta * 50 * 1000).astype(float)


def _cargo_weight_proxy(df: pd.DataFrame) -> pd.Series:
    """Proxy cargo weight in kg from quantity × unit price tier.

    DataCo has no direct weight column. We use:
        weight_proxy = Order Item Quantity × (Product Price / 10)
    This creates a realistic weight range of ~0.5–500 kg.
    """
    return (
        df["Order Item Quantity"].fillna(1)
        * (df["Product Price"].fillna(df["Product Price"].median()) / 10)
    ).clip(lower=0.1)


def _cargo_value_inr(df: pd.DataFrame) -> pd.Series:
    """Convert order sales (USD) to INR."""
    return df["Sales"].fillna(0.0) * _USD_TO_INR


# ─────────────────────────────────────────────────────────────
# MAIN ENGINEERING FUNCTION
# ─────────────────────────────────────────────────────────────

def engineer_features(
    raw_df: pd.DataFrame,
) -> tuple[pd.DataFrame, pd.Series]:
    """Transform the raw DataCo DataFrame into an XGBoost-ready feature matrix.

    Parameters
    ----------
    raw_df : pd.DataFrame
        Output of ``load_dataco_data()``.

    Returns
    -------
    X : pd.DataFrame
        Feature matrix with 12 engineered columns.  All values are
        numeric; no NaNs remain.
    y : pd.Series
        Binary target — ``Late_delivery_risk`` (0 = on time, 1 = late).

    Feature Columns
    ---------------
    historical_route_delay_rate : float [0, 1]
        Mean late-delivery rate for the same (region, mode) corridor.
    weather_score : float [0, 1]
        Composite weather disruption risk (region base + monsoon amp).
    congestion_index : float [0, 1]
        Proxy from shipping mode speed + regional delay density.
    route_deviation_meters : float ≥ 0
        Estimated deviation in meters from (real − scheduled) days.
    time_of_day_bin : int {0, 1, 2, 3}
        Night / Morning / Afternoon / Evening.
    day_of_week : int {0–6}
        Monday = 0, Sunday = 6.
    monsoon_flag : int {0, 1}
        1 if order placed during Jun–Sep monsoon season.
    cargo_weight_kg : float > 0
        Proxy weight from quantity × price tier.
    cargo_value_inr : float ≥ 0
        Order sales converted to Indian Rupees.
    cargo_type_encoded : int
        Label-encoded Department Name (proxy for cargo category).
    carrier_score : float [0, 1]
        Ordinal quality score for Shipping Mode.
    distance_to_next_hub_km : float ≥ 0
        Haversine distance to the nearest major logistics hub.
    """
    print(f"[engineer_features] Processing {len(raw_df):,} rows …")

    df = raw_df.copy()

    # ── 1. Parse dates ────────────────────────────────────────
    df = _parse_order_dates(df)

    # Drop rows where the target or essential columns are missing
    required_cols = [
        "Late_delivery_risk",
        "Order Region",
        "Shipping Mode",
        "Days for shipping (real)",
        "Days for shipment (scheduled)",
        "Order Item Quantity",
        "Product Price",
        "Sales",
        "Department Name",
        "Latitude",
        "Longitude",
    ]
    before = len(df)
    df.dropna(subset=required_cols, inplace=True)
    dropped = before - len(df)
    if dropped:
        print(f"  → Dropped {dropped:,} rows with missing required fields.")

    # ── 2. Engineer each feature ──────────────────────────────

    # 2a. Historical route delay rate
    df["historical_route_delay_rate"] = _historical_route_delay_rate(df)

    # 2b. Weather score
    df["weather_score"] = _weather_score(df)

    # 2c. Congestion index
    df["congestion_index"] = _congestion_index(df)

    # 2d. Route deviation (meters)
    df["route_deviation_meters"] = _route_deviation_meters(df)

    # 2e. Time of day bin
    hour = df["_order_dt"].dt.hour.fillna(0).astype(int)
    df["time_of_day_bin"] = hour.map(_time_of_day_bin)

    # 2f. Day of week (Mon=0 … Sun=6)
    df["day_of_week"] = df["_order_dt"].dt.dayofweek.fillna(0).astype(int)

    # 2g. Monsoon flag
    month = df["_order_dt"].dt.month.fillna(1).astype(int)
    df["monsoon_flag"] = month.isin(_MONSOON_MONTHS).astype(int)

    # 2h. Cargo weight proxy (kg)
    df["cargo_weight_kg"] = _cargo_weight_proxy(df)

    # 2i. Cargo value in INR
    df["cargo_value_inr"] = _cargo_value_inr(df)

    # 2j. Cargo type encoded (Department Name → integer label)
    le = LabelEncoder()
    df["cargo_type_encoded"] = le.fit_transform(
        df["Department Name"].fillna("Unknown").astype(str)
    )

    # 2k. Carrier score
    df["carrier_score"] = (
        df["Shipping Mode"]
        .map(_CARRIER_SCORE_MAP)
        .fillna(0.50)
    )

    # 2l. Distance to nearest hub (km) — vectorised via apply
    lat = df["Latitude"].fillna(0.0)
    lon = df["Longitude"].fillna(0.0)
    df["distance_to_next_hub_km"] = [
        _nearest_hub_distance(la, lo)
        for la, lo in zip(lat, lon)
    ]

    # ── 3. Assemble feature matrix ────────────────────────────
    feature_cols: list[str] = [
        "historical_route_delay_rate",
        "weather_score",
        "congestion_index",
        "route_deviation_meters",
        "time_of_day_bin",
        "day_of_week",
        "monsoon_flag",
        "cargo_weight_kg",
        "cargo_value_inr",
        "cargo_type_encoded",
        "carrier_score",
        "distance_to_next_hub_km",
    ]

    X: pd.DataFrame = df[feature_cols].copy()
    y: pd.Series = df["Late_delivery_risk"].astype(int)

    # ── 4. Final NaN sweep (safety net) ──────────────────────
    remaining_nans = X.isna().sum().sum()
    if remaining_nans:
        print(f"  → Imputing {remaining_nans} remaining NaN(s) with column medians.")
        X.fillna(X.median(numeric_only=True), inplace=True)

    # ── 5. Cast all to float32 for XGBoost efficiency ─────────
    X = X.astype(np.float32)

    print(f"  → Feature matrix: {X.shape}  |  Target balance: "
          f"{y.mean():.1%} late deliveries")

    return X, y


# ─────────────────────────────────────────────────────────────
# QUICK VALIDATION (run as script)
# ─────────────────────────────────────────────────────────────

if __name__ == "__main__":
    raw = load_dataco_data()
    X, y = engineer_features(raw)

    print("\n── Feature matrix sample ──────────────────────────")
    print(X.head(3).to_string())
    print("\n── Feature statistics ─────────────────────────────")
    print(X.describe().T[["mean", "std", "min", "max"]].round(3).to_string())
    print("\n── Target distribution ────────────────────────────")
    print(y.value_counts(normalize=True).rename({0: "on time", 1: "late"}).to_string())
    print("\n── NaN check ──────────────────────────────────────")
    nans = X.isna().sum()
    print("All zero:", (nans == 0).all(), "— no NaN values remain.")
