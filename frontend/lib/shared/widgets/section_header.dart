import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meridian/core/theme/app_colors.dart';
import 'package:meridian/core/theme/app_theme.dart';

/// Section header with a label and optional trailing action.
///
/// Reused across the Command Center for "Risk Alerts ›",
/// "AI Recommendation ›", etc.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          if (trailing != null)
            GestureDetector(
              onTap: onTap,
              child: Text(
                trailing!,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
