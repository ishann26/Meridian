import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:meridian/core/theme/app_colors.dart';

/// Responsive shell scaffold that wraps all tab screens.
///
/// - Mobile: Floating rounded charcoal bottom nav.
/// - Desktop/Tablet: Slim charcoal left sidebar.
///
/// Uses [StatefulNavigationShell] from GoRouter to preserve
/// each tab's navigation state independently.
class SlcShell extends StatelessWidget {
  const SlcShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 768;

        if (isDesktop) {
          return Scaffold(
            backgroundColor: AppColors.bgPrimary,
            body: Row(
              children: [
                _buildSidebar(context),
                Expanded(child: navigationShell),
              ],
            ),
          );
        } else {
          return Scaffold(
            backgroundColor: AppColors.bgPrimary,
            body: navigationShell,
            // extendBody: true makes the content scroll behind the floating nav,
            // but we must ensure content has bottom padding so it's not permanently covered.
            // Using extendBody: false ensures content naturally stops above the floating nav.
            // We'll use extendBody: true to give that premium floating feel,
            // but we'll wrap the bottom nav in an invisible container that "lifts" it.
            // Actually, the simplest, safest way that guarantees no coverage is extendBody: false.
            // It will simply paint the scaffold background color behind the floating pill.
            bottomNavigationBar: _buildMobileNav(context),
          );
        }
      },
    );
  }

  Widget _buildMobileNav(BuildContext context) {
    // A transparent container wrapping the floating pill.
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.panelDark,
            borderRadius: BorderRadius.circular(100), // Pill shape
            boxShadow: [
              BoxShadow(
                color: AppColors.panelDark.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MobileNavItem(
                icon: Icons.dashboard_rounded,
                label: 'Command',
                index: 0,
                currentIndex: navigationShell.currentIndex,
                onTap: _onTap,
              ),
              _MobileNavItem(
                icon: Icons.local_shipping_rounded,
                label: 'Shipments',
                index: 1,
                currentIndex: navigationShell.currentIndex,
                onTap: _onTap,
              ),
              _MobileNavItem(
                icon: Icons.auto_awesome_rounded,
                label: 'Copilot',
                index: 2,
                currentIndex: navigationShell.currentIndex,
                onTap: _onTap,
              ),
              _MobileNavItem(
                icon: Icons.science_rounded,
                label: 'Simulate',
                index: 3,
                currentIndex: navigationShell.currentIndex,
                onTap: _onTap,
              ),
              _MobileNavItem(
                icon: Icons.eco_rounded,
                label: 'Impact',
                index: 4,
                currentIndex: navigationShell.currentIndex,
                onTap: _onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 90,
      color: AppColors.panelDark,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),
            // Logo cluster
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: AppColors.accentMint,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.accentTan,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
            _SidebarNavItem(
              icon: Icons.dashboard_rounded,
              label: 'Command',
              index: 0,
              currentIndex: navigationShell.currentIndex,
              onTap: _onTap,
            ),
            const SizedBox(height: 24),
            _SidebarNavItem(
              icon: Icons.local_shipping_rounded,
              label: 'Shipments',
              index: 1,
              currentIndex: navigationShell.currentIndex,
              onTap: _onTap,
            ),
            const SizedBox(height: 24),
            _SidebarNavItem(
              icon: Icons.auto_awesome_rounded,
              label: 'Copilot',
              index: 2,
              currentIndex: navigationShell.currentIndex,
              onTap: _onTap,
            ),
            const SizedBox(height: 24),
            _SidebarNavItem(
              icon: Icons.science_rounded,
              label: 'Simulate',
              index: 3,
              currentIndex: navigationShell.currentIndex,
              onTap: _onTap,
            ),
            const SizedBox(height: 24),
            _SidebarNavItem(
              icon: Icons.eco_rounded,
              label: 'Impact',
              index: 4,
              currentIndex: navigationShell.currentIndex,
              onTap: _onTap,
            ),
          ],
        ),
      ),
    );
  }

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

/// Mobile nav item — expands to show label when selected.
class _MobileNavItem extends StatelessWidget {
  const _MobileNavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = index == currentIndex;

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 10,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentMint.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? AppColors.accentMint
                  : AppColors.textOnDarkMuted,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentMint,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

/// Sidebar nav item — always shows label below icon.
class _SidebarNavItem extends StatelessWidget {
  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = index == currentIndex;

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.accentMint.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              size: 22,
              color: isSelected
                  ? AppColors.accentMint
                  : AppColors.textOnDarkMuted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? AppColors.accentMint
                  : AppColors.textOnDarkMuted,
            ),
          ),
        ],
      ),
    );
  }
}
