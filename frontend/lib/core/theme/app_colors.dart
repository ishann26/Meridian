import 'package:flutter/material.dart';

/// SmartLogiChain color palette.
///
/// Inspired by soft premium mobile UI: off-white backgrounds,
/// charcoal hero panels, muted mint/cream/tan accents.
class AppColors {
  AppColors._();

  // ── Backgrounds ──────────────────────────────────────────────
  static const Color bgPrimary = Color(0xFFF6F4F0); // warm off-white
  static const Color bgSecondary = Color(0xFFEDE9E3); // slightly deeper cream
  static const Color bgCard = Color(0xFFFFFFFF); // white card surface

  // ── Charcoal / Dark panels ───────────────────────────────────
  static const Color panelDark = Color(0xFF1C1C1E); // near-black charcoal
  static const Color panelDarkAlt = Color(0xFF2C2C2E); // lighter charcoal
  static const Color panelDarkSoft = Color(0xFF3A3A3C); // softest charcoal

  // ── Text ─────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6E6E73);
  static const Color textTertiary = Color(0xFF8E8E93);
  static const Color textOnDark = Color(0xFFF5F5F7);
  static const Color textOnDarkMuted = Color(0xFFAEAEB2);

  // ── Accents ──────────────────────────────────────────────────
  static const Color accentMint = Color(0xFFB8D8C8); // muted mint
  static const Color accentMintDark = Color(0xFF7FB89E); // deeper mint
  static const Color accentCream = Color(0xFFF0E6D3); // warm cream
  static const Color accentTan = Color(0xFFD4C5A9); // soft tan
  static const Color accentPeach = Color(0xFFF2C6A5); // warm peach

  // ── Semantic ─────────────────────────────────────────────────
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFF9F0A);
  static const Color error = Color(0xFFFF3B30);
  static const Color info = Color(0xFF5AC8FA);

  // ── Misc ─────────────────────────────────────────────────────
  static const Color divider = Color(0xFFE5E5EA);
  static const Color shimmerBase = Color(0xFFE8E5E0);
  static const Color shimmerHighlight = Color(0xFFF5F3EF);
  static const Color shadow = Color(0x14000000); // 8% black
}
