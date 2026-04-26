import 'package:flutter/material.dart';
import 'package:meridian/core/theme/app_colors.dart';
import 'package:meridian/core/theme/app_theme.dart';

/// Placeholder screen for features not yet built.
///
/// Shows the screen name, a description, and a decorative accent card
/// using the SmartLogiChain design system.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.accentColor = AppColors.accentMint,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppTheme.spacingXl),

              // ── Icon badge ──────────────────────────────────
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: Icon(
                  icon,
                  size: 30,
                  color: accentColor == AppColors.accentMint
                      ? AppColors.accentMintDark
                      : AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: AppTheme.spacingLg),

              // ── Title ───────────────────────────────────────
              Text(
                title,
                style: theme.textTheme.displayMedium,
              ),

              const SizedBox(height: AppTheme.spacingSm),

              // ── Subtitle ────────────────────────────────────
              Text(
                subtitle,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: AppTheme.spacingXl),

              // ── Decorative charcoal card ────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                decoration: BoxDecoration(
                  color: AppColors.panelDark,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Coming Soon',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.textOnDark,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingXs),
                    Text(
                      'This feature is under development.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textOnDarkMuted,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusPill),
                      ),
                      child: Text(
                        'Phase 0 · Foundation',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // ── Decorative accent strip ─────────────────────
              Row(
                children: [
                  _accentDot(AppColors.accentMint),
                  const SizedBox(width: 8),
                  _accentDot(AppColors.accentCream),
                  const SizedBox(width: 8),
                  _accentDot(AppColors.accentTan),
                  const SizedBox(width: 8),
                  _accentDot(AppColors.accentPeach),
                  const Spacer(),
                  Text(
                    'SmartLogiChain',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.textTertiary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _accentDot(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
