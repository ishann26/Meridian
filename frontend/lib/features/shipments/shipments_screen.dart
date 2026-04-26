import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meridian/core/theme/app_colors.dart';
import 'package:meridian/core/theme/app_theme.dart';
import 'package:meridian/data/models/shipment.dart';
import 'package:meridian/data/repositories/shipment_repository.dart';
import 'package:meridian/core/di/service_locator.dart';
import 'package:meridian/features/shipments/widgets/shipment_card.dart';

/// Shipments — list of all cargo movements.
///
/// Loads from [ShipmentRepository], supports pull-to-refresh,
/// and adapts to single/two-column layouts.
class ShipmentsScreen extends StatefulWidget {
  const ShipmentsScreen({super.key});

  @override
  State<ShipmentsScreen> createState() => _ShipmentsScreenState();
}

class _ShipmentsScreenState extends State<ShipmentsScreen> {
  final ShipmentRepository _repo = ServiceLocator.instance.shipmentRepo;

  List<Shipment> _shipments = [];
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
      _shipments = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.panelDark, strokeWidth: 2.5,
                ),
              )
            : RefreshIndicator(
                onRefresh: _load,
                color: AppColors.panelDark,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 600;
                    return CustomScrollView(
                      slivers: [
                        // ── Header ──────────────────────────────
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppTheme.spacingLg, AppTheme.spacingLg,
                              AppTheme.spacingLg, AppTheme.spacingSm,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Shipments',
                                  style: GoogleFonts.inter(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_shipments.length} total · '
                                  '${_shipments.where((s) => s.status == ShipmentStatus.inTransit).length} in transit',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // ── Empty state ─────────────────────────
                        if (_shipments.isEmpty)
                          SliverFillRemaining(
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.inventory_2_rounded,
                                      size: 48, color: AppColors.textTertiary),
                                  const SizedBox(height: 12),
                                  Text('No shipments yet',
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (isWide)
                          // ── Two-column grid ───────────────────
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacingLg,
                              vertical: AppTheme.spacingSm,
                            ),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 1.55,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, i) => ShipmentCard(
                                  shipment: _shipments[i],
                                  onTap: () => _openDetail(_shipments[i].id),
                                ),
                                childCount: _shipments.length,
                              ),
                            ),
                          )
                        else
                          // ── Single-column list ────────────────
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacingLg,
                              vertical: AppTheme.spacingSm,
                            ),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, i) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: ShipmentCard(
                                    shipment: _shipments[i],
                                    onTap: () => _openDetail(_shipments[i].id),
                                  ),
                                ),
                                childCount: _shipments.length,
                              ),
                            ),
                          ),

                        // Bottom breathing room
                        const SliverToBoxAdapter(
                          child: SizedBox(height: AppTheme.spacingXl),
                        ),
                      ],
                    );
                  },
                ),
              ),
      ),
    );
  }

  void _openDetail(String id) {
    context.push('/shipments/$id');
  }
}
