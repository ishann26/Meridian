import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:meridian/core/theme/app_colors.dart';
import 'package:meridian/core/theme/app_theme.dart';
import 'package:meridian/data/models/shipment.dart';
import 'package:meridian/data/repositories/shipment_repository.dart';
import 'package:meridian/core/di/service_locator.dart';
import 'package:meridian/widgets/risk_badge.dart';

/// Risk Radar View — visually tracks live shipments on a map.
///
/// Shows dynamic risk markers, a floating action button,
/// and a soft charcoal bottom sheet for selected shipment intel.
class RiskRadarView extends StatefulWidget {
  const RiskRadarView({super.key});

  @override
  State<RiskRadarView> createState() => _RiskRadarViewState();
}

class _RiskRadarViewState extends State<RiskRadarView> with SingleTickerProviderStateMixin {
  final Completer<GoogleMapController> _controller = Completer();
  final ShipmentRepository _repo = ServiceLocator.instance.shipmentRepo;

  List<Shipment> _shipments = [];
  Shipment? _selectedShipment;
  bool _isLoading = true;

  // Pulse animation for high risk markers
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    
    // Animate alpha from 0.4 to 1.0 to create a pulsing effect
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final data = await _repo.getAll();
    if (!mounted) return;
    setState(() {
      // Just keep active shipments for the radar
      _shipments = data.where((s) => s.status == ShipmentStatus.inTransit || s.status == ShipmentStatus.delayed).toList();
      _isLoading = false;
    });
  }

  String _riskLabel(Shipment s) {
    if (s.status == ShipmentStatus.delayed && s.delayHours > 24) return 'HIGH';
    if (s.status == ShipmentStatus.delayed || s.status == ShipmentStatus.customs) return 'MEDIUM';
    return 'LOW';
  }

  double _getMarkerHue(String risk) {
    switch (risk) {
      case 'HIGH': return BitmapDescriptor.hueRed;
      case 'MEDIUM': return BitmapDescriptor.hueOrange;
      default: return 150.0; // Approximate mint/green hue
    }
  }

  Set<Marker> _buildMarkers() {
    return _shipments.map((s) {
      final risk = _riskLabel(s);
      
      // Mocking lat/lng based on ID hash since Shipment doesn't have coordinates
      final lat = 13.0 + (s.id.hashCode % 10) * 0.5;
      final lng = 80.0 + (s.id.hashCode % 15) * 0.5;

      return Marker(
        markerId: MarkerId(s.id),
        position: LatLng(lat, lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(_getMarkerHue(risk)),
        alpha: risk == 'HIGH' ? _pulseAnimation.value : 1.0,
        onTap: () {
          setState(() => _selectedShipment = s);
        },
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppColors.panelDark))
          : Stack(
              children: [
                // 1. Google Map (AnimatedBuilder rebuilds markers for the pulse effect)
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return GoogleMap(
                      initialCameraPosition: const CameraPosition(
                        target: LatLng(15.0, 80.0), // Center roughly on South Asia
                        zoom: 4.5,
                      ),
                      markers: _buildMarkers(),
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                      compassEnabled: false,
                      onMapCreated: (GoogleMapController controller) {
                        _controller.complete(controller);
                      },
                      onTap: (_) => setState(() => _selectedShipment = null),
                    );
                  },
                ),

                // 2. Header
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: AppTheme.spacingLg,
                  child: Row(
                    children: [
                      // Back button
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
                      // Title
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
    final riskLabel = _riskLabel(s);

    double delayProb = 0.10;
    if (riskLabel == 'HIGH') delayProb = 0.85;
    if (riskLabel == 'MEDIUM') delayProb = 0.45;

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
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STATUS',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textOnDarkMuted,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.statusLabel,
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textOnDark,
                      ),
                    ),
                  ],
                ),
              ),
              RiskBadge(
                delayProbability: delayProb,
                riskLevel: riskLabel,
                predictedDelayHours: s.delayHours > 0 ? s.delayHours.toDouble() : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
