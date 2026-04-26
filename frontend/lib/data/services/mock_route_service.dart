import 'package:meridian/data/models/route_option.dart';
import 'package:meridian/data/mock/mock_routes.dart';
import 'package:meridian/data/repositories/route_repository.dart';

/// Mock implementation of [RouteRepository].
///
/// Returns data from [mockRouteOptions]. In production this would
/// call Google Maps / HERE / Gemini APIs.
class MockRouteService implements RouteRepository {
  static const _latency = Duration(milliseconds: 500);

  @override
  Future<List<RouteOption>> getRoutes({
    required String origin,
    required String destination,
  }) async {
    await Future.delayed(_latency);
    // For now, return all mock routes regardless of origin/destination.
    // Real implementation would filter by corridor.
    return List.unmodifiable(mockRouteOptions);
  }

  @override
  Future<RouteOption?> getRecommended({
    required String origin,
    required String destination,
  }) async {
    await Future.delayed(_latency);
    try {
      return mockRouteOptions.firstWhere((r) => r.isRecommended);
    } catch (_) {
      return null;
    }
  }
}
