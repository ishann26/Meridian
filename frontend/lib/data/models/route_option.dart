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

  /// Deserialize from a JSON map.
  factory RouteLeg.fromJson(Map<String, dynamic> json) {
    return RouteLeg(
      from: json['from'] as String,
      to: json['to'] as String,
      mode: TransportMode.values.byName(json['mode'] as String),
      distanceKm: (json['distanceKm'] as num).toDouble(),
      durationHours: (json['durationHours'] as num).toDouble(),
      costUsd: (json['costUsd'] as num).toDouble(),
      co2Kg: (json['co2Kg'] as num).toDouble(),
    );
  }

  /// Serialize to a JSON map.
  Map<String, dynamic> toJson() => {
        'from': from,
        'to': to,
        'mode': mode.name,
        'distanceKm': distanceKm,
        'durationHours': durationHours,
        'costUsd': costUsd,
        'co2Kg': co2Kg,
      };

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

  /// Deserialize from a JSON map.
  factory RouteOption.fromJson(Map<String, dynamic> json) {
    return RouteOption(
      id: json['id'] as String,
      name: json['name'] as String,
      origin: json['origin'] as String,
      destination: json['destination'] as String,
      legs: (json['legs'] as List<dynamic>)
          .map((l) => RouteLeg.fromJson(l as Map<String, dynamic>))
          .toList(),
      totalCostUsd: (json['totalCostUsd'] as num).toDouble(),
      totalDurationHours: (json['totalDurationHours'] as num).toDouble(),
      totalDistanceKm: (json['totalDistanceKm'] as num).toDouble(),
      totalCo2Kg: (json['totalCo2Kg'] as num).toDouble(),
      riskScore: (json['riskScore'] as num).toDouble(),
      isRecommended: json['isRecommended'] as bool? ?? false,
    );
  }

  /// Serialize to a JSON map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'origin': origin,
        'destination': destination,
        'legs': legs.map((l) => l.toJson()).toList(),
        'totalCostUsd': totalCostUsd,
        'totalDurationHours': totalDurationHours,
        'totalDistanceKm': totalDistanceKm,
        'totalCo2Kg': totalCo2Kg,
        'riskScore': riskScore,
        'isRecommended': isRecommended,
      };

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
