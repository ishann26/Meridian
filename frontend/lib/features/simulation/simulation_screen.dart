import 'package:flutter/material.dart';
import 'package:meridian/core/theme/app_colors.dart';
import 'package:meridian/shared/widgets/placeholder_screen.dart';

/// Simulation — what-if scenario playground.
///
/// Will let users model disruptions (port closures, delays,
/// reroutes) and see cost/time impact before they happen.
class SimulationScreen extends StatelessWidget {
  const SimulationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Simulation',
      subtitle:
          'Run what-if scenarios. Block a port, reroute cargo, spike demand — see the ripple effect instantly.',
      icon: Icons.science_rounded,
      accentColor: AppColors.accentPeach,
    );
  }
}
