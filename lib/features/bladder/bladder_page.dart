import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/alarm_service.dart';
import '../../core/vitals_store.dart';
import '../../core/responsive.dart';
import '../home/app_drawer.dart';
import '../../core/app_colors.dart';

class BladderPage extends StatefulWidget {
  const BladderPage({super.key});

  @override
  State<BladderPage> createState() => _BladderPageState();
}

class _BladderPageState extends State<BladderPage> {
  final VitalsStore store = VitalsStore.instance;

  // null = no reading (shown as "--").
  double? get impedance => store.vitals.value.impedance;
  double? get fillPercentage => store.vitals.value.bladderPercent;

  @override
  void initState() {
    super.initState();
    store.vitals.addListener(_onVitalsChanged);
  }

  void _onVitalsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    store.vitals.removeListener(_onVitalsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reading = fillPercentage;
    // The gauge needs a number: an empty gauge with "--" when there is none.
    final percentage = reading ?? 0;
    final alarm =
        AlarmService.instance.levels[AlarmParam.bladder] != AlarmLevel.normal;
    const alarmRed = Color(0xFFE65F72);

    return Scaffold(
      backgroundColor: AppColors.bg,
      drawer: const AppDrawer(current: AppSection.bladder),
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: const DrawerMenuButton(),
        title: const Text(
          'Bladder Monitor',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: ContentFrame(
          maxWidth: 900,
          child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Bladder Filling Level',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 6),
               Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Filling estimation from impedance',
                  style: TextStyle(color: AppColors.text.withValues(alpha: .54)),
                ),
              ),
              const SizedBox(height: 22),
              LayoutBuilder(
                builder: (context, box) {
                  final wide = box.maxWidth >= 700;
                  final bladderCard = Container(
                                padding: const EdgeInsets.fromLTRB(10, 22, 10, 18),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: 330,
                      child: BladderVisualization(
                        percentage: percentage,
                        noData: reading == null,
                        color: alarm ? alarmRed : const Color(0xFF54A9FF),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: .92, end: 1).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutBack,
                            ),
                          ),
                          child: child,
                        ),
                      ),
                      child: Text(
                        '${showDouble(reading, 0)}%',
                        key: ValueKey<int>(reading?.round() ?? -1),
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          color: alarm ? alarmRed : const Color(0xFF38E08F),
                        ),
                      ),
                    ),
                     Text(
                      'Estimated bladder filling',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.text.withValues(alpha: .54), fontSize: 12),
                    ),
                    if (alarm) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: alarmRed.withValues(alpha: .18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: alarmRed,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                              'ABOVE SAFE LIMIT '
                              '(${AlarmService.formatNumber(AlarmParam.bladder, AlarmService.instance.limits[AlarmParam.bladder]!.high)}%)',
                              style: const TextStyle(
                                color: alarmRed,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
                  final impedanceCard = Container(
                padding: const EdgeInsets.fromLTRB(12, 22, 12, 22),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: const Color(0xFF54A9FF).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.sensors,
                        color: Color(0xFF54A9FF),
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Impedance',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                     Text(
                      'Live sensor reading',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.text.withValues(alpha: .54), fontSize: 12),
                    ),
                    const SizedBox(height: 18),
                    FittedBox(
                      child: Text(
                        showDouble(impedance, 1),
                        style: const TextStyle(
                          color: Color(0xFF54A9FF),
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Text(
                      'Ω',
                      style: TextStyle(
                        color: Color(0xFF54A9FF),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
                  if (wide) {
                    return Directionality(
                      textDirection: TextDirection.ltr,
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(flex: 3, child: bladderCard),
                            const SizedBox(width: 12),
                            Expanded(flex: 2, child: impedanceCard),
                          ],
                        ),
                      ),
                    );
                  }
                  // Phones: the original stacked layout.
                  return Column(
                    children: [
                      SizedBox(width: double.infinity, child: bladderCard),
                      const SizedBox(height: 14),
                      SizedBox(width: double.infinity, child: impedanceCard),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
               Text(
                'Prototype simulation: the displayed filling percentage increases with impedance. Sensor calibration will be added when the ESP32 is connected.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.text.withValues(alpha: .38),
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class BladderVisualization extends StatelessWidget {
  final double percentage;
  final Color color;

  /// No reading: the label shows "--%" instead of "0%".
  final bool noData;

  const BladderVisualization({
    super.key,
    required this.percentage,
    this.color = const Color(0xFF54A9FF),
    this.noData = false,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: percentage),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, animatedPercentage, child) {
        return CustomPaint(
          painter: BladderPainter(
            percentage: animatedPercentage,
            color: color,
            noData: noData,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class BladderPainter extends CustomPainter {
  final double percentage;
  final Color color;
  final bool noData;

  BladderPainter({
    required this.percentage,
    this.color = const Color(0xFF54A9FF),
    this.noData = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final top = 34.0;
    final bladderWidth = min(size.width * 0.62, 210.0);
    final bladderHeight = min(size.height * 0.67, 245.0);
    final left = centerX - bladderWidth / 2;
    final right = centerX + bladderWidth / 2;
    final bottom = top + bladderHeight;

    final outlinePath = Path()
      ..moveTo(centerX - 27, top + 20)
      ..cubicTo(centerX - 25, top - 2, centerX - 12, top - 4, centerX, top + 12)
      ..cubicTo(
        centerX + 12,
        top - 4,
        centerX + 25,
        top - 2,
        centerX + 27,
        top + 20,
      )
      ..cubicTo(right - 5, top + 48, right + 5, top + 92, right - 2, top + 142)
      ..cubicTo(
        right - 10,
        bottom - 25,
        centerX + 57,
        bottom + 5,
        centerX,
        bottom + 9,
      )
      ..cubicTo(
        centerX - 57,
        bottom + 5,
        left + 10,
        bottom - 25,
        left + 2,
        top + 142,
      )
      ..cubicTo(left - 5, top + 92, left + 5, top + 48, centerX - 27, top + 20)
      ..close();

    final fillFraction = percentage.clamp(0.0, 100.0) / 100.0;
    final fillTop = bottom + 9 - (bladderHeight + 20) * fillFraction;

    canvas.save();
    canvas.clipPath(outlinePath);

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.48);
    canvas.drawRect(
      Rect.fromLTRB(left - 10, fillTop, right + 10, bottom + 20),
      fillPaint,
    );

    final wavePaint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    final wave = Path();
    final waveY = fillTop + 2;
    for (double x = left - 10; x <= right + 10; x += 3) {
      final y = waveY + sin((x - left) / 18) * 2.5;
      if (x == left - 10) {
        wave.moveTo(x, y);
      } else {
        wave.lineTo(x, y);
      }
    }
    canvas.drawPath(wave, wavePaint);
    canvas.restore();

    final outlinePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawPath(outlinePath, outlinePaint);

    final tubePaint = Paint()
      ..color = AppColors.text.withValues(alpha: .38)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(centerX - 27, top + 8),
      Offset(centerX - 27, top - 4),
      tubePaint,
    );
    canvas.drawLine(
      Offset(centerX + 27, top + 8),
      Offset(centerX + 27, top - 4),
      tubePaint,
    );

    final labelPaint = TextPainter(
      text: TextSpan(
        text: noData ? '--%' : '${percentage.toStringAsFixed(0)}%',
        style:  TextStyle(
          color: AppColors.text,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    labelPaint.paint(
      canvas,
      Offset(centerX - labelPaint.width / 2, top + bladderHeight * 0.48),
    );
  }

  @override
  bool shouldRepaint(covariant BladderPainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.color != color ||
        oldDelegate.noData != noData;
  }
}
