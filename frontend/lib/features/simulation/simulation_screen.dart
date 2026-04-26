import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meridian/core/theme/app_colors.dart';
import 'package:meridian/core/theme/app_theme.dart';
import 'package:meridian/data/models/simulation_result.dart';
import 'package:meridian/data/repositories/simulation_repository.dart';
import 'package:meridian/data/services/mock_simulation_service.dart';

/// Simulation — compare current plan vs AI-optimized route.
///
/// Runs a what-if scenario via [SimulationRepository] and displays
/// side-by-side route cards plus a savings summary panel.
class SimulationScreen extends StatefulWidget {
  const SimulationScreen({super.key});

  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> {
  final SimulationRepository _repo = MockSimulationService();

  SimulationResult? _result;
  bool _isLoading = false;
  bool _hasRun = false;

  // ── Static route data for comparison cards ───────────────
  static const _current = _RouteData(
    label: 'Current Plan',
    waypoints: ['Mumbai', 'Chennai Port', 'Delhi'],
    hours: 42,
    costRupees: 80000,
    risk: 'HIGH',
    co2Kg: 210,
  );

  static const _optimized = _RouteData(
    label: 'AI Optimized',
    waypoints: ['Mumbai', 'Nagpur Rail Hub', 'Delhi'],
    hours: 36,
    costRupees: 72000,
    risk: 'LOW',
    co2Kg: 180,
  );

  Future<void> _runSimulation() async {
    setState(() => _isLoading = true);

    final result = await _repo.runSimulation(const SimulationInput(
      scenario: ScenarioType.routeBlockage,
      affectedNode: 'Chennai Port',
      durationDays: 3,
      severityMultiplier: 1.5,
    ));

    if (!mounted) return;
    setState(() {
      _result = result;
      _isLoading = false;
      _hasRun = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          children: [
            // ── Header ──────────────────────────────────────
            Text(
              'Route Simulation',
              style: GoogleFonts.inter(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Compare current plan with Meridian's optimized route",
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.textTertiary,
              ),
            ),

            const SizedBox(height: 24),

            // ── Current route card ──────────────────────────
            _routeCard(_current, isOptimized: false),

            const SizedBox(height: 14),

            // ── VS divider ──────────────────────────────────
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('VS',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ── Optimized route card ────────────────────────
            _routeCard(_optimized, isOptimized: true),

            const SizedBox(height: 24),

            // ── Savings summary panel ───────────────────────
            _savingsPanel(),

            const SizedBox(height: 20),

            // ── Run Simulation button ───────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _runSimulation,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textOnDark,
                        ),
                      )
                    : const Icon(Icons.science_rounded, size: 18),
                label: Text(_hasRun ? 'Run Again' : 'Run Simulation'),
              ),
            ),

            // ── Simulation result (if run) ──────────────────
            if (_result != null) ...[
              const SizedBox(height: 24),
              _simulationResultCard(_result!),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // ROUTE CARD
  // ─────────────────────────────────────────────────────────
  Widget _routeCard(_RouteData route, {required bool isOptimized}) {
    final riskColor = _riskColor(route.risk);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isOptimized ? AppColors.panelDark : AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: isOptimized ? AppTheme.elevatedShadow : AppTheme.cardShadow,
        border: isOptimized
            ? Border.all(
                color: AppColors.accentMint.withValues(alpha: 0.3),
                width: 1.5,
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              if (isOptimized) ...[
                Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.accentMint.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded,
                      size: 13, color: AppColors.accentMint),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                route.label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isOptimized
                      ? AppColors.textOnDark
                      : AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              _pill(route.risk, riskColor, isOptimized),
            ],
          ),

          const SizedBox(height: 14),

          // Waypoints
          _waypointRow(route.waypoints, isOptimized),

          const SizedBox(height: 16),

          // Stats grid
          Row(
            children: [
              _statItem(
                '${route.hours}',
                'hrs',
                Icons.schedule_rounded,
                isOptimized,
              ),
              const SizedBox(width: 12),
              _statItem(
                '₹${(route.costRupees / 1000).round()}k',
                'cost',
                Icons.currency_rupee_rounded,
                isOptimized,
              ),
              const SizedBox(width: 12),
              _statItem(
                '${route.co2Kg}',
                'kg CO₂',
                Icons.eco_rounded,
                isOptimized,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _waypointRow(List<String> waypoints, bool isDark) {
    final dotColor = isDark ? AppColors.accentMint : AppColors.accentMintDark;
    final lineColor = isDark
        ? AppColors.panelDarkSoft
        : AppColors.divider;
    final textColor = isDark
        ? AppColors.textOnDarkMuted
        : AppColors.textSecondary;

    return Row(
      children: [
        for (int i = 0; i < waypoints.length; i++) ...[
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: i == 0 || i == waypoints.length - 1
                  ? dotColor
                  : (isDark ? AppColors.accentTan : AppColors.accentPeach),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              waypoints[i],
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (i < waypoints.length - 1) ...[
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 1.5,
                decoration: BoxDecoration(
                  color: lineColor,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ],
    );
  }

  Widget _statItem(
    String value,
    String label,
    IconData icon,
    bool isDark,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.panelDarkAlt
              : AppColors.bgSecondary.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 14,
              color: isDark ? AppColors.accentMint : AppColors.textTertiary,
            ),
            const SizedBox(height: 4),
            Text(value,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
              ),
            ),
            Text(label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.textOnDarkMuted
                    : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // SAVINGS SUMMARY PANEL
  // ─────────────────────────────────────────────────────────
  Widget _savingsPanel() {
    const timeSaved = 6;
    const costSaved = 8000;
    const co2Saved = 30;

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
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: AppColors.accentMint.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.trending_up_rounded,
                    size: 14, color: AppColors.accentMint),
              ),
              const SizedBox(width: 10),
              Text('Optimization Savings',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentMint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              _savingStat('$timeSaved', 'hrs saved', AppColors.accentMint),
              const SizedBox(width: 12),
              _savingStat(
                  '₹${(costSaved / 1000).round()}k', 'saved', AppColors.accentTan),
              const SizedBox(width: 12),
              _savingStat('$co2Saved', 'kg CO₂ cut', AppColors.accentPeach),
            ],
          ),
        ],
      ),
    );
  }

  Widget _savingStat(String value, String label, Color accent) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textOnDarkMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // SIMULATION RESULT CARD (after running)
  // ─────────────────────────────────────────────────────────
  Widget _simulationResultCard(SimulationResult r) {
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
          Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: AppColors.panelDark.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.analytics_rounded,
                    size: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 10),
              Text('Simulation Result',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              _pill(r.input.scenarioLabel, AppColors.accentTan, false),
            ],
          ),
          const SizedBox(height: 14),

          _resultRow('Scenario', r.input.scenarioLabel),
          _resultRow('Affected', r.input.affectedNode),
          _resultRow('Duration', '${r.input.durationDays} days'),
          _resultRow('Cost Impact',
              '+${r.costImpactPercent.toStringAsFixed(1)}%',
              valueColor: AppColors.warning),
          _resultRow('Delay Increase',
              '+${r.delayIncreaseDays.toStringAsFixed(1)} days',
              valueColor: AppColors.warning),
          _resultRow('Shipments Affected', '${r.shipmentsAffected}'),

          const SizedBox(height: 12),

          // Mitigation
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accentMint.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Mitigation',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentMintDark,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(r.mitigationSuggestion,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // SHARED HELPERS
  // ─────────────────────────────────────────────────────────
  Widget _pill(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.20 : 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Color _riskColor(String risk) {
    switch (risk) {
      case 'HIGH':
        return AppColors.warning;
      case 'MEDIUM':
        return AppColors.accentTan;
      default:
        return AppColors.accentMintDark;
    }
  }
}

// ─────────────────────────────────────────────────────────
// DATA CLASS
// ─────────────────────────────────────────────────────────
class _RouteData {
  const _RouteData({
    required this.label,
    required this.waypoints,
    required this.hours,
    required this.costRupees,
    required this.risk,
    required this.co2Kg,
  });
  final String label;
  final List<String> waypoints;
  final int hours;
  final int costRupees;
  final String risk;
  final int co2Kg;
}
