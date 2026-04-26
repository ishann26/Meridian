import 'package:meridian/data/models/route_option.dart';
import 'package:meridian/data/models/shipment.dart';

/// Two route options for Mumbai → Rotterdam corridor.
final List<RouteOption> mockRouteOptions = [
  RouteOption(
    id: 'RTE-001',
    name: 'Direct Sea — Suez Canal',
    origin: 'Mumbai, India',
    destination: 'Rotterdam, Netherlands',
    legs: const [
      RouteLeg(
        from: 'Mumbai Port',
        to: 'Jeddah',
        mode: TransportMode.sea,
        distanceKm: 4800,
        durationHours: 168, // 7 days
        costUsd: 3200,
        co2Kg: 820,
      ),
      RouteLeg(
        from: 'Jeddah',
        to: 'Port Said (Suez)',
        mode: TransportMode.sea,
        distanceKm: 1400,
        durationHours: 48,
        costUsd: 900,
        co2Kg: 240,
      ),
      RouteLeg(
        from: 'Port Said',
        to: 'Rotterdam',
        mode: TransportMode.sea,
        distanceKm: 5200,
        durationHours: 192, // 8 days
        costUsd: 3500,
        co2Kg: 890,
      ),
    ],
    totalCostUsd: 7600,
    totalDurationHours: 408, // ~17 days
    totalDistanceKm: 11400,
    totalCo2Kg: 1950,
    riskScore: 0.35,
    isRecommended: true,
  ),
  RouteOption(
    id: 'RTE-002',
    name: 'Air + Road Hybrid',
    origin: 'Mumbai, India',
    destination: 'Rotterdam, Netherlands',
    legs: const [
      RouteLeg(
        from: 'Mumbai Airport',
        to: 'Frankfurt Airport',
        mode: TransportMode.air,
        distanceKm: 6600,
        durationHours: 9,
        costUsd: 12500,
        co2Kg: 4200,
      ),
      RouteLeg(
        from: 'Frankfurt',
        to: 'Rotterdam',
        mode: TransportMode.road,
        distanceKm: 450,
        durationHours: 6,
        costUsd: 800,
        co2Kg: 95,
      ),
    ],
    totalCostUsd: 13300,
    totalDurationHours: 15,
    totalDistanceKm: 7050,
    totalCo2Kg: 4295,
    riskScore: 0.12,
    isRecommended: false,
  ),
];
