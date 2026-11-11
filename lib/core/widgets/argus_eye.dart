import 'package:flutter/material.dart';

/// The ARGUS logo: an eye with a softly pulsing pupil.
/// [pulse] goes from 0 to 1 and drives the glow of the pupil.
class ArgusEyePainter extends CustomPainter {
  final double pulse;

  ArgusEyePainter({this.pulse = 0.5});

  @override
  void paint(Canvas canvas, Size size) {
    const blue = Color(0xFF54A9FF);
    const green = Color(0xFF38E08F);

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Almond-shaped eye outline.
    final eye = Path()
      ..moveTo(0, cy)
      ..quadraticBezierTo(cx, -size.height * 0.45, size.width, cy)
      ..quadraticBezierTo(cx, size.height * 1.45, 0, cy)
      ..close();

    canvas.drawPath(
      eye,
      Paint()
        ..color = blue.withValues(alpha: 0.08)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      eye,
      Paint()
        ..color = blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeJoin = StrokeJoin.round,
    );

    // Iris.
    final irisRadius = size.height * 0.31;
    canvas.drawCircle(
      Offset(cx, cy),
      irisRadius,
      Paint()
        ..color = blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    // Pupil with a soft pulsing glow.
    final pupilRadius = size.height * 0.13;
    canvas.drawCircle(
      Offset(cx, cy),
      pupilRadius * (1.5 + pulse * 0.5),
      Paint()
        ..color = green.withValues(alpha: 0.18 + pulse * 0.17)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(Offset(cx, cy), pupilRadius, Paint()..color = green);

    // Small highlight.
    canvas.drawCircle(
      Offset(cx - pupilRadius * 0.35, cy - pupilRadius * 0.35),
      pupilRadius * 0.28,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant ArgusEyePainter oldDelegate) =>
      oldDelegate.pulse != pulse;
}
