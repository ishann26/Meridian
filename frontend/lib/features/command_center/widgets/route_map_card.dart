import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meridian/core/theme/app_colors.dart';
import 'package:meridian/core/theme/app_theme.dart';

/// A charcoal card with a stylized route map visualization.
///
/// Shows "current" and "optimized" route lines drawn with
/// [CustomPainter], simulating a real map view with city nodes,
/// grid texture, and a gradient glow along the optimized path.
class RouteMapCard extends StatelessWidget {
  const RouteMapCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.panelDark,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.accentMint.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.route_rounded,
                    size: 15,
                    color: AppColors.accentMint,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Route Intelligence',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textOnDark,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accentMint.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: AppColors.accentMint,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'LIVE',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentMint,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Route map canvas ─────────────────────────────
          SizedBox(
            height: 150,
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: CustomPaint(
                painter: _RouteMapPainter(),
                size: Size.infinite,
              ),
            ),
          ),

          // ── Legend + corridor label ───────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
            child: Row(
              children: [
                _LegendItem(
                  color: AppColors.accentPeach.withValues(alpha: 0.8),
                  label: 'Current',
                  isDashed: true,
                ),
                const SizedBox(width: 16),
                _LegendItem(
                  color: AppColors.accentMint,
                  label: 'Optimized',
                  isDashed: false,
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.panelDarkAlt,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: Text(
                    'MUM → RTD',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textOnDarkMuted,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Legend item with a line sample (solid or dashed) + label.
class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.isDashed,
  });

  final Color color;
  final String label;
  final bool isDashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 3,
          child: CustomPaint(
            painter: _LineSamplePainter(color: color, isDashed: isDashed),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: AppColors.textOnDarkMuted,
          ),
        ),
      ],
    );
  }
}

/// Paints a tiny line sample for the legend.
class _LineSamplePainter extends CustomPainter {
  _LineSamplePainter({required this.color, required this.isDashed});

  final Color color;
  final bool isDashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    if (isDashed) {
      var x = 0.0;
      while (x < size.width) {
        canvas.drawLine(
          Offset(x, size.height / 2),
          Offset(min(x + 4, size.width), size.height / 2),
          paint,
        );
        x += 6;
      }
    } else {
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Paints stylized route lines with city nodes on a dark background.
class _RouteMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Subtle grid dots ───────────────────────────────────
    final dotPaint = Paint()
      ..color = AppColors.panelDarkSoft.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;

    for (var x = 24.0; x < w - 12; x += 28) {
      for (var y = 14.0; y < h - 10; y += 28) {
        canvas.drawCircle(Offset(x, y), 0.8, dotPaint);
      }
    }

    // ── City nodes ─────────────────────────────────────────
    final cities = [
      _CityNode('MUM', Offset(w * 0.08, h * 0.48)),
      _CityNode('JED', Offset(w * 0.30, h * 0.32)),
      _CityNode('SUZ', Offset(w * 0.50, h * 0.26)),
      _CityNode('ANT', Offset(w * 0.76, h * 0.58)),
      _CityNode('RTD', Offset(w * 0.92, h * 0.38)),
    ];

    // ── Current route (peach, dashed) ──────────────────────
    final currentPaint = Paint()
      ..color = AppColors.accentPeach.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final currentPath = Path()
      ..moveTo(cities[0].pos.dx, cities[0].pos.dy)
      ..cubicTo(
        w * 0.18, h * 0.22,
        w * 0.24, h * 0.24,
        cities[1].pos.dx, cities[1].pos.dy,
      )
      ..cubicTo(
        w * 0.38, h * 0.20,
        w * 0.44, h * 0.22,
        cities[2].pos.dx, cities[2].pos.dy,
      )
      ..cubicTo(
        w * 0.62, h * 0.18,
        w * 0.82, h * 0.24,
        cities[4].pos.dx, cities[4].pos.dy,
      );

    _drawDashedPath(canvas, currentPath, currentPaint);

    // ── Optimized route glow (soft mint shadow) ────────────
    final glowPaint = Paint()
      ..color = AppColors.accentMint.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final optPath = Path()
      ..moveTo(cities[0].pos.dx, cities[0].pos.dy)
      ..cubicTo(
        w * 0.22, h * 0.60,
        w * 0.38, h * 0.66,
        w * 0.52, h * 0.58,
      )
      ..cubicTo(
        w * 0.64, h * 0.52,
        w * 0.70, h * 0.58,
        cities[3].pos.dx, cities[3].pos.dy,
      )
      ..cubicTo(
        w * 0.82, h * 0.54,
        w * 0.88, h * 0.44,
        cities[4].pos.dx, cities[4].pos.dy,
      );

    canvas.drawPath(optPath, glowPaint);

    // ── Optimized route line (solid mint) ───────────────────
    final optimizedPaint = Paint()
      ..color = AppColors.accentMint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(optPath, optimizedPaint);

    // ── Draw city nodes ────────────────────────────────────
    for (final city in cities) {
      // Outer glow
      canvas.drawCircle(
        city.pos,
        7,
        Paint()
          ..color = AppColors.panelDarkAlt
          ..style = PaintingStyle.fill,
      );

      // Inner dot
      canvas.drawCircle(
        city.pos,
        3.5,
        Paint()
          ..color = AppColors.textOnDark
          ..style = PaintingStyle.fill,
      );

      // Label
      final tp = TextPainter(
        text: TextSpan(
          text: city.label,
          style: GoogleFonts.inter(
            fontSize: 8,
            fontWeight: FontWeight.w600,
            color: AppColors.textOnDarkMuted,
            letterSpacing: 0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(
        canvas,
        Offset(city.pos.dx - tp.width / 2, city.pos.dy + 11),
      );
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final end = min(d + 6.0, metric.length);
        canvas.drawPath(metric.extractPath(d, end), paint);
        d += 11.0;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CityNode {
  const _CityNode(this.label, this.pos);
  final String label;
  final Offset pos;
}
