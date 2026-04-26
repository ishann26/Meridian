import 'package:meridian/data/models/risk_alert.dart';

/// Contract for risk alert data access.
///
/// Implementations: [MockRiskAlertService] (now), GeminiRiskService (later).
abstract class RiskAlertRepository {
  /// Fetch all active risk alerts.
  Future<List<RiskAlert>> getAll();

  /// Fetch alerts filtered by severity.
  Future<List<RiskAlert>> getBySeverity(RiskSeverity severity);

  /// Fetch alerts that affect a specific shipment.
  Future<List<RiskAlert>> getForShipment(String shipmentId);

  /// Count of high + critical severity alerts.
  Future<int> getCriticalCount();
}
