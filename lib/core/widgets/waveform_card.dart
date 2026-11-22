import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../device_service.dart';
import '../ecg_buffer.dart';
import '../settings_store.dart';
import '../vitals_store.dart';
import '../app_colors.dart';

class WaveformCard extends StatefulWidget {
  final String title;
  final Color color;

  /// Height of the whole card.
  final double height;

  /// Heart rate shown big in the corner (null = hidden).
  final int? heartRate;

  const WaveformCard({
    super.key,
    required this.title,
    required this.color,
    this.height = 150,
    this.heartRate,
  });

  @override
  State<WaveformCard> createState() => _WaveformCardState();
}

class _WaveformCardState extends State<WaveformCard> {
  double phase = 0;

  /// Freeze: stops the trace so it can be looked at (like a real monitor).
  bool frozen = false;
  List<double> _frozenCopy = const [];

  Timer? timer;

  @override
  void initState() {
    super.initState();

    timer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (mounted && !frozen) setState(() => phase += .15);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final speed = SettingsStore.instance.waveformSpeed;
    final speedText = speed == speed.roundToDouble()
        ? speed.toStringAsFixed(0)
        : speed.toStringAsFixed(1);

    return Container(
      height: widget.height,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.ecgBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.color.withValues(alpha: .25)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.title,
                style: TextStyle(
                  color: widget.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$speedText mm/s',
                style: TextStyle(
                  color: AppColors.text.withValues(alpha: .4),
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() {
                  frozen = !frozen;
                  if (frozen) _frozenCopy = List.of(EcgBuffer.instance.samples);
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (frozen ? AppColors.amber : widget.color)
                        .withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        frozen ? Icons.play_arrow_rounded : Icons.pause_rounded,
                        size: 14,
                        color: frozen ? AppColors.amber : widget.color,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        frozen ? 'FROZEN' : 'FREEZE',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: frozen
                              ? AppColors.amber
                              : widget.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (widget.heartRate != null) ...[
                Text(
                  '${widget.heartRate}',
                  style: TextStyle(
                    color: widget.color,
                    fontWeight: FontWeight.w800,
                    fontSize: 30,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'BPM',
                  style: TextStyle(
                    color: AppColors.text.withValues(alpha: .5),
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListenableBuilder(
              listenable: Listenable.merge([
                EcgBuffer.instance,
                DeviceService.instance,
              ]),
              builder: (context, _) {
                final real =
                    VitalsStore.instance.usingDevice &&
                    DeviceService.instance.connected &&
                    EcgBuffer.instance.hasData;
                if (real) {
                  return CustomPaint(
                    painter: RealEcgPainter(
                      color: widget.color,
                      samples: frozen
                          ? _frozenCopy
                          : List.of(EcgBuffer.instance.samples),
                      fs: EcgBuffer.instance.fs,
                      seconds: (4 * 25 / speed).clamp(1.5, 8.0).toDouble(),
                      gridColor: AppColors.text,
                    ),
                    size: Size.infinite,
                  );
                }
                return CustomPaint(
                  painter: ECGPainter(
                    color: widget.color,
                    phase: phase,
                    speed: speed,
                    gridColor: AppColors.text,
                  ),
                  size: Size.infinite,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ECGPainter extends CustomPainter {
  final Color color;
  final double phase;

  /// Sweep speed in mm/s. Faster sweep = beats are spread wider on screen.
  final double speed;

  /// Base color of the ECG paper grid.
  final Color gridColor;

  ECGPainter({
    required this.color,
    required this.phase,
    this.speed = 25,
    Color? gridColor,
  }) : gridColor = gridColor ?? AppColors.text;

  @override
  void paint(Canvas canvas, Size size) {
    // ECG paper: small and large squares.
    final minor = Paint()
      ..color = gridColor.withValues(alpha: .05)
      ..strokeWidth = 1;
    final major = Paint()
      ..color = gridColor.withValues(alpha: .10)
      ..strokeWidth = 1;
    const small = 12.0;
    for (double x = 0; x <= size.width; x += small) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        (x / small) % 5 == 0 ? major : minor,
      );
    }
    for (double y = 0; y <= size.height; y += small) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        (y / small) % 5 == 0 ? major : minor,
      );
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Taller cards get taller beats.
    final k = (size.height / 110).clamp(0.8, 2.2);

    final path = Path();

    for (double x = 0; x <= size.width; x++) {
      final normalized = (x / size.width) * 8 * pi * (25 / speed) + phase;

      double y = sin(normalized) * 4 * k;

      final beat = normalized % (2 * pi);

      if (beat > 2.8 && beat < 3.05) {
        y -= 25 * k;
      } else if (beat >= 3.05 && beat < 3.2) {
        y += 35 * k;
      } else if (beat >= 3.2 && beat < 3.45) {
        y -= 8 * k;
      }

      final screenY = size.height / 2 + y;

      if (x == 0) {
        path.moveTo(x, screenY);
      } else {
        path.lineTo(x, screenY);
      }
    }

    // Soft glow under the trace, then the trace itself.
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: .35)
        ..strokeWidth = 6
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ECGPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.speed != speed ||
        oldDelegate.gridColor != gridColor;
  }
}

/// Draws the real ECG samples sent by the ESP32 (latest [seconds] seconds).
class RealEcgPainter extends CustomPainter {
  final Color color;
  final List<double> samples;
  final int fs;
  final double seconds;
  final Color gridColor;

  RealEcgPainter({
    required this.color,
    required this.samples,
    required this.fs,
    required this.seconds,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ECG paper.
    final minor = Paint()
      ..color = gridColor.withValues(alpha: .05)
      ..strokeWidth = 1;
    final major = Paint()
      ..color = gridColor.withValues(alpha: .10)
      ..strokeWidth = 1;
    const small = 12.0;
    for (double x = 0; x <= size.width; x += small) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        (x / small) % 5 == 0 ? major : minor,
      );
    }
    for (double y = 0; y <= size.height; y += small) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        (y / small) % 5 == 0 ? major : minor,
      );
    }
    if (samples.length < 2) return;

    final want = (fs * seconds).round();
    final start = samples.length > want ? samples.length - want : 0;
    final view = samples.sublist(start);

    var lo = view.reduce(min);
    var hi = view.reduce(max);
    if (hi - lo < 1) hi = lo + 1;
    final pad = (hi - lo) * 0.12;
    lo -= pad;
    hi += pad;

    final path = Path();
    for (var i = 0; i < view.length; i++) {
      final x = i / (want - 1) * size.width;
      final y = size.height - (view[i] - lo) / (hi - lo) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: .35)
        ..strokeWidth = 6
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant RealEcgPainter old) => true;
}
