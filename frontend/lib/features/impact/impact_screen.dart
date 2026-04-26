import 'package:flutter/material.dart';
import 'package:meridian/core/theme/app_colors.dart';
import 'package:meridian/shared/widgets/placeholder_screen.dart';

/// Impact — sustainability & cost analytics.
///
/// Will display carbon footprint tracking, cost optimization
/// insights, and multi-modal transport efficiency metrics.
class ImpactScreen extends StatelessWidget {
  const ImpactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Impact',
      subtitle:
          'Measure what matters. Carbon footprint, cost savings, and route efficiency — quantified and visualized.',
      icon: Icons.eco_rounded,
      accentColor: AppColors.accentMint,
    );
  }
}
