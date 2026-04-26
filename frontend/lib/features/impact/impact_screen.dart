import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meridian/core/theme/app_colors.dart';
import 'package:meridian/core/theme/app_theme.dart';
import 'package:meridian/data/models/impact_metric.dart';
import 'package:meridian/data/repositories/impact_repository.dart';
import 'package:meridian/core/di/service_locator.dart';

/// Impact — sustainability & performance analytics dashboard.
///
/// Loads metrics from [ImpactRepository] and displays them as
/// progress rings, trend cards, comparison bars, and a national
/// impact highlight panel.
class ImpactScreen extends StatefulWidget {
  const ImpactScreen({super.key});

  @override
  State<ImpactScreen> createState() => _ImpactScreenState();
}

class _ImpactScreenState extends State<ImpactScreen> {
  final ImpactRepository _repo = ServiceLocator.instance.impactRepo;

  List<ImpactMetric> _metrics = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final data = await _repo.getAll();
    if (!mounted) return;
    setState(() {
      _metrics = data;
      _isLoading = false;
    });
  }

  // Quick lookups
  ImpactMetric? _find(String id) {
    try {
      return _metrics.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.panelDark, strokeWidth: 2.5),
              )
            : RefreshIndicator(
                onRefresh: _load,
                color: AppColors.panelDark,
                child: ListView(
                  padding: const EdgeInsets.all(AppTheme.spacingLg),
                  children: [
                    // ── Header ──────────────────────────────
                    Text('Impact Report',
                      style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('How Meridian improves logistics efficiency',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textTertiary,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Hero metric rings ───────────────────
                    if (_metrics.isNotEmpty) _heroRings(),

                    const SizedBox(height: 20),

                    // ── Trend cards ─────────────────────────
                    ..._metrics.map((m) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _trendCard(m),
                    )),

                    const SizedBox(height: 8),

                    // ── National impact panel ───────────────
                    _nationalImpactPanel(),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // HERO PROGRESS RINGS (top 2 metrics)
  // ─────────────────────────────────────────────────────────
  Widget _heroRings() {
    final carbon = _find('IMP-001');
    final fleet = _find('IMP-004');

    return Row(
      children: [
        if (carbon != null)
          Expanded(child: _ringCard(carbon, AppColors.accentMintDark)),
        const SizedBox(width: 12),
        if (fleet != null)
          Expanded(child: _ringCard(fleet, AppColors.accentTan)),
      ],
    );
  }

  Widget _ringCard(ImpactMetric m, Color accent) {
    final progress = m.target != null
        ? (m.value / m.target!).clamp(0.0, 1.0)
        : 0.75;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          SizedBox(
            width: 80, height: 80,
            child: CustomPaint(
              painter: _RingPainter(
                progress: progress,
                color: accent,
                bgColor: AppColors.divider,
                strokeWidth: 6,
              ),
              child: Center(
                child: Text(
                  m.unit == '%'
                      ? '${m.value.round()}%'
                      : m.value.toStringAsFixed(1),
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(m.label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          _trendBadge(m),
          if (m.target != null) ...[
            const SizedBox(height: 6),
            Text('Target: ${m.target!.round()} ${m.unit}',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // TREND CARD (each metric)
  // ─────────────────────────────────────────────────────────
  Widget _trendCard(ImpactMetric m) {
    final accent = _accentFor(m.category);
    final progress = m.target != null
        ? (m.value / m.target!).clamp(0.0, 1.0)
        : 0.75;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: icon + label + trend badge
          Row(
            children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(_iconFor(m.category),
                    size: 15, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.label,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(m.period,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              _trendBadge(m),
            ],
          ),

          const SizedBox(height: 14),

          // Value row
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _formatValue(m),
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Text(m.unit,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Progress bar toward target
          if (m.target != null) ...[
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor: AppColors.divider,
                      valueColor: AlwaysStoppedAnimation(accent),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${(progress * 100).round()}%',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              m.isOnTarget ? 'On track to target' : 'Below target',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: m.isOnTarget
                    ? AppColors.accentMintDark
                    : AppColors.warning,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // NATIONAL LOGISTICS IMPACT PANEL
  // ─────────────────────────────────────────────────────────
  Widget _nationalImpactPanel() {
    return Container(
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
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: AppColors.accentMint.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.public_rounded,
                    size: 15, color: AppColors.accentMint),
              ),
              const SizedBox(width: 10),
              Text('National Logistics Impact',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentMint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Projected impact if Meridian scales across India\'s logistics network',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppColors.textOnDarkMuted,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 20),

          // Stats row
          Row(
            children: [
              _nationalStat('14%', 'cost\nreduction', AppColors.accentMint),
              const SizedBox(width: 12),
              _nationalStat('2.1M', 'tons CO₂\nsaved/yr', AppColors.accentPeach),
              const SizedBox(width: 12),
              _nationalStat('22%', 'faster\ndelivery', AppColors.accentTan),
            ],
          ),

          const SizedBox(height: 20),

          // Comparison bars
          _comparisonBar('Logistics Cost / GDP', 0.14, 0.08,
              'India avg', 'With Meridian'),
          const SizedBox(height: 14),
          _comparisonBar('Avg Delivery Time', 0.60, 0.35,
              '8.5 days', '5.2 days'),
          const SizedBox(height: 14),
          _comparisonBar('Carbon Intensity', 0.55, 0.30,
              'Current', 'Optimized'),
        ],
      ),
    );
  }

  Widget _nationalStat(String value, String label, Color accent) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
            style: GoogleFonts.inter(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.textOnDarkMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _comparisonBar(
    String label,
    double before,
    double after,
    String beforeLabel,
    String afterLabel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textOnDarkMuted,
          ),
        ),
        const SizedBox(height: 6),
        // Before bar
        Row(
          children: [
            SizedBox(
              width: 70,
              child: Text(beforeLabel,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textOnDarkMuted,
                ),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: before, minHeight: 6,
                  backgroundColor: AppColors.panelDarkSoft,
                  valueColor: const AlwaysStoppedAnimation(
                      AppColors.accentPeach),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // After bar
        Row(
          children: [
            SizedBox(
              width: 70,
              child: Text(afterLabel,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppColors.accentMint,
                ),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: after, minHeight: 6,
                  backgroundColor: AppColors.panelDarkSoft,
                  valueColor: const AlwaysStoppedAnimation(
                      AppColors.accentMint),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // SHARED HELPERS
  // ─────────────────────────────────────────────────────────
  Widget _trendBadge(ImpactMetric m) {
    final isPositive = _isPositiveTrend(m);
    final color = isPositive ? AppColors.accentMintDark : AppColors.warning;
    final icon = m.trend == MetricTrend.up
        ? Icons.trending_up_rounded
        : m.trend == MetricTrend.down
            ? Icons.trending_down_rounded
            : Icons.trending_flat_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(m.changeLabel,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// For carbon/cost/time, "down" is good. For efficiency/reliability, "up" is good.
  bool _isPositiveTrend(ImpactMetric m) {
    switch (m.category) {
      case ImpactCategory.carbon:
      case ImpactCategory.cost:
      case ImpactCategory.time:
        return m.trend == MetricTrend.down;
      case ImpactCategory.efficiency:
      case ImpactCategory.reliability:
        return m.trend == MetricTrend.up || m.trend == MetricTrend.flat;
    }
  }

  String _formatValue(ImpactMetric m) {
    if (m.value >= 100000) {
      return '\$${(m.value / 1000).round()}k';
    }
    if (m.value >= 1000) {
      return m.value.round().toString();
    }
    if (m.unit == '%') {
      return m.value.toStringAsFixed(1);
    }
    return m.value.toStringAsFixed(1);
  }

  Color _accentFor(ImpactCategory cat) {
    switch (cat) {
      case ImpactCategory.carbon: return AppColors.accentMintDark;
      case ImpactCategory.cost: return AppColors.accentTan;
      case ImpactCategory.time: return AppColors.accentPeach;
      case ImpactCategory.efficiency: return AppColors.accentMint;
      case ImpactCategory.reliability: return AppColors.info;
    }
  }

  IconData _iconFor(ImpactCategory cat) {
    switch (cat) {
      case ImpactCategory.carbon: return Icons.eco_rounded;
      case ImpactCategory.cost: return Icons.savings_rounded;
      case ImpactCategory.time: return Icons.schedule_rounded;
      case ImpactCategory.efficiency: return Icons.speed_rounded;
      case ImpactCategory.reliability: return Icons.verified_rounded;
    }
  }
}

// ─────────────────────────────────────────────────────────
// CUSTOM RING PAINTER
// ─────────────────────────────────────────────────────────
class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.bgColor,
    this.strokeWidth = 6,
  });

  final double progress;
  final Color color;
  final Color bgColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - strokeWidth;
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    // Background ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = bgColor,
    );

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color;
}
