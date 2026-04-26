import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meridian/core/theme/app_colors.dart';
import 'package:meridian/core/theme/app_theme.dart';
import 'package:meridian/data/models/risk_alert.dart';

/// Compact risk alert card with severity border and confidence.
class RiskAlertCard extends StatelessWidget {
  const RiskAlertCard({super.key, required this.alert, this.onTap});

  final RiskAlert alert;
  final VoidCallback? onTap;

  Color get _color {
    switch (alert.severity) {
      case RiskSeverity.critical: return AppColors.error;
      case RiskSeverity.high: return AppColors.warning;
      case RiskSeverity.medium: return const Color(0xFFFFCC00);
      case RiskSeverity.low: return AppColors.accentMintDark;
    }
  }

  IconData get _icon {
    switch (alert.category) {
      case RiskCategory.weather: return Icons.thunderstorm_rounded;
      case RiskCategory.geopolitical: return Icons.public_rounded;
      case RiskCategory.portCongestion: return Icons.directions_boat_rounded;
      case RiskCategory.supplierDelay: return Icons.factory_rounded;
      case RiskCategory.regulatory: return Icons.gavel_rounded;
      case RiskCategory.infrastructure: return Icons.construction_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: AppTheme.cardShadow,
          border: Border(left: BorderSide(color: _color, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: _color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_icon, size: 14, color: _color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    alert.title,
                    style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary, height: 1.3,
                    ),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    alert.severityLabel.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: _color, letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 38),
              child: Text(
                alert.description,
                style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary, height: 1.4,
                ),
                maxLines: 2, overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 38),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 12, color: AppColors.textTertiary),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      alert.affectedRegion,
                      style: GoogleFonts.inter(
                        fontSize: 10, fontWeight: FontWeight.w500,
                        color: AppColors.textTertiary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${alert.confidenceLabel} conf.',
                    style: GoogleFonts.inter(
                      fontSize: 10, fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
