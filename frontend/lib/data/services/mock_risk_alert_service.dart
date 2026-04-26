import 'package:meridian/data/models/risk_alert.dart';
import 'package:meridian/data/mock/mock_risk_alerts.dart';
import 'package:meridian/data/repositories/risk_alert_repository.dart';

/// Mock implementation of [RiskAlertRepository].
///
/// Returns data from [mockRiskAlerts] with simulated latency.
class MockRiskAlertService implements RiskAlertRepository {
  static const _latency = Duration(milliseconds: 350);

  @override
  Future<List<RiskAlert>> getAll() async {
    await Future.delayed(_latency);
    return List.unmodifiable(mockRiskAlerts);
  }

  @override
  Future<List<RiskAlert>> getBySeverity(RiskSeverity severity) async {
    await Future.delayed(_latency);
    return mockRiskAlerts.where((a) => a.severity == severity).toList();
  }

  @override
  Future<List<RiskAlert>> getForShipment(String shipmentId) async {
    await Future.delayed(_latency);
    return mockRiskAlerts
        .where((a) => a.affectedShipmentIds.contains(shipmentId))
        .toList();
  }

  @override
  Future<int> getCriticalCount() async {
    await Future.delayed(_latency);
    return mockRiskAlerts
        .where((a) =>
            a.severity == RiskSeverity.high ||
            a.severity == RiskSeverity.critical)
        .length;
  }
}
