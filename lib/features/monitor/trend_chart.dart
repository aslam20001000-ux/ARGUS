import 'package:flutter/material.dart';

import '../../core/app_colors.dart';

/// Simple line chart of readings over time with dashed alarm-limit lines.
class TrendChart extends StatelessWidget {
  final List<DateTime> times;
  final List<double> values;
  final Duration range;
  final Color color;
  final double? lowLimit;
  final double? highLimit;
  final int decimals;

  const TrendChart({
    super.key,
    required this.times,
    required this.values,
    required this.range,
    required this.color,
    this.lowLimit,
    this.highLimit,
    this.decimals = 0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _TrendPainter(
        times: times,
        values: values,
        range: range,
        color: color,
        lowLimit: lowLimit,
        highLimit: highLimit,
        decimals: decimals,
        text: AppColors.text,
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<DateTime> times;
  final List<double> values;
  final Duration range;
  final Color color;
  final double? lowLimit;
  final double? highLimit;
  final int decimals;
  final Color text;

  _TrendPainter({
    required this.times,
    required this.values,
    required this.range,
    required this.color,
    required this.lowLimit,
    required this.highLimit,
    required this.decimals,
    required this.text,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    const leftPad = 34.0;
    const bottomPad = 16.0;
    final plot = Rect.fromLTRB(leftPad, 4, size.width, size.height - bottomPad);

    // Vertical range: the data plus the limits, with a little margin.
    var minV = values.reduce((a, b) => a < b ? a : b);
    var maxV = values.reduce((a, b) => a > b ? a : b);
    if (lowLimit != null && lowLimit! < minV) minV = lowLimit!;
    if (highLimit != null && highLimit! > maxV) maxV = highLimit!;
    if (maxV - minV < 1e-6) {
      minV -= 1;
      maxV += 1;
    }
    final pad = (maxV - minV) * 0.12;
    minV -= pad;
    maxV += pad;

    final end = DateTime.now();
    final start = end.subtract(range);
    double xOf(DateTime t) {
      final f = t.difference(start).inMilliseconds / range.inMilliseconds;
      return plot.left + plot.width * f.clamp(0.0, 1.0);
    }

    double yOf(double v) =>
        plot.bottom - plot.height * ((v - minV) / (maxV - minV));

    // Grid.
    final grid = Paint()
      ..color = text.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = plot.top + plot.height * i / 3;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
    }

    // Axis labels.
    void label(String s, Offset at, {bool rightAlign = false}) {
      final tp = TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(color: text.withValues(alpha: .5), fontSize: 9.5),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, rightAlign ? Offset(at.dx - tp.width, at.dy) : at);
    }

    label(
      maxV.toStringAsFixed(decimals),
      Offset(leftPad - 4, plot.top - 2),
      rightAlign: true,
    );
    label(
      minV.toStringAsFixed(decimals),
      Offset(leftPad - 4, plot.bottom - 10),
      rightAlign: true,
    );
    label(_rangeText(range), Offset(plot.left, plot.bottom + 3));
    label('now', Offset(plot.right, plot.bottom + 3), rightAlign: true);

    // Limit lines (dashed).
    void dashed(double v) {
      final y = yOf(v);
      final paint = Paint()
        ..color = const Color(0xFFE65F72).withValues(alpha: 0.65)
        ..strokeWidth = 1.2;
      for (double x = plot.left; x < plot.right; x += 9) {
        canvas.drawLine(
          Offset(x, y),
          Offset((x + 5).clamp(plot.left, plot.right), y),
          paint,
        );
      }
    }

    if (lowLimit != null) dashed(lowLimit!);
    if (highLimit != null) dashed(highLimit!);

    // The line.
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final p = Offset(xOf(times[i]), yOf(values[i]));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.save();
    canvas.clipRect(plot.inflate(2));
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  static String _rangeText(Duration d) =>
      d.inMinutes < 60 ? '-${d.inMinutes}m' : '-${d.inHours}h';

  @override
  bool shouldRepaint(covariant _TrendPainter old) => true;
}
