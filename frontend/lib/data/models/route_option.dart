import 'shipment.dart';

/// A single leg within a multi-modal route.
class RouteLeg {
  const RouteLeg({
    required this.from,
    required this.to,
    required this.mode,
    required this.distanceKm,
    required this.durationHours,
    required this.costUsd,
    required this.co2Kg,
  });

  final String from;
  final String to;
  final TransportMode mode;
  final double distanceKm;
  final double durationHours;
  final double costUsd;
  final double co2Kg;
}

/// A complete route option from origin to destination,
/// composed of one or more [RouteLeg]s.
class RouteOption {
  const RouteOption({
    required this.id,
    required this.name,
    required this.origin,
    required this.destination,
    required this.legs,
    required this.totalCostUsd,
    required this.totalDurationHours,
    required this.totalDistanceKm,
    required this.totalCo2Kg,
    required this.riskScore,
    this.isRecommended = false,
  });

  final String id;

  /// Display label, e.g. "Sea + Rail Express".
  final String name;
  final String origin;
  final String destination;
  final List<RouteLeg> legs;
  final double totalCostUsd;
  final double totalDurationHours;
  final double totalDistanceKm;
  final double totalCo2Kg;

  /// 0.0 (safest) – 1.0 (riskiest).
  final double riskScore;

  /// AI-recommended best option flag.
  final bool isRecommended;

  /// Number of distinct transport modes used.
  int get modeCount => legs.map((l) => l.mode).toSet().length;

  /// Human-readable duration.
  String get durationLabel {
    final days = (totalDurationHours / 24).floor();
    final hours = (totalDurationHours % 24).round();
    if (days > 0) return '${days}d ${hours}h';
    return '${hours}h';
  }
}
