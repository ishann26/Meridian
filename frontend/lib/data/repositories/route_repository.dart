import 'package:meridian/data/models/route_option.dart';

/// Contract for route planning data access.
///
/// Implementations: [MockRouteService] (now), MapsRouteService (later).
abstract class RouteRepository {
  /// Fetch available route options between an origin and destination.
  Future<List<RouteOption>> getRoutes({
    required String origin,
    required String destination,
  });

  /// Get the AI-recommended route for a corridor.
  Future<RouteOption?> getRecommended({
    required String origin,
    required String destination,
  });
}
