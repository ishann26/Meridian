import 'package:flutter/material.dart';
import 'package:meridian/core/theme/app_colors.dart';
import 'package:meridian/shared/widgets/placeholder_screen.dart';

/// Command Center — the main dashboard.
///
/// Will display hero KPI cards, active shipment summary,
/// disruption alerts, and quick-action shortcuts.
class CommandCenterScreen extends StatelessWidget {
  const CommandCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Command Center',
      subtitle:
          'Your logistics nerve center. Live KPIs, disruption alerts, and fleet overview — all at a glance.',
      icon: Icons.dashboard_rounded,
      accentColor: AppColors.accentMint,
    );
  }
}
