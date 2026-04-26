import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meridian/core/theme/app_colors.dart';
import 'package:meridian/core/theme/app_theme.dart';

/// AI recommendation card — charcoal with mint accent.
class AiRecommendationCard extends StatelessWidget {
  const AiRecommendationCard({
    super.key,
    required this.title,
    required this.recommendation,
    required this.impact,
    this.onTap,
  });

  final String title;
  final String recommendation;
  final String impact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panelDark,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: AppColors.accentMint.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    size: 15, color: AppColors.accentMint),
              ),
              const SizedBox(width: 10),
              Text('AI Copilot',
                style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppColors.accentMint, letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accentMint.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('PRIORITY',
                  style: GoogleFonts.inter(
                    fontSize: 8, fontWeight: FontWeight.w700,
                    color: AppColors.accentMint, letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Title
          Text(title,
            style: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w600,
              color: AppColors.textOnDark,
            ),
          ),
          const SizedBox(height: 6),

          // Body
          Text(recommendation,
            style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w400,
              color: AppColors.textOnDarkMuted, height: 1.5,
            ),
          ),
          const SizedBox(height: 14),

          // Impact + action
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.panelDarkAlt,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.trending_up_rounded,
                          size: 12, color: AppColors.accentMint),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(impact,
                          style: GoogleFonts.inter(
                            fontSize: 10, fontWeight: FontWeight.w500,
                            color: AppColors.textOnDarkMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentMint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Apply',
                    style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: AppColors.panelDark,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
