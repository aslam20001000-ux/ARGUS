import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/ews.dart';
import '../../core/vitals_store.dart';

const _green = Color(0xFF38E08F);
const _amber = Color(0xFFFFB454);
const _red = Color(0xFFE65F72);

/// Ring showing the early-warning score of the current readings.
class EwsCard extends StatelessWidget {
  final VitalsData vitals;
  const EwsCard({super.key, required this.vitals});

  @override
  Widget build(BuildContext context) {
    final r = Ews.compute(vitals);
    final color = r.noData
        ? AppColors.text.withValues(alpha: .4)
        : switch (r.risk) {
            EwsRisk.low => _green,
            EwsRisk.medium => _amber,
            EwsRisk.high => _red,
          };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: r.risk == EwsRisk.high ? AppColors.alarmCard : AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: r.risk == EwsRisk.low ? .2 : .6),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 104,
            height: 104,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0,
                      end: r.score / EwsResult.maxScore,
                    ),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => CustomPaint(
                      painter: _RingPainter(
                        fraction: value,
                        color: color,
                        track: AppColors.text.withValues(alpha: .09),
                      ),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      r.noData ? '--' : '${r.score}',
                      style: TextStyle(
                        fontSize: 32,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    Text(
                      '/ ${EwsResult.maxScore}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.text.withValues(alpha: .45),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'EARLY WARNING SCORE',
                  style: TextStyle(
                    fontSize: 10.5,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text.withValues(alpha: .5),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  r.label,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final p in r.parts)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _partColor(p.points).withValues(alpha: .14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          p.valueText == '--'
                              ? '${p.label} --'
                              : '${p.label} +${p.points}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: _partColor(p.points),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Estimate from 4 readings. Not a clinical decision.',
                  style: TextStyle(
                    fontSize: 9.5,
                    color: AppColors.text.withValues(alpha: .35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Color _partColor(int points) => switch (points) {
    0 => _green,
    1 => _amber,
    2 => const Color(0xFFFF8A65),
    _ => _red,
  };
}

class _RingPainter extends CustomPainter {
  final double fraction;
  final Color color;
  final Color track;

  _RingPainter({
    required this.fraction,
    required this.color,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    // 270° gauge that starts at the bottom-left.
    const start = 3 * pi / 4;
    const sweep = 3 * pi / 2;

    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
    if (fraction > 0) {
      canvas.drawArc(
        rect,
        start,
        sweep * fraction.clamp(0.0, 1.0),
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.fraction != fraction || old.color != color || old.track != track;
}
