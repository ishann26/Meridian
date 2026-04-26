import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meridian/core/theme/app_colors.dart';
import 'package:meridian/core/theme/app_theme.dart';
import 'package:meridian/data/models/shipment.dart';
import 'package:meridian/data/repositories/shipment_repository.dart';
import 'package:meridian/core/di/service_locator.dart';
import 'package:meridian/widgets/risk_badge.dart';

/// Full logistics decision view for a single shipment.
///
/// Sections: header, cargo, route intelligence, disruption risks,
/// timeline, AI recommendation, and action buttons.
class ShipmentDetailScreen extends StatefulWidget {
  const ShipmentDetailScreen({super.key, required this.shipmentId});
  final String shipmentId;

  @override
  State<ShipmentDetailScreen> createState() => _ShipmentDetailScreenState();
}

class _ShipmentDetailScreenState extends State<ShipmentDetailScreen> {
  final ShipmentRepository _repo = ServiceLocator.instance.shipmentRepo;
  late Future<Shipment?> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.getById(widget.shipmentId);
  }

  // ── Risk helpers ──────────────────────────────────────────
  String _riskLabel(Shipment s) {
    if (s.status == ShipmentStatus.delayed && s.delayHours > 24) {
      return 'HIGH';
    }
    if (s.status == ShipmentStatus.delayed ||
        s.status == ShipmentStatus.customs) {
      return 'MEDIUM';
    }
    return 'LOW';
  }

  double _delayProbability(Shipment s) {
    final label = _riskLabel(s);
    if (label == 'HIGH') return 0.85;
    if (label == 'MEDIUM') return 0.45;
    return 0.10;
  }

  Color _riskColor(Shipment s) {
    switch (_riskLabel(s)) {
      case 'HIGH': return AppColors.warning;
      case 'MEDIUM': return AppColors.accentTan;
      default: return AppColors.accentMintDark;
    }
  }

  Color _statusColor(Shipment s) {
    switch (s.status) {
      case ShipmentStatus.inTransit: return AppColors.accentMint;
      case ShipmentStatus.delayed: return AppColors.warning;
      case ShipmentStatus.customs: return const Color(0xFFFFCC00);
      case ShipmentStatus.delivered: return AppColors.success;
      case ShipmentStatus.preparing: return AppColors.textTertiary;
    }
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
        title: Text(widget.shipmentId,
          style: GoogleFonts.inter(
            fontSize: 16, fontWeight: FontWeight.w700,
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
                color: AppColors.panelDark, strokeWidth: 2.5),
            );
          }
          final s = snap.data;
          if (s == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_off_rounded,
                      size: 48, color: AppColors.textTertiary),
                  const SizedBox(height: 12),
                  Text('Shipment not found',
                    style: GoogleFonts.inter(
                      fontSize: 15, color: AppColors.textTertiary),
                  ),
                ],
              ),
            );
          }
          return _body(s);
        },
      ),
    );
  }

  Widget _body(Shipment s) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingLg, 0, AppTheme.spacingLg, AppTheme.spacingXl,
      ),
      children: [
        _headerCard(s),
        const SizedBox(height: 16),
        _cargoCard(s),
        const SizedBox(height: 16),
        _routeIntelCard(s),
        const SizedBox(height: 16),
        _disruptionCard(s),
        const SizedBox(height: 16),
        _timelineCard(s),
        const SizedBox(height: 16),
        _recommendationCard(s),
        const SizedBox(height: 24),
        _actionButtons(s),
        const SizedBox(height: 32),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // 1. HEADER CARD
  // ─────────────────────────────────────────────────────────
  Widget _headerCard(Shipment s) {
    return Container(
      padding: const EdgeInsets.all(18),
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
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppColors.accentMint, letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              _pill(s.statusLabel, _statusColor(s)),
              const SizedBox(width: 6),
              RiskBadge(
                delayProbability: _delayProbability(s),
                riskLevel: _riskLabel(s),
                predictedDelayHours: s.delayHours > 0 ? s.delayHours.toDouble() : null,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(s.cargoDescription,
            style: GoogleFonts.inter(
              fontSize: 17, fontWeight: FontWeight.w700,
              color: AppColors.textOnDark,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: s.progress, minHeight: 5,
              backgroundColor: AppColors.panelDarkSoft,
              valueColor: AlwaysStoppedAnimation(_statusColor(s)),
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
                Flexible(
                  child: Text(s.currentLocation!,
                    style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w500,
                      color: AppColors.textOnDarkMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // 2. CARGO CARD
  // ─────────────────────────────────────────────────────────
  Widget _cargoCard(Shipment s) {
    return _whiteCard(
      icon: Icons.inventory_2_rounded,
      title: 'Cargo Details',
      child: Column(
        children: [
          _detailRow('Cargo', s.cargoDescription),
          _detailRow('Weight', '${(s.weightKg / 1000).toStringAsFixed(1)} tons'),
          _detailRow('Mode', s.modeLabel),
          _routeRow(s.origin, s.destination),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // 3. ROUTE INTELLIGENCE CARD
  // ─────────────────────────────────────────────────────────
  Widget _routeIntelCard(Shipment s) {
    final eta = '${s.estimatedArrival.day}/${s.estimatedArrival.month}/${s.estimatedArrival.year}';
    final costEstimate = '\$${(s.weightKg * 0.12).toStringAsFixed(0)}';

    return _whiteCard(
      icon: Icons.route_rounded,
      title: 'Route Intelligence',
      child: Column(
        children: [
          _detailRow('ETA', s.daysRemaining > 0 ? '$eta (${s.daysRemaining}d)' : eta),
          _detailRow('Est. Cost', costEstimate),
          _detailRow('Current Route',
              '${s.origin} → ${s.destination} via ${s.modeLabel}'),
          if (s.delayHours > 0)
            _detailRow('Predicted Delay', '+${s.delayHours}h',
                valueColor: AppColors.warning),
          _detailRow('Risk Level', _riskLabel(s),
              valueColor: _riskColor(s)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // 4. DISRUPTION RISKS CARD
  // ─────────────────────────────────────────────────────────
  Widget _disruptionCard(Shipment s) {
    // Generate contextual risks based on shipment state
    final risks = <_RiskItem>[];
    if (s.status == ShipmentStatus.delayed) {
      risks.add(_RiskItem('Port congestion at destination', 0.72,
          AppColors.warning));
    }
    if (s.mode == TransportMode.sea) {
      risks.add(_RiskItem('Weather disruption en route', 0.38,
          AppColors.accentPeach));
    }
    risks.add(_RiskItem('Customs clearance delay', 0.25,
        AppColors.accentTan));
    if (risks.length < 3) {
      risks.add(_RiskItem('Supply chain bottleneck', 0.15,
          AppColors.accentMintDark));
    }

    return _whiteCard(
      icon: Icons.warning_amber_rounded,
      title: 'Disruption Risks',
      child: Column(
        children: risks.take(3).map((r) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(r.label,
                      style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: r.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${(r.probability * 100).round()}%',
                      style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: r.color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: r.probability, minHeight: 4,
                  backgroundColor: AppColors.divider,
                  valueColor: AlwaysStoppedAnimation(r.color),
                ),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // 5. TIMELINE CARD
  // ─────────────────────────────────────────────────────────
  Widget _timelineCard(Shipment s) {
    final steps = <_TimelineStep>[
      _TimelineStep('Pickup at ${s.origin}', true,
          '${s.departureDate.day}/${s.departureDate.month}'),
      _TimelineStep('In Transit — ${s.modeLabel}',
          s.progress > 0.1, s.currentLocation ?? ''),
    ];

    if (s.delayHours > 0) {
      steps.add(_TimelineStep(
        'Risk: +${s.delayHours}h delay',
        s.status == ShipmentStatus.delayed, 'Monitoring',
      ));
    }

    steps.add(_TimelineStep(
      'Delivery at ${s.destination}',
      s.status == ShipmentStatus.delivered,
      '${s.estimatedArrival.day}/${s.estimatedArrival.month}',
    ));

    return _whiteCard(
      icon: Icons.timeline_rounded,
      title: 'Shipment Timeline',
      child: Column(
        children: List.generate(steps.length, (i) {
          final step = steps[i];
          final isLast = i == steps.length - 1;
          return _timelineRow(step, isLast);
        }),
      ),
    );
  }

  Widget _timelineRow(_TimelineStep step, bool isLast) {
    final dotColor = step.completed
        ? AppColors.accentMintDark
        : AppColors.divider;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vertical line + dot
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    border: step.completed
                        ? null
                        : Border.all(color: AppColors.textTertiary, width: 1.5),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: step.completed
                          ? AppColors.accentMintDark.withValues(alpha: 0.4)
                          : AppColors.divider,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.label,
                    style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: step.completed
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    ),
                  ),
                  if (step.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(step.subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w400,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // 6. AI PREDICTION CARD
  // ─────────────────────────────────────────────────────────
  Widget _recommendationCard(Shipment s) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.panelDark,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: AppColors.accentMint.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    size: 14, color: AppColors.accentMint),
              ),
              const SizedBox(width: 10),
              Text('AI Prediction Agent',
                style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppColors.accentMint,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              RiskBadge(
                delayProbability: _delayProbability(s),
                riskLevel: _riskLabel(s),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  '${(_delayProbability(s) * 100).round()}% Delay Probability',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textOnDark,
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'High risk due to port congestion (42%) + heavy rain forecast',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.textOnDarkMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _featurePill('Port congestion (42%)'),
              _featurePill('Heavy rain forecast (38%)'),
              _featurePill('Carrier score (15%)'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _featurePill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accentTan.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.panelDark,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // ACTION BUTTONS
  // ─────────────────────────────────────────────────────────
  Widget _actionButtons(Shipment s) {
    return Column(
      children: [
        // 1. Accept & Reroute (Big Mint Pill)
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _snack('Rerouting ${s.id} via alternate port...'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentMint,
              foregroundColor: AppColors.panelDark,
              elevation: 4,
              shadowColor: AppColors.shadow,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
            ),
            child: Text(
              'Accept & Reroute',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 2. Run Simulation (Able to re-call /predict when sliders change)
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              // TODO: implement re-call to /predict when sliders change in simulation
              context.go('/simulation');
            },
            icon: const Icon(Icons.science_rounded, size: 18),
            label: const Text('Run Simulation'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: AppColors.panelDark.withValues(alpha: 0.1), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
              foregroundColor: AppColors.panelDark,
              textStyle: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: GoogleFonts.inter(fontSize: 13)),
        backgroundColor: AppColors.panelDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ));
  }

  // ─────────────────────────────────────────────────────────
  // SHARED HELPERS
  // ─────────────────────────────────────────────────────────
  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
        style: GoogleFonts.inter(
          fontSize: 10, fontWeight: FontWeight.w700,
          color: color, letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _whiteCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
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
          Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: AppColors.panelDark.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 10),
              Text(title,
                style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
              style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w500,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(value,
              style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w500,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _routeRow(String origin, String destination) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text('Route',
              style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w500,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          const Icon(Icons.circle, size: 6,
              color: AppColors.accentMintDark),
          const SizedBox(width: 4),
          Flexible(
            child: Text(origin,
              style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.arrow_forward, size: 12,
                color: AppColors.textTertiary),
          ),
          Flexible(
            child: Text(destination,
              style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Private data classes ──────────────────────────────────
class _RiskItem {
  const _RiskItem(this.label, this.probability, this.color);
  final String label;
  final double probability;
  final Color color;
}

class _TimelineStep {
  const _TimelineStep(this.label, this.completed, this.subtitle);
  final String label;
  final bool completed;
  final String subtitle;
}
