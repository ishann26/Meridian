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
  });

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

  /// 0.0 – 1.0 representing journey completion.
  final double progress;

  /// Current lat/lng description (e.g. "Arabian Sea").
  final String? currentLocation;

  /// Hours of delay, 0 if on time.
  final int delayHours;

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
