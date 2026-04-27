/// Transport mode for a shipment leg.
enum TransportMode { road, rail, air, sea }

/// Current status of a shipment in its lifecycle.
enum ShipmentStatus {
  preparing,
  inTransit,
  delayed,
  customs,
  delivered,
}

/// A single shipment moving through the supply chain.
class Shipment {
  const Shipment({
    required this.id,
    required this.trackingCode,
    required this.origin,
    required this.destination,
    required this.status,
    required this.mode,
    required this.departureDate,
    required this.estimatedArrival,
    required this.weightKg,
    required this.cargoDescription,
    required this.progress,
    this.currentLocation,
    this.delayHours = 0,
    this.severity,
  });

  /// Deserialize from a JSON map (Firebase / REST API).
  factory Shipment.fromJson(Map<String, dynamic> json) {
    return Shipment(
      id: (json['shipment_id'] ?? json['id']) as String,
      trackingCode: json['trackingCode'] as String? ?? 'TRK-${json['shipment_id']}',
      origin: json['origin'] as String? ?? 'N/A',
      destination: json['destination'] as String? ?? 'N/A',
      status: _parseStatus(json['status'] as String?),
      mode: _parseMode(json['mode'] as String?),
      departureDate: _parseDate(json['departureDate']),
      estimatedArrival: _parseDate(json['estimatedArrival']),
      weightKg: (json['weightKg'] as num?)?.toDouble() ?? 0.0,
      cargoDescription: json['cargoDescription'] as String? ?? 'General Cargo',
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      currentLocation: json['currentLocation'] as String?,
      delayHours: (json['delay_prediction'] as num?)?.toInt() ?? 0,
      severity: json['severity'] as String?,
    );
  }

  static ShipmentStatus _parseStatus(String? status) {
    if (status == null) return ShipmentStatus.preparing;
    final lower = status.toLowerCase();
    if (lower.contains('transit')) return ShipmentStatus.inTransit;
    if (lower.contains('delay') || lower.contains('disrupt')) return ShipmentStatus.delayed;
    if (lower.contains('custom')) return ShipmentStatus.customs;
    if (lower.contains('deliver')) return ShipmentStatus.delivered;
    return ShipmentStatus.preparing;
  }

  static TransportMode _parseMode(String? mode) {
    if (mode == null) return TransportMode.sea;
    final lower = mode.toLowerCase();
    if (lower.contains('road')) return TransportMode.road;
    if (lower.contains('rail')) return TransportMode.rail;
    if (lower.contains('air')) return TransportMode.air;
    return TransportMode.sea;
  }

  static DateTime _parseDate(dynamic date) {
    if (date == null) return DateTime.now();
    if (date is String) return DateTime.tryParse(date) ?? DateTime.now();
    return DateTime.now();
  }

  final String id;
  final String trackingCode;
  final String origin;
  final String destination;
  final ShipmentStatus status;
  final TransportMode mode;
  final DateTime departureDate;
  final DateTime estimatedArrival;
  final double weightKg;
  final String cargoDescription;
  final double progress;
  final String? currentLocation;
  final int delayHours;
  final String? severity; // Added severity

  /// Human-readable status label.
  String get statusLabel {
    switch (status) {
      case ShipmentStatus.preparing:
        return 'Preparing';
      case ShipmentStatus.inTransit:
        return 'In Transit';
      case ShipmentStatus.delayed:
        return 'Delayed';
      case ShipmentStatus.customs:
        return 'At Customs';
      case ShipmentStatus.delivered:
        return 'Delivered';
    }
  }

  /// Human-readable mode label.
  String get modeLabel {
    switch (mode) {
      case TransportMode.road:
        return 'Road';
      case TransportMode.rail:
        return 'Rail';
      case TransportMode.air:
        return 'Air';
      case TransportMode.sea:
        return 'Sea';
    }
  }

  /// Estimated days remaining.
  int get daysRemaining {
    final remaining = estimatedArrival.difference(DateTime.now()).inDays;
    return remaining < 0 ? 0 : remaining;
  }
}
