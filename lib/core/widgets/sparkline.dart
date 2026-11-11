import 'package:flutter/material.dart';

/// Tiny trend line (no axes) used inside the vital cards.
class Sparkline extends StatelessWidget {
  final List<double> values;
  final Color color;

  /// Optional alarm limits: drawn only when they are inside the shown range.
  final double? low;
  final double? high;

  const Sparkline({
    super.key,
    required this.values,
    required this.color,
    this.low,
    this.high,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _SparkPainter(values, color, low, high),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final double? low;
  final double? high;

  _SparkPainter(this.values, this.color, this.low, this.high);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) {
      // Not enough data yet: a flat dotted line.
      final p = Paint()
        ..color = color.withValues(alpha: .35)
        ..strokeWidth = 1.4;
      for (double x = 0; x < size.width; x += 6) {
        canvas.drawLine(
          Offset(x, size.height / 2),
          Offset(x + 3, size.height / 2),
          p,
        );
      }
      return;
    }

    var minV = values.reduce((a, b) => a < b ? a : b);
    var maxV = values.reduce((a, b) => a > b ? a : b);
    if (maxV - minV < 1e-6) {
      minV -= 1;
      maxV += 1;
    }
    final pad = (maxV - minV) * 0.15;
    minV -= pad;
    maxV += pad;

    double xOf(int i) => size.width * i / (values.length - 1);
    double yOf(double v) =>
        size.height - size.height * ((v - minV) / (maxV - minV));

    final line = Path();
    for (var i = 0; i < values.length; i++) {
      final x = xOf(i);
      final y = yOf(values[i]);
      if (i == 0) {
        line.moveTo(x, y);
      } else {
        line.lineTo(x, y);
      }
    }

    // Soft fill under the line.
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: .28), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // Dot on the latest value.
    canvas.drawCircle(
      Offset(size.width, yOf(values.last)),
      3,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => true;
}
