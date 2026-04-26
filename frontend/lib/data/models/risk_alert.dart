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

  /// Deserialize from a JSON map.
  factory RiskAlert.fromJson(Map<String, dynamic> json) {
    return RiskAlert(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      severity: RiskSeverity.values.byName(json['severity'] as String),
      category: RiskCategory.values.byName(json['category'] as String),
      affectedRegion: json['affectedRegion'] as String,
      detectedAt: DateTime.parse(json['detectedAt'] as String),
      confidence: (json['confidence'] as num).toDouble(),
      affectedShipmentIds: (json['affectedShipmentIds'] as List<dynamic>?)
              ?.cast<String>() ??
          const [],
      recommendation: json['recommendation'] as String?,
    );
  }

  /// Serialize to a JSON map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'severity': severity.name,
        'category': category.name,
        'affectedRegion': affectedRegion,
        'detectedAt': detectedAt.toIso8601String(),
        'confidence': confidence,
        'affectedShipmentIds': affectedShipmentIds,
        'recommendation': recommendation,
      };

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
