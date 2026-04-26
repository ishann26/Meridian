/// Severity level of a supply-chain risk.
enum RiskSeverity { low, medium, high, critical }

/// Category of disruption.
enum RiskCategory {
  weather,
  geopolitical,
  portCongestion,
  supplierDelay,
  regulatory,
  infrastructure,
}

/// An AI-predicted or detected supply-chain risk alert.
class RiskAlert {
  const RiskAlert({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.category,
    required this.affectedRegion,
    required this.detectedAt,
    required this.confidence,
    this.affectedShipmentIds = const [],
    this.recommendation,
  });

  final String id;
  final String title;
  final String description;
  final RiskSeverity severity;
  final RiskCategory category;
  final String affectedRegion;
  final DateTime detectedAt;

  /// AI confidence score, 0.0 – 1.0.
  final double confidence;

  /// IDs of shipments affected by this risk.
  final List<String> affectedShipmentIds;

  /// AI-suggested mitigation action.
  final String? recommendation;

  /// Human-readable severity label.
  String get severityLabel {
    switch (severity) {
      case RiskSeverity.low:
        return 'Low';
      case RiskSeverity.medium:
        return 'Medium';
      case RiskSeverity.high:
        return 'High';
      case RiskSeverity.critical:
        return 'Critical';
    }
  }

  /// Human-readable category label.
  String get categoryLabel {
    switch (category) {
      case RiskCategory.weather:
        return 'Weather';
      case RiskCategory.geopolitical:
        return 'Geopolitical';
      case RiskCategory.portCongestion:
        return 'Port Congestion';
      case RiskCategory.supplierDelay:
        return 'Supplier Delay';
      case RiskCategory.regulatory:
        return 'Regulatory';
      case RiskCategory.infrastructure:
        return 'Infrastructure';
    }
  }

  /// Confidence as a percentage string.
  String get confidenceLabel => '${(confidence * 100).round()}%';
}
