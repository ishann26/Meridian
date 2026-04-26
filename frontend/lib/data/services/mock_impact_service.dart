import 'package:meridian/data/models/impact_metric.dart';
import 'package:meridian/data/mock/mock_impact_metrics.dart';
import 'package:meridian/data/repositories/impact_repository.dart';

/// Mock implementation of [ImpactRepository].
///
/// Returns data from [mockImpactMetrics] with simulated latency.
class MockImpactService implements ImpactRepository {
  static const _latency = Duration(milliseconds: 350);

  @override
  Future<List<ImpactMetric>> getAll() async {
    await Future.delayed(_latency);
    return List.unmodifiable(mockImpactMetrics);
  }

  @override
  Future<List<ImpactMetric>> getByCategory(ImpactCategory category) async {
    await Future.delayed(_latency);
    return mockImpactMetrics.where((m) => m.category == category).toList();
  }
}
