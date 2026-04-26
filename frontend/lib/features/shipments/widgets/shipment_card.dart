import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meridian/core/theme/app_colors.dart';
import 'package:meridian/core/theme/app_theme.dart';
import 'package:meridian/data/models/shipment.dart';

/// Premium rounded card for a single shipment.
///
/// Shows ID, cargo, origin→destination, mode, ETA,
/// status pill, progress bar, and risk badge.
class ShipmentCard extends StatelessWidget {
  const ShipmentCard({
    super.key,
    required this.shipment,
    this.onTap,
  });

  final Shipment shipment;
  final VoidCallback? onTap;

  // ── Risk level derived from delay + status ───────────────
  String get _riskLabel {
    if (shipment.status == ShipmentStatus.delayed && shipment.delayHours > 24) {
      return 'HIGH';
    }
    if (shipment.status == ShipmentStatus.delayed ||
        shipment.status == ShipmentStatus.customs) {
      return 'MEDIUM';
    }
    return 'LOW';
  }

  Color get _riskColor {
    switch (_riskLabel) {
      case 'HIGH':
        return AppColors.warning;
      case 'MEDIUM':
        return AppColors.accentTan;
      default:
        return AppColors.accentMintDark;
    }
  }

  Color get _statusColor {
    switch (shipment.status) {
      case ShipmentStatus.inTransit:
        return AppColors.accentMintDark;
      case ShipmentStatus.delayed:
        return AppColors.warning;
      case ShipmentStatus.customs:
        return const Color(0xFFFFCC00);
      case ShipmentStatus.delivered:
        return AppColors.success;
      case ShipmentStatus.preparing:
        return AppColors.textTertiary;
    }
  }

  IconData get _modeIcon {
    switch (shipment.mode) {
      case TransportMode.sea:
        return Icons.directions_boat_rounded;
      case TransportMode.air:
        return Icons.flight_rounded;
      case TransportMode.rail:
        return Icons.train_rounded;
      case TransportMode.road:
        return Icons.local_shipping_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Row 1: ID + mode + risk badge ────────────────
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(_modeIcon, size: 15, color: _statusColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shipment.id,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        shipment.modeLabel,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    shipment.statusLabel,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Risk badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _riskColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _riskLabel,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: _riskColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Cargo description ────────────────────────────
            Text(
              shipment.cargoDescription,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 8),

            // ── Route: origin → destination ──────────────────
            Row(
              children: [
                const Icon(Icons.circle, size: 6, color: AppColors.accentMintDark),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    shipment.origin,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    Icons.arrow_forward,
                    size: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
                Flexible(
                  child: Text(
                    shipment.destination,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Progress bar ─────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: shipment.progress,
                minHeight: 4,
                backgroundColor: AppColors.divider,
                valueColor: AlwaysStoppedAnimation<Color>(_statusColor),
              ),
            ),

            const SizedBox(height: 10),

            // ── Footer: ETA + weight ─────────────────────────
            Row(
              children: [
                const Icon(Icons.schedule_rounded,
                    size: 12, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(
                  shipment.daysRemaining > 0
                      ? 'ETA ${shipment.daysRemaining}d'
                      : shipment.status == ShipmentStatus.delivered
                          ? 'Delivered'
                          : 'Departing soon',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textTertiary,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.scale_rounded,
                    size: 12, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(
                  '${(shipment.weightKg / 1000).toStringAsFixed(1)}t',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textTertiary,
                  ),
                ),
                if (shipment.delayHours > 0) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.warning_amber_rounded,
                      size: 12, color: AppColors.warning),
                  const SizedBox(width: 3),
                  Text(
                    '+${shipment.delayHours}h',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
