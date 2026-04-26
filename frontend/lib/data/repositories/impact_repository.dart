import 'package:meridian/data/models/impact_metric.dart';

/// Contract for sustainability / performance metric access.
///
/// Implementations: [MockImpactService] (now), AnalyticsService (later).
abstract class ImpactRepository {
  /// Fetch all impact metrics for the current period.
  Future<List<ImpactMetric>> getAll();

  /// Fetch metrics filtered by category.
  Future<List<ImpactMetric>> getByCategory(ImpactCategory category);
}
