import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meridian/core/theme/app_colors.dart';
import 'package:meridian/core/theme/app_theme.dart';
import 'package:meridian/data/models/shipment.dart';
import 'package:meridian/data/repositories/shipment_repository.dart';
import 'package:meridian/data/services/mock_shipment_service.dart';

/// Detail screen for a single shipment.
///
/// Loaded by ID via the repository — does not import mock data directly.
class ShipmentDetailScreen extends StatefulWidget {
  const ShipmentDetailScreen({super.key, required this.shipmentId});

  final String shipmentId;

  @override
  State<ShipmentDetailScreen> createState() => _ShipmentDetailScreenState();
}

class _ShipmentDetailScreenState extends State<ShipmentDetailScreen> {
  final ShipmentRepository _repo = MockShipmentService();
  late Future<Shipment?> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.getById(widget.shipmentId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.shipmentId,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<Shipment?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.panelDark, strokeWidth: 2.5,
              ),
            );
          }
          final shipment = snap.data;
          if (shipment == null) {
            return Center(
              child: Text(
                'Shipment not found',
                style: GoogleFonts.inter(
                  fontSize: 15, color: AppColors.textTertiary,
                ),
              ),
            );
          }
          return _buildDetail(shipment);
        },
      ),
    );
  }

  Widget _buildDetail(Shipment s) {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      children: [
        // ── Hero card ────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.panelDark,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            boxShadow: AppTheme.elevatedShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(s.trackingCode,
                    style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: AppColors.accentMint, letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  _statusPill(s),
                ],
              ),
              const SizedBox(height: 16),
              Text(s.cargoDescription,
                style: GoogleFonts.inter(
                  fontSize: 18, fontWeight: FontWeight.w700,
                  color: AppColors.textOnDark,
                ),
              ),
              const SizedBox(height: 16),
              // Progress
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: s.progress,
                  minHeight: 5,
                  backgroundColor: AppColors.panelDarkSoft,
                  valueColor: const AlwaysStoppedAnimation(AppColors.accentMint),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('${(s.progress * 100).round()}% complete',
                    style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w500,
                      color: AppColors.textOnDarkMuted,
                    ),
                  ),
                  const Spacer(),
                  if (s.currentLocation != null)
                    Text(s.currentLocation!,
                      style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w500,
                        color: AppColors.textOnDarkMuted,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Info grid ────────────────────────────────────────
        Row(
          children: [
            Expanded(child: _infoTile('Origin', s.origin)),
            const SizedBox(width: 12),
            Expanded(child: _infoTile('Destination', s.destination)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _infoTile('Mode', s.modeLabel)),
            const SizedBox(width: 12),
            Expanded(
              child: _infoTile('Weight', '${(s.weightKg / 1000).toStringAsFixed(1)} tons'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _infoTile('Departed',
                  '${s.departureDate.day}/${s.departureDate.month}/${s.departureDate.year}'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _infoTile('ETA',
                  '${s.estimatedArrival.day}/${s.estimatedArrival.month}/${s.estimatedArrival.year}'),
            ),
          ],
        ),
        if (s.delayHours > 0) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _infoTile('Delay', '+${s.delayHours} hours',
                    valueColor: AppColors.warning),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoTile('Days Left', '${s.daysRemaining}'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _statusPill(Shipment s) {
    Color color;
    switch (s.status) {
      case ShipmentStatus.inTransit:  color = AppColors.accentMint; break;
      case ShipmentStatus.delayed:    color = AppColors.warning; break;
      case ShipmentStatus.customs:    color = const Color(0xFFFFCC00); break;
      case ShipmentStatus.delivered:  color = AppColors.success; break;
      case ShipmentStatus.preparing:  color = AppColors.textOnDarkMuted; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        s.statusLabel,
        style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w600, color: color,
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
            style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w500,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 4),
          Text(value,
            style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
            maxLines: 2, overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
