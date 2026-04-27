import 'package:meridian/data/repositories/shipment_repository.dart';
import 'package:meridian/data/repositories/risk_alert_repository.dart';
import 'package:meridian/data/repositories/route_repository.dart';
import 'package:meridian/data/repositories/simulation_repository.dart';
import 'package:meridian/data/repositories/impact_repository.dart';
import 'package:meridian/data/services/api_shipment_service.dart';
import 'package:meridian/data/services/mock_risk_alert_service.dart';
import 'package:meridian/data/services/mock_route_service.dart';
import 'package:meridian/data/services/mock_simulation_service.dart';
import 'package:meridian/data/services/mock_impact_service.dart';

/// Centralized dependency locator for Meridian.
///
/// All repository instances are created here. To switch from
/// mock services to Firebase / REST / Gemini, change exactly
/// one line per repository — no UI files need to be touched.
///
/// Usage:
/// ```dart
/// final repo = ServiceLocator.instance.shipmentRepo;
/// ```
class ServiceLocator {
  ServiceLocator._();

  static final ServiceLocator instance = ServiceLocator._();

  // ── Repositories ──────────────────────────────────────────
  // Swap the right-hand side to switch implementations.

  final ShipmentRepository shipmentRepo = ApiShipmentService();
  final RiskAlertRepository riskAlertRepo = MockRiskAlertService();
  final RouteRepository routeRepo = MockRouteService();
  final SimulationRepository simulationRepo = MockSimulationService();
  final ImpactRepository impactRepo = MockImpactService();
}
