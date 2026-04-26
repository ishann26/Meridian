import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meridian/core/theme/app_colors.dart';
import 'package:meridian/core/theme/app_theme.dart';
import 'package:meridian/data/models/risk_alert.dart';
import 'package:meridian/data/models/shipment.dart';
import 'package:meridian/data/repositories/shipment_repository.dart';
import 'package:meridian/data/repositories/risk_alert_repository.dart';
import 'package:meridian/core/di/service_locator.dart';
import 'package:meridian/features/command_center/widgets/metric_pill.dart';
import 'package:meridian/features/command_center/widgets/route_map_card.dart';
import 'package:meridian/features/command_center/widgets/risk_alert_card.dart';
import 'package:meridian/features/command_center/widgets/ai_recommendation_card.dart';
import 'package:meridian/shared/widgets/section_header.dart';
import 'package:meridian/widgets/fleet_impact_forecaster.dart';
import 'package:meridian/screens/risk_radar_view.dart';

/// Command Center — the main dashboard.
///
/// Displays live KPIs, an active route map, risk alerts,
/// and an AI recommendation card. All data comes from
/// repository interfaces backed by mock services.
class CommandCenterScreen extends StatefulWidget {
  const CommandCenterScreen({super.key});

  @override
  State<CommandCenterScreen> createState() => _CommandCenterScreenState();
}

class _CommandCenterScreenState extends State<CommandCenterScreen> {
  final ShipmentRepository _shipmentRepo = ServiceLocator.instance.shipmentRepo;
  final RiskAlertRepository _riskAlertRepo = ServiceLocator.instance.riskAlertRepo;

  List<Shipment> _shipments = [];
  List<RiskAlert> _alerts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      _shipmentRepo.getAll(),
      _riskAlertRepo.getAll(),
    ]);

    if (!mounted) return;
    setState(() {
      _shipments = results[0] as List<Shipment>;
      _alerts = results[1] as List<RiskAlert>;
      _isLoading = false;
    });
  }

  // ── Computed KPIs ──────────────────────────────────────────
  int get _activeCount => _shipments
      .where((s) =>
          s.status == ShipmentStatus.inTransit ||
          s.status == ShipmentStatus.delayed)
      .length;

  int get _highRiskCount => _alerts
      .where((a) =>
          a.severity == RiskSeverity.high ||
          a.severity == RiskSeverity.critical)
      .length;

  String get _delayRisk {
    final delayed =
        _shipments.where((s) => s.status == ShipmentStatus.delayed).length;
    if (_shipments.isEmpty) return '0%';
    return '${((delayed / _shipments.length) * 100).round()}%';
  }

  String get _costSaved => '\$18.2k'; // Mock static value for now.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.panelDark,
                  strokeWidth: 2.5,
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadData,
                color: AppColors.panelDark,
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingLg,
                  ),
                  children: [
                    const SizedBox(height: AppTheme.spacingLg),

                    // ── Branding ────────────────────────────────
                    _buildHeader(),

                    const SizedBox(height: AppTheme.spacingLg),

                    // ── KPI Metric pills ────────────────────────
                    _buildMetricStrip(),

                    const SizedBox(height: AppTheme.spacingXl),

                    // ── Open Risk Radar Button ──────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const RiskRadarView()),
                          );
                        },
                        icon: const Icon(Icons.radar_rounded, size: 20),
                        label: Text('Open Risk Radar', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
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
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacingXl),

                    // ── Route map ───────────────────────────────
                    const RouteMapCard(),

                    const SizedBox(height: AppTheme.spacingXl),

                    // ── Fleet Impact Forecaster ─────────────────
                    const FleetImpactForecaster(),

                    const SizedBox(height: AppTheme.spacingXl),

                    // ── AI Recommendation ───────────────────────
                    const SectionHeader(title: 'AI Recommendation'),
                    const AiRecommendationCard(
                      title: 'Reroute SHP-001 via Antwerp',
                      recommendation:
                          'Port of Rotterdam is experiencing 40% longer dwell '
                          'times due to labor shortages. Diverting to Antwerp '
                          '(120km south) with last-mile road transport saves '
                          '~2 days and avoids the congestion surcharge.',
                      impact: 'Saves ~2 days · Avoids \$4.8k surcharge',
                    ),

                    const SizedBox(height: AppTheme.spacingXl),

                    // ── Risk Alerts ─────────────────────────────
                    SectionHeader(
                      title: 'Risk Alerts',
                      trailing: '${_alerts.length} active ›',
                    ),
                    ..._alerts.map(
                      (alert) => Padding(
                        padding: const EdgeInsets.only(
                            bottom: AppTheme.spacingSm + 4),
                        child: RiskAlertCard(alert: alert),
                      ),
                    ),

                    // Bottom breathing room for nav bar.
                    const SizedBox(height: AppTheme.spacingXl),
                  ],
                ),
              ),
      ),
    );
  }

  /// App title + subtitle header.
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Logo dot cluster
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.accentMint,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 3),
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.accentTan,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Text(
              'Meridian',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 30),
          child: Text(
            'AI logistics copilot for predictive routing',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }

  /// Horizontal scrollable metric strip.
  Widget _buildMetricStrip() {
    return SizedBox(
      height: 90,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          MetricPill(
            label: 'Active',
            value: '$_activeCount',
            unit: 'shipments',
            icon: Icons.local_shipping_rounded,
            accentColor: AppColors.accentMint,
          ),
          const SizedBox(width: 12),
          MetricPill(
            label: 'High Risk',
            value: '$_highRiskCount',
            unit: 'routes',
            icon: Icons.warning_rounded,
            accentColor: AppColors.warning,
          ),
          const SizedBox(width: 12),
          MetricPill(
            label: 'Delay Risk',
            value: _delayRisk,
            icon: Icons.schedule_rounded,
            accentColor: AppColors.accentPeach,
          ),
          const SizedBox(width: 12),
          MetricPill(
            label: 'Cost Saved',
            value: _costSaved,
            icon: Icons.savings_rounded,
            accentColor: AppColors.accentTan,
          ),
        ],
      ),
    );
  }
}
