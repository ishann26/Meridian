import 'package:flutter/material.dart';
import 'package:meridian/core/theme/app_colors.dart';
import 'package:meridian/shared/widgets/placeholder_screen.dart';

/// Shipments — tracking and management.
///
/// Will display active/completed shipments list with filters,
/// status timeline, and detailed shipment view.
class ShipmentsScreen extends StatelessWidget {
  const ShipmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Shipments',
      subtitle:
          'Track every package across road, rail, air, and sea. Filter, sort, and drill into real-time status.',
      icon: Icons.local_shipping_rounded,
      accentColor: AppColors.accentCream,
    );
  }
}
