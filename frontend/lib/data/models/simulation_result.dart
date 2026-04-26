/// The type of disruption scenario to simulate.
enum ScenarioType {
  portClosure,
  demandSpike,
  supplierShutdown,
  routeBlockage,
  weatherEvent,
}

/// Input parameters for a what-if simulation.
class SimulationInput {
  const SimulationInput({
    required this.scenario,
    required this.affectedNode,
    required this.durationDays,
    this.severityMultiplier = 1.0,
  });

  /// Deserialize from a JSON map.
  factory SimulationInput.fromJson(Map<String, dynamic> json) {
    return SimulationInput(
      scenario: ScenarioType.values.byName(json['scenario'] as String),
      affectedNode: json['affectedNode'] as String,
      durationDays: (json['durationDays'] as num).toInt(),
      severityMultiplier:
          (json['severityMultiplier'] as num?)?.toDouble() ?? 1.0,
    );
  }

  /// Serialize to a JSON map.
  Map<String, dynamic> toJson() => {
        'scenario': scenario.name,
        'affectedNode': affectedNode,
        'durationDays': durationDays,
        'severityMultiplier': severityMultiplier,
      };

  final ScenarioType scenario;

  /// The port, route, or supplier being disrupted.
  final String affectedNode;

  /// How many days the disruption lasts.
  final int durationDays;

  /// 1.0 = normal, 2.0 = severe, etc.
  final double severityMultiplier;

  /// Human-readable scenario label.
  String get scenarioLabel {
    switch (scenario) {
      case ScenarioType.portClosure:
        return 'Port Closure';
      case ScenarioType.demandSpike:
        return 'Demand Spike';
      case ScenarioType.supplierShutdown:
        return 'Supplier Shutdown';
      case ScenarioType.routeBlockage:
        return 'Route Blockage';
      case ScenarioType.weatherEvent:
        return 'Weather Event';
    }
  }
}

/// Output of a what-if simulation run.
class SimulationResult {
  const SimulationResult({
    required this.id,
    required this.input,
    required this.baselineCostUsd,
    required this.projectedCostUsd,
    required this.baselineDelayDays,
    required this.projectedDelayDays,
    required this.shipmentsAffected,
    required this.riskDelta,
    required this.mitigationSuggestion,
    required this.ranAt,
  });

  /// Deserialize from a JSON map.
  factory SimulationResult.fromJson(Map<String, dynamic> json) {
    return SimulationResult(
      id: json['id'] as String,
      input: SimulationInput.fromJson(json['input'] as Map<String, dynamic>),
      baselineCostUsd: (json['baselineCostUsd'] as num).toDouble(),
      projectedCostUsd: (json['projectedCostUsd'] as num).toDouble(),
      baselineDelayDays: (json['baselineDelayDays'] as num).toDouble(),
      projectedDelayDays: (json['projectedDelayDays'] as num).toDouble(),
      shipmentsAffected: (json['shipmentsAffected'] as num).toInt(),
      riskDelta: (json['riskDelta'] as num).toDouble(),
      mitigationSuggestion: json['mitigationSuggestion'] as String,
      ranAt: DateTime.parse(json['ranAt'] as String),
    );
  }

  /// Serialize to a JSON map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'input': input.toJson(),
        'baselineCostUsd': baselineCostUsd,
        'projectedCostUsd': projectedCostUsd,
        'baselineDelayDays': baselineDelayDays,
        'projectedDelayDays': projectedDelayDays,
        'shipmentsAffected': shipmentsAffected,
        'riskDelta': riskDelta,
        'mitigationSuggestion': mitigationSuggestion,
        'ranAt': ranAt.toIso8601String(),
      };

  final String id;
  final SimulationInput input;

  /// Cost before disruption.
  final double baselineCostUsd;

  /// Projected cost after disruption.
  final double projectedCostUsd;

  /// Avg delay before disruption (days).
  final double baselineDelayDays;

  /// Projected avg delay after disruption (days).
  final double projectedDelayDays;

  /// Number of shipments impacted.
  final int shipmentsAffected;

  /// Change in overall risk score (-1.0 to +1.0).
  final double riskDelta;

  /// AI-generated suggestion.
  final String mitigationSuggestion;

  /// When the simulation was executed.
  final DateTime ranAt;

  /// Cost increase as a percentage.
  double get costImpactPercent =>
      baselineCostUsd > 0
          ? ((projectedCostUsd - baselineCostUsd) / baselineCostUsd) * 100
          : 0;

  /// Delay increase in days.
  double get delayIncreaseDays => projectedDelayDays - baselineDelayDays;
}
