import 'dart:math';

import 'package:meridian/data/models/simulation_result.dart';
import 'package:meridian/data/repositories/simulation_repository.dart';

/// Mock implementation of [SimulationRepository].
///
/// Generates deterministic-ish results based on input parameters
/// rather than returning static data, so the UI feels dynamic.
class MockSimulationService implements SimulationRepository {
  final List<SimulationResult> _history = [];
  final _rng = Random(42);

  @override
  Future<SimulationResult> runSimulation(SimulationInput input) async {
    // Simulate computation time.
    await Future.delayed(const Duration(milliseconds: 800));

    final baselineCost = 284600.0;
    final baselineDelay = 2.1;

    // Scale impact by severity and duration.
    final costMultiplier =
        1.0 + (0.05 * input.durationDays * input.severityMultiplier);
    final delayMultiplier =
        1.0 + (0.15 * input.durationDays * input.severityMultiplier);

    // Add slight randomness so repeated runs feel different.
    final jitter = 0.95 + (_rng.nextDouble() * 0.1);

    final result = SimulationResult(
      id: 'SIM-${_history.length + 1}'.padLeft(7, '0'),
      input: input,
      baselineCostUsd: baselineCost,
      projectedCostUsd: baselineCost * costMultiplier * jitter,
      baselineDelayDays: baselineDelay,
      projectedDelayDays: baselineDelay * delayMultiplier * jitter,
      shipmentsAffected: (input.durationDays * input.severityMultiplier)
          .clamp(1, 6)
          .round(),
      riskDelta: (0.08 * input.durationDays * input.severityMultiplier)
          .clamp(0.0, 1.0),
      mitigationSuggestion: _generateSuggestion(input),
      ranAt: DateTime.now(),
    );

    _history.add(result);
    return result;
  }

  @override
  Future<List<SimulationResult>> getHistory() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.unmodifiable(_history.reversed);
  }

  String _generateSuggestion(SimulationInput input) {
    switch (input.scenario) {
      case ScenarioType.portClosure:
        return 'Reroute affected shipments to the nearest alternate port '
            '(${input.affectedNode} bypass). Pre-book berth slots to avoid '
            'queuing delays at the fallback port.';
      case ScenarioType.demandSpike:
        return 'Activate buffer inventory at regional warehouses and '
            'increase order frequency with tier-2 suppliers to absorb '
            'the ${input.durationDays}-day demand surge.';
      case ScenarioType.supplierShutdown:
        return 'Switch to pre-qualified alternate supplier for the '
            'affected component. Expedite via air freight if lead-time '
            'gap exceeds 5 days.';
      case ScenarioType.routeBlockage:
        return 'Reroute via the next-best multi-modal corridor. For '
            '${input.affectedNode}, consider rail + sea combination to '
            'maintain cost efficiency.';
      case ScenarioType.weatherEvent:
        return 'Hold departures for ${input.durationDays} days until the '
            'weather window clears. Pre-position cargo at the origin port '
            'to enable rapid dispatch post-event.';
    }
  }
}
