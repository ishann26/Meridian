import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:meridian/core/theme/app_colors.dart';
import 'package:meridian/core/theme/app_theme.dart';
import 'package:meridian/widgets/risk_badge.dart';

// Sample Shipment data model for the view
class _SampleShipment {
  final String id;
  final String trackingCode;
  final String origin;
  final String destination;
  final String cargoDescription;
  final double lat;
  final double lng;
  final String riskLabel;
  final double delayProb;
  final double delayHours;

  _SampleShipment(this.id, this.trackingCode, this.origin, this.destination, this.cargoDescription, this.lat, this.lng, this.riskLabel, this.delayProb, this.delayHours);
}

/// Risk Radar View — visually tracks live shipments on a map using flutter_map.
class RiskRadarView extends StatefulWidget {
  const RiskRadarView({super.key});

  @override
  State<RiskRadarView> createState() => _RiskRadarViewState();
}

class _RiskRadarViewState extends State<RiskRadarView> with SingleTickerProviderStateMixin {
  late List<_SampleShipment> _shipments;
  _SampleShipment? _selectedShipment;

  // Pulse animation for high risk markers
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    // Animate alpha from 0.3 to 1.0 to create a pulsing effect
    _pulseAnimation = Tween<double>(begin: 0.1, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Hardcode 5 sample shipments around Chennai
    _shipments = [
      _SampleShipment('s1', 'SHP-842', 'Chennai Port', 'Delhi', 'Electronics', 13.0827, 80.2707, 'HIGH', 0.88, 42.5),
      _SampleShipment('s2', 'SHP-910', 'Ennore Port', 'Bangalore', 'Auto Parts', 13.2500, 80.3300, 'HIGH', 0.79, 28.0),
      _SampleShipment('s3', 'SHP-105', 'Chennai Hub', 'Mumbai', 'Textiles', 12.9800, 80.1500, 'MEDIUM', 0.45, 12.0),
      _SampleShipment('s4', 'SHP-223', 'Kattupalli', 'Hyderabad', 'Machinery', 13.3100, 80.3300, 'LOW', 0.10, 0.0),
      _SampleShipment('s5', 'SHP-551', 'Sriperumbudur', 'Pune', 'Pharmaceuticals', 12.9600, 79.9400, 'LOW', 0.05, 0.0),
    ];
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Marker _buildMapMarker(_SampleShipment s) {
    Color color;
    switch (s.riskLabel) {
      case 'HIGH': color = AppColors.error; break;
      case 'MEDIUM': color = AppColors.warning; break;
      default: color = AppColors.accentMint; break;
    }

    return Marker(
      point: LatLng(s.lat, s.lng),
      width: 60,
      height: 60,
      child: GestureDetector(
        onTap: () => setState(() => _selectedShipment = s),
        child: s.riskLabel == 'HIGH'
            ? AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: _pulseAnimation.value * 0.3),
                      border: Border.all(color: color.withValues(alpha: _pulseAnimation.value), width: 2),
                    ),
                    child: Center(
                      child: Container(
                        width: 16, height: 16,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [
                          BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 2)
                        ]),
                      ),
                    ),
                  );
                },
              )
            : Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.2),
                  border: Border.all(color: color.withValues(alpha: 0.8), width: 2),
                ),
                child: Center(
                  child: Container(
                    width: 14, height: 14,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Stack(
        children: [
          // 1. Flutter Map
          Positioned.fill(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: const LatLng(13.0827, 80.2707),
                initialZoom: 8.0,
                onTap: (tapPosition, point) => setState(() => _selectedShipment = null),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token=wvwhufooqvimxuomeybuwxajratxgggzgonh',
                  userAgentPackageName: 'com.example.meridian',
                  maxZoom: 18,
                ),
                MarkerLayer(
                  markers: _shipments.map((s) => _buildMapMarker(s)).toList(),
                ),
              ],
            ),
          ),

          // 2. Header
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: AppTheme.spacingLg,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      shape: BoxShape.circle,
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Text(
                    'Risk Radar',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Floating "Refresh Predictions" button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: AppTheme.spacingLg,
            child: GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Refreshing AI predictions...', style: GoogleFonts.inter()),
                    backgroundColor: AppColors.panelDark,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.accentMint,
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.panelDark),
                    const SizedBox(width: 8),
                    Text(
                      'Refresh Predictions',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.panelDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. Bottom Card for selected shipment
          if (_selectedShipment != null)
            Positioned(
              bottom: 32,
              left: AppTheme.spacingLg,
              right: AppTheme.spacingLg,
              child: _buildSelectedShipmentCard(),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectedShipmentCard() {
    final s = _selectedShipment!;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.panelDark,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.bgCard.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Text(
                  s.trackingCode,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textOnDark,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _selectedShipment = null),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, color: AppColors.textOnDarkMuted, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            s.cargoDescription,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textOnDark,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.route_rounded, size: 16, color: AppColors.textOnDarkMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${s.origin} → ${s.destination}',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textOnDarkMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              RiskBadge(
                delayProbability: s.delayProb,
                riskLevel: s.riskLabel,
                predictedDelayHours: s.delayHours > 0 ? s.delayHours : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  '${(s.delayProb * 100).round()}% Delay Probability',
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
          if (s.riskLabel == 'HIGH') ...[
            const SizedBox(height: 20),
            Text(
              'WHY HIGH RISK',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textOnDarkMuted,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'High risk due to port congestion (42%) + heavy rain forecast',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.textOnDarkMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _featurePill('Port congestion (42%)'),
                _featurePill('Heavy rain forecast (38%)'),
                _featurePill('Carrier score (15%)'),
              ],
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final id = s.id;
                  setState(() => _selectedShipment = null);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Rerouting $id via alternate port...', style: GoogleFonts.inter()),
                      backgroundColor: AppColors.panelDark,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
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
          ],
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
}
