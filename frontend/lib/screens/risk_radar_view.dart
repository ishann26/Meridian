import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:meridian/core/theme/app_colors.dart';

// ══════════════════════════════════════════════════════════════════════════════
// RISK RADAR VIEW
// flutter_map + standard OpenStreetMap tiles (no token, no auth required).
// ══════════════════════════════════════════════════════════════════════════════

class RiskRadarView extends StatefulWidget {
  const RiskRadarView({super.key});

  @override
  State<RiskRadarView> createState() => _RiskRadarViewState();
}

class _RiskRadarViewState extends State<RiskRadarView> {
  // ── Sample data ────────────────────────────────────────────────────────────
  static const List<_ShipmentRisk> _shipments = [
    _ShipmentRisk(
      id: 'SHP-1024',
      point: LatLng(13.0827, 80.2707),
      risk: RiskLevel.high,
      title: 'Chennai Port Delay',
      explanation:
          'High congestion and weather disruption risk detected near Chennai '
          'port. Cyclone advisory issued for coastal routes.',
      features: ['Port congestion', 'Cyclone risk', 'ETA drift'],
    ),
    _ShipmentRisk(
      id: 'SHP-1041',
      point: LatLng(12.9716, 80.2206),
      risk: RiskLevel.medium,
      title: 'OMR Cargo Corridor',
      explanation:
          'Moderate delay probability due to road congestion and high cargo '
          'density along the OMR hub.',
      features: ['Traffic load', 'Road delay', 'Queue time'],
    ),
    _ShipmentRisk(
      id: 'SHP-1088',
      point: LatLng(13.6288, 79.4192),
      risk: RiskLevel.low,
      title: 'Tirupati Route',
      explanation:
          'Route is currently stable with low disruption probability. '
          'No adverse weather or traffic events predicted.',
      features: ['Clear route', 'Low delay', 'Stable ETA'],
    ),
    _ShipmentRisk(
      id: 'SHP-1102',
      point: LatLng(12.9165, 79.1325),
      risk: RiskLevel.medium,
      title: 'Vellore Hub',
      explanation:
          'Moderate risk due to predicted regional traffic buildup and '
          'an incoming weather watch for the district.',
      features: ['Hub load', 'Weather watch', 'ETA variance'],
    ),
    _ShipmentRisk(
      id: 'SHP-1120',
      point: LatLng(11.0168, 76.9558),
      risk: RiskLevel.low,
      title: 'Coimbatore Transfer',
      explanation:
          'Shipment movement is healthy with no major disruption predicted. '
          'Transfer hub is operating at normal throughput.',
      features: ['Good speed', 'Low risk', 'Clear hub'],
    ),
  ];

  // ── Actions ────────────────────────────────────────────────────────────────
  void _showMarkerSheet(_ShipmentRisk s) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      isScrollControlled: true,
      builder: (_) => _ShipmentSheet(shipment: s),
    );
  }

  void _onRefresh() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Predictions refreshed',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.panelDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────
              _Header(),
              const SizedBox(height: 18),

              // ── Map card ────────────────────────────────────
              Expanded(
                child: _MapCard(
                  shipments: _shipments,
                  onMarkerTap: _showMarkerSheet,
                  onRefresh: _onRefresh,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// HEADER
// ══════════════════════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Back button
            GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.panelDark.withValues(alpha: 0.07),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 17,
                  color: AppColors.panelDark,
                ),
              ),
            ),
            const SizedBox(width: 14),
            const Text(
              'Risk Radar',
              style: TextStyle(
                color: AppColors.panelDark,
                fontSize: 36,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 54),
          child: Text(
            'Live disruption view · Chennai region',
            style: TextStyle(
              color: AppColors.panelDark.withValues(alpha: 0.48),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MAP CARD  (the main interactive widget)
// ══════════════════════════════════════════════════════════════════════════════

class _MapCard extends StatelessWidget {
  final List<_ShipmentRisk> shipments;
  final ValueChanged<_ShipmentRisk> onMarkerTap;
  final VoidCallback onRefresh;

  const _MapCard({
    required this.shipments,
    required this.onMarkerTap,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: Stack(
        children: [
          // ── flutter_map ──────────────────────────────────────
          FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(13.0827, 80.2707),
              initialZoom: 8.0,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              // OpenStreetMap tiles — free, no token required.
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.meridian',
              ),

              // Markers
              MarkerLayer(
                markers: shipments.map((s) {
                  return Marker(
                    point: s.point,
                    width: 64,
                    height: 64,
                    child: GestureDetector(
                      onTap: () => onMarkerTap(s),
                      child: s.risk == RiskLevel.high
                          ? _PulsingMarker(color: _riskColor(s.risk))
                          : _StaticMarker(s: s),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // ── Refresh button (top-right) ───────────────────────
          Positioned(
            top: 14,
            right: 14,
            child: _RefreshPill(onTap: onRefresh),
          ),

          // ── Legend (bottom-left) ─────────────────────────────
          const Positioned(
            left: 14,
            bottom: 14,
            child: _Legend(),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARKERS
// ══════════════════════════════════════════════════════════════════════════════

class _StaticMarker extends StatelessWidget {
  final _ShipmentRisk s;
  const _StaticMarker({required this.s});

  @override
  Widget build(BuildContext context) {
    final color = _riskColor(s.risk);
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.45),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            s.risk == RiskLevel.medium
                ? Icons.timelapse_rounded
                : Icons.local_shipping_rounded,
            size: 15,
            color: s.risk == RiskLevel.low
                ? AppColors.panelDark
                : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _PulsingMarker extends StatefulWidget {
  final Color color;
  const _PulsingMarker({required this.color});

  @override
  State<_PulsingMarker> createState() => _PulsingMarkerState();
}

class _PulsingMarkerState extends State<_PulsingMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _scale = Tween<double>(begin: 0.8, end: 1.9).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _opacity = Tween<double>(begin: 0.50, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing halo
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Transform.scale(
            scale: _scale.value,
            child: Opacity(
              opacity: _opacity.value,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
          ),
        ),
        // Solid core
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.50),
                blurRadius: 18,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(
            Icons.warning_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// REFRESH PILL
// ══════════════════════════════════════════════════════════════════════════════

class _RefreshPill extends StatelessWidget {
  final VoidCallback onTap;
  const _RefreshPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.accentMint,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentMintDark.withValues(alpha: 0.38),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.refresh_rounded, size: 17, color: AppColors.panelDark),
            SizedBox(width: 7),
            Text(
              'Refresh Predictions',
              style: TextStyle(
                color: AppColors.panelDark,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// LEGEND
// ══════════════════════════════════════════════════════════════════════════════

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.panelDark.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dot(AppColors.accentMint),
          const SizedBox(width: 5),
          _lbl('Low'),
          const SizedBox(width: 11),
          _dot(const Color(0xFFFFB347)),
          const SizedBox(width: 5),
          _lbl('Medium'),
          const SizedBox(width: 11),
          _dot(AppColors.error),
          const SizedBox(width: 5),
          _lbl('High'),
        ],
      ),
    );
  }

  static Widget _dot(Color c) => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );

  static Widget _lbl(String t) => Text(
        t,
        style: const TextStyle(
          color: AppColors.textOnDarkMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// BOTTOM SHEET
// ══════════════════════════════════════════════════════════════════════════════

class _ShipmentSheet extends StatelessWidget {
  final _ShipmentRisk shipment;
  const _ShipmentSheet({required this.shipment});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 14),
      decoration: BoxDecoration(
        color: AppColors.panelDark,
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 36,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Drag handle ───────────────────────────────────
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(top: 8, bottom: 22),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),

            // ── Badge + ID ────────────────────────────────────
            Row(
              children: [
                RadarRiskBadge(level: shipment.risk),
                const Spacer(),
                Text(
                  shipment.id,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Title ─────────────────────────────────────────
            Text(
              shipment.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 10),

            // ── Explanation ───────────────────────────────────
            Text(
              shipment.explanation,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 14.5,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 20),

            // ── Features label ────────────────────────────────
            Text(
              'TOP RISK FEATURES',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),

            // ── Feature pills ─────────────────────────────────
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: shipment.features
                  .map(
                    (f) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 9),
                      decoration: BoxDecoration(
                        color: AppColors.accentCream.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.accentCream.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Text(
                        f,
                        style: const TextStyle(
                          color: AppColors.accentCream,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 26),

            // ── CTA ───────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentMint,
                  foregroundColor: AppColors.panelDark,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: const Text(
                  'Accept & Reroute',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// RISK BADGE  (exported — used by bottom sheet)
// ══════════════════════════════════════════════════════════════════════════════

class RadarRiskBadge extends StatelessWidget {
  final RiskLevel level;
  const RadarRiskBadge({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    final color = _riskColor(level);
    final label = switch (level) {
      RiskLevel.low => 'LOW RISK',
      RiskLevel.medium => 'MEDIUM RISK',
      RiskLevel.high => 'HIGH RISK',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: level == RiskLevel.low ? AppColors.panelDark : Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DATA MODEL + HELPERS
// ══════════════════════════════════════════════════════════════════════════════

enum RiskLevel { low, medium, high }

class _ShipmentRisk {
  final String id;
  final LatLng point;
  final RiskLevel risk;
  final String title;
  final String explanation;
  final List<String> features;

  const _ShipmentRisk({
    required this.id,
    required this.point,
    required this.risk,
    required this.title,
    required this.explanation,
    required this.features,
  });
}

Color _riskColor(RiskLevel level) => switch (level) {
      RiskLevel.low => AppColors.accentMint,
      RiskLevel.medium => const Color(0xFFFFB347), // soft orange
      RiskLevel.high => AppColors.error,            // soft red
    };
