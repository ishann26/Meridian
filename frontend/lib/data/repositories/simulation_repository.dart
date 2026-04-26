import 'package:meridian/data/models/simulation_result.dart';

/// Contract for what-if simulation execution.
///
/// Implementations: [MockSimulationService] (now), GeminiSimService (later).
abstract class SimulationRepository {
  /// Run a what-if simulation with the given input parameters.
  Future<SimulationResult> runSimulation(SimulationInput input);

  /// Fetch past simulation results.
  Future<List<SimulationResult>> getHistory();
}
