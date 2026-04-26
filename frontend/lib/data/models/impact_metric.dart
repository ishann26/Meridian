/// Category of an impact/sustainability metric.
enum ImpactCategory {
  carbon,
  cost,
  time,
  efficiency,
  reliability,
}

/// Trend direction for a metric.
enum MetricTrend { up, down, flat }

/// A single supply-chain performance / sustainability metric.
class ImpactMetric {
  const ImpactMetric({
    required this.id,
    required this.label,
    required this.value,
    required this.unit,
    required this.category,
    required this.trend,
    required this.changePercent,
    required this.period,
    this.target,
  });

  /// Deserialize from a JSON map.
  factory ImpactMetric.fromJson(Map<String, dynamic> json) {
    return ImpactMetric(
      id: json['id'] as String,
      label: json['label'] as String,
      value: (json['value'] as num).toDouble(),
      unit: json['unit'] as String,
      category: ImpactCategory.values.byName(json['category'] as String),
      trend: MetricTrend.values.byName(json['trend'] as String),
      changePercent: (json['changePercent'] as num).toDouble(),
      period: json['period'] as String,
      target: (json['target'] as num?)?.toDouble(),
    );
  }

  /// Serialize to a JSON map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'value': value,
        'unit': unit,
        'category': category.name,
        'trend': trend.name,
        'changePercent': changePercent,
        'period': period,
        'target': target,
      };

  final String id;

  /// Display name, e.g. "Carbon Footprint".
  final String label;

  /// Current value.
  final double value;

  /// Unit of measurement, e.g. "tons CO₂", "USD", "hours".
  final String unit;

  final ImpactCategory category;
  final MetricTrend trend;

  /// Percentage change from previous period. Negative = improved.
  final double changePercent;

  /// Period label, e.g. "Apr 2026", "Q1 2026".
  final String period;

  /// Optional target value for goal tracking.
  final double? target;

  /// Whether the metric is on track to hit its target.
  bool get isOnTarget => target != null && value <= target!;

  /// Formatted change string, e.g. "+12.3%" or "-5.1%".
  String get changeLabel {
    final sign = changePercent >= 0 ? '+' : '';
    return '$sign${changePercent.toStringAsFixed(1)}%';
  }
}
