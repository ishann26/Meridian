"""Synthetic data generator + XGBoost training pipeline.

Run directly to train:
    python -m app.ml.train

Generates ~5 000 synthetic shipment records with realistic
correlations, trains an XGBoost binary classifier for delay
probability, evaluates on a holdout set, and saves the model.
"""

from __future__ import annotations

import os
import json
from pathlib import Path

import numpy as np
import pandas as pd
import xgboost as xgb
from sklearn.model_selection import train_test_split
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    roc_auc_score,
)
import joblib

from app.ml.features import FEATURE_NAMES

# ── Paths ────────────────────────────────────────────────────
MODEL_DIR = Path(__file__).resolve().parent.parent.parent / "models"
MODEL_PATH = MODEL_DIR / "delay_predictor.joblib"
METADATA_PATH = MODEL_DIR / "model_metadata.json"


# ─────────────────────────────────────────────────────────────
# SYNTHETIC DATA GENERATION
# ─────────────────────────────────────────────────────────────
def generate_synthetic_data(n: int = 5000, seed: int = 42) -> pd.DataFrame:
    """Generate *n* synthetic shipment records with realistic delay labels.

    The delay label is derived from a logistic function of the
    features so the XGBoost model has real signal to learn.
    """
    rng = np.random.default_rng(seed)

    # Base features
    distance = rng.uniform(100, 20_000, n)
    weight = rng.uniform(50, 50_000, n)
    cargo_value = rng.uniform(1_000, 500_000, n)
    congestion = rng.uniform(0.0, 1.0, n)
    dow = rng.integers(0, 7, n).astype(float)
    hour = rng.integers(0, 24, n).astype(float)
    hist_delay = rng.uniform(0.0, 0.5, n)
    hazardous = rng.choice([0.0, 1.0], n, p=[0.85, 0.15])
    perishable = rng.choice([0.0, 1.0], n, p=[0.80, 0.20])

    # One-hot transport mode
    modes = rng.choice(["air", "rail", "road", "sea"], n, p=[0.15, 0.25, 0.30, 0.30])
    mode_air = (modes == "air").astype(float)
    mode_rail = (modes == "rail").astype(float)
    mode_road = (modes == "road").astype(float)
    mode_sea = (modes == "sea").astype(float)

    # One-hot weather origin
    w_origin = rng.choice(["clear", "fog", "rain", "storm"], n, p=[0.50, 0.15, 0.25, 0.10])
    wo_clear = (w_origin == "clear").astype(float)
    wo_fog = (w_origin == "fog").astype(float)
    wo_rain = (w_origin == "rain").astype(float)
    wo_storm = (w_origin == "storm").astype(float)

    # One-hot weather destination
    w_dest = rng.choice(["clear", "fog", "rain", "storm"], n, p=[0.50, 0.15, 0.25, 0.10])
    wd_clear = (w_dest == "clear").astype(float)
    wd_fog = (w_dest == "fog").astype(float)
    wd_rain = (w_dest == "rain").astype(float)
    wd_storm = (w_dest == "storm").astype(float)

    # ── Derive delay label with realistic signal ─────────────
    # Higher congestion, storms, sea transport, heavy loads → more delays
    logit = (
        -2.0
        + 1.8 * congestion
        + 1.5 * wo_storm + 0.8 * wo_rain + 0.4 * wo_fog
        + 1.2 * wd_storm + 0.6 * wd_rain
        + 0.5 * mode_sea + 0.3 * mode_road - 0.3 * mode_air
        + 0.4 * (distance / 20_000)
        + 0.3 * (weight / 50_000)
        + 1.0 * hist_delay
        + 0.3 * hazardous
        + 0.2 * perishable
        + 0.15 * ((dow >= 5).astype(float))  # weekends
        + rng.normal(0, 0.3, n)  # noise
    )
    prob = 1.0 / (1.0 + np.exp(-logit))
    delayed = (rng.random(n) < prob).astype(int)

    df = pd.DataFrame({
        "distance_km": distance,
        "weight_kg": weight,
        "cargo_value_usd": cargo_value,
        "port_congestion_index": congestion,
        "day_of_week": dow,
        "hour_of_departure": hour,
        "historical_delay_rate": hist_delay,
        "is_hazardous": hazardous,
        "is_perishable": perishable,
        "mode_air": mode_air,
        "mode_rail": mode_rail,
        "mode_road": mode_road,
        "mode_sea": mode_sea,
        "weather_origin_clear": wo_clear,
        "weather_origin_fog": wo_fog,
        "weather_origin_rain": wo_rain,
        "weather_origin_storm": wo_storm,
        "weather_dest_clear": wd_clear,
        "weather_dest_fog": wd_fog,
        "weather_dest_rain": wd_rain,
        "weather_dest_storm": wd_storm,
        "delayed": delayed,
    })

    return df


# ─────────────────────────────────────────────────────────────
# TRAINING
# ─────────────────────────────────────────────────────────────
def train_model() -> None:
    """Train an XGBoost classifier and save to disk."""
    print("═" * 60)
    print("  Meridian Prediction Agent — Training Pipeline")
    print("═" * 60)

    # 1. Generate data
    print("\n[1/4] Generating synthetic training data …")
    df = generate_synthetic_data(n=5000)
    print(f"  → {len(df)} records, {df['delayed'].mean():.1%} delayed")

    # 2. Split
    print("\n[2/4] Splitting train / test (80/20) …")
    X = df[FEATURE_NAMES]
    y = df["delayed"]
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y,
    )
    print(f"  → Train: {len(X_train)}, Test: {len(X_test)}")

    # 3. Train XGBoost
    print("\n[3/4] Training XGBoost classifier …")
    model = xgb.XGBClassifier(
        n_estimators=200,
        max_depth=6,
        learning_rate=0.1,
        subsample=0.8,
        colsample_bytree=0.8,
        min_child_weight=3,
        gamma=0.1,
        reg_alpha=0.1,
        reg_lambda=1.0,
        scale_pos_weight=1.0,
        objective="binary:logistic",
        eval_metric="auc",
        random_state=42,
        use_label_encoder=False,
    )
    model.fit(
        X_train, y_train,
        eval_set=[(X_test, y_test)],
        verbose=False,
    )

    # 4. Evaluate
    print("\n[4/4] Evaluating on test set …")
    y_pred = model.predict(X_test)
    y_proba = model.predict_proba(X_test)[:, 1]

    acc = accuracy_score(y_test, y_pred)
    auc = roc_auc_score(y_test, y_proba)
    report = classification_report(y_test, y_pred, output_dict=True)

    print(f"  → Accuracy:  {acc:.4f}")
    print(f"  → ROC AUC:   {auc:.4f}")
    print(f"  → Precision: {report['1']['precision']:.4f}")
    print(f"  → Recall:    {report['1']['recall']:.4f}")
    print(f"  → F1:        {report['1']['f1-score']:.4f}")

    # 5. Save model + metadata
    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    joblib.dump(model, MODEL_PATH)
    print(f"\n  ✓ Model saved to {MODEL_PATH}")

    metadata = {
        "version": "1.0.0",
        "features": FEATURE_NAMES,
        "features_count": len(FEATURE_NAMES),
        "training_samples": len(X_train),
        "test_samples": len(X_test),
        "accuracy": round(acc, 4),
        "roc_auc": round(auc, 4),
        "precision": round(report["1"]["precision"], 4),
        "recall": round(report["1"]["recall"], 4),
        "f1_score": round(report["1"]["f1-score"], 4),
    }
    with open(METADATA_PATH, "w") as f:
        json.dump(metadata, f, indent=2)
    print(f"  ✓ Metadata saved to {METADATA_PATH}")
    print("\n" + "═" * 60)


if __name__ == "__main__":
    train_model()
