import 'package:go_router/go_router.dart';

import 'package:meridian/features/command_center/command_center_screen.dart';
import 'package:meridian/features/shipments/shipments_screen.dart';
import 'package:meridian/features/shipments/shipment_detail_screen.dart';
import 'package:meridian/features/ai_copilot/ai_copilot_screen.dart';
import 'package:meridian/features/simulation/simulation_screen.dart';
import 'package:meridian/features/impact/impact_screen.dart';
import 'package:meridian/shared/widgets/slc_shell.dart';

/// All named route paths used in Meridian.
abstract class AppRoutes {
  static const String commandCenter = '/';
  static const String shipments = '/shipments';
  static const String shipmentDetail = '/shipments/:id';
  static const String aiCopilot = '/ai-copilot';
  static const String simulation = '/simulation';
  static const String impact = '/impact';
}

/// GoRouter configuration with a [StatefulShellRoute] for
/// persistent bottom navigation across all five tabs.
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.commandCenter,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return SlcShell(navigationShell: navigationShell);
      },
      branches: [
        // ── Tab 0: Command Center ──────────────────────────
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.commandCenter,
              pageBuilder: (context, state) => const NoTransitionPage(
                child: CommandCenterScreen(),
              ),
            ),
          ],
        ),

        // ── Tab 1: Shipments ───────────────────────────────
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.shipments,
              pageBuilder: (context, state) => const NoTransitionPage(
                child: ShipmentsScreen(),
              ),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) {
                    final id = state.pathParameters['id']!;
                    return ShipmentDetailScreen(shipmentId: id);
                  },
                ),
              ],
            ),
          ],
        ),

        // ── Tab 2: AI Copilot ──────────────────────────────
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.aiCopilot,
              pageBuilder: (context, state) => const NoTransitionPage(
                child: AiCopilotScreen(),
              ),
            ),
          ],
        ),

        // ── Tab 3: Simulation ──────────────────────────────
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.simulation,
              pageBuilder: (context, state) => const NoTransitionPage(
                child: SimulationScreen(),
              ),
            ),
          ],
        ),

        // ── Tab 4: Impact ──────────────────────────────────
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.impact,
              pageBuilder: (context, state) => const NoTransitionPage(
                child: ImpactScreen(),
              ),
            ),
          ],
        ),
      ],
    ),
  ],
);
