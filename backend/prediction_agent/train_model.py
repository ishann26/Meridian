"""Train the XGBoost Prediction Agent for Meridian.

This script:
1. Loads and engineers features using feature_engineering.py
2. Splits data 80/20 into train/test sets
3. Trains an XGBClassifier with early stopping
4. Evaluates and prints accuracy, precision, and recall
5. Saves the trained model and feature names to the models/ directory
"""

import json
from pathlib import Path

import xgboost as xgb
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, precision_score, recall_score

from backend.prediction_agent.feature_engineering import load_dataco_data, engineer_features

# ── Paths ────────────────────────────────────────────────────
MODELS_DIR = Path(__file__).resolve().parent / "models"
MODEL_PATH = MODELS_DIR / "delay_predictor.json"
FEATURES_PATH = MODELS_DIR / "feature_names.json"

def main():
    print("═" * 60)
    print("  Meridian Prediction Agent — Model Training")
    print("═" * 60)

    # 1. Load and prepare data
    print("\n[1/4] Loading and engineering features...")
    raw_df = load_dataco_data()
    X, y = engineer_features(raw_df)
    
    # 2. Train/Test Split (80/20)
    print("\n[2/4] Splitting data 80/20...")
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )
    print(f"  → Train: {len(X_train):,} samples")
    print(f"  → Test:  {len(X_test):,} samples")

    # 3. Train XGBoost
    print("\n[3/4] Training XGBClassifier...")
    model = xgb.XGBClassifier(
        n_estimators=200,
        max_depth=6,
        learning_rate=0.1,
        objective="binary:logistic",
        eval_metric="logloss",
        early_stopping_rounds=10,
        random_state=42,
    )
    
    # Pass early_stopping_rounds in constructor, but need eval_set in fit
    model.fit(
        X_train, y_train,
        eval_set=[(X_test, y_test)],
        verbose=10  # Print progress every 10 trees
    )

    # 4. Evaluate
    print("\n[4/4] Evaluating on test set...")
    y_pred = model.predict(X_test)
    
    acc = accuracy_score(y_test, y_pred)
    prec = precision_score(y_test, y_pred)
    rec = recall_score(y_test, y_pred)
    
    print(f"  → Accuracy:  {acc:.4f}")
    print(f"  → Precision: {prec:.4f}")
    print(f"  → Recall:    {rec:.4f}")

    # 5. Save model and metadata
    print("\n[5/5] Saving model artifacts...")
    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    
    model.save_model(MODEL_PATH)
    print(f"  ✓ Model saved to {MODEL_PATH.relative_to(Path.cwd())}")
    
    feature_names = X.columns.tolist()
    with open(FEATURES_PATH, "w") as f:
        json.dump(feature_names, f, indent=2)
    print(f"  ✓ Features saved to {FEATURES_PATH.relative_to(Path.cwd())}")
    
    print("\nTraining complete! 🎉")
    print("═" * 60)

if __name__ == "__main__":
    main()
