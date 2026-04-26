import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meridian/core/theme/app_colors.dart';
import 'package:meridian/core/theme/app_theme.dart';

/// A premium, pill-shaped badge displaying delay probability and risk level.
///
/// Features:
/// - Soft shadow and very rounded corners (pill shape).
/// - Dynamic coloring based on risk: mint (low), orange (medium), red (high).
/// - Large bold percentage and smaller descriptive text.
class RiskBadge extends StatelessWidget {
  final double delayProbability;
  final String? riskLevel;
  final double? predictedDelayHours;

  const RiskBadge({
    super.key,
    required this.delayProbability,
    this.riskLevel,
    this.predictedDelayHours,
  });

  @override
  Widget build(BuildContext context) {
    final String level = riskLevel?.toUpperCase() ?? _deriveRiskLevel();
    final Color badgeColor = _getRiskColor(level);
    final int percentage = (delayProbability * 100).round();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingLg,
        vertical: AppTheme.spacingMd,
      ),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '$percentage%',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _getSubtitleText(),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary.withValues(alpha: 0.7),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  String _deriveRiskLevel() {
    if (delayProbability >= 0.75) return 'HIGH';
    if (delayProbability >= 0.25) return 'MEDIUM';
    return 'LOW';
  }

  Color _getRiskColor(String level) {
    switch (level) {
      case 'HIGH':
      case 'CRITICAL':
        return AppColors.error; // Soft red from theme
      case 'MEDIUM':
        return AppColors.warning; // Soft orange from theme
      case 'LOW':
      default:
        return AppColors.accentMint; // Mint for positive/low risk
    }
  }

  String _getSubtitleText() {
    if (predictedDelayHours != null && predictedDelayHours! > 0) {
      // e.g. "4.2h delay"
      final hoursStr = predictedDelayHours!.toStringAsFixed(1);
      return '+$hoursStr\h delay';
    }
    return 'delay risk';
  }
}
