import 'dart:math';

import 'package:flutter/material.dart';

import '../app_colors.dart';
import 'sparkline.dart';

/// One reading: big colored number, short trend line and its safe range.
/// Turns red when the reading is outside its limits.
class VitalCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final String status;

  /// Color of this reading while it is normal.
  final Color color;

  /// Recent values for the trend line (oldest first).
  final List<double> trend;

  /// Text under the trend, e.g. "Limits 50 – 120 BPM".
  final String footer;

  /// When set, the icon beats at this rate (beats per minute).
  final int? pulseBpm;

  /// When true the card turns red (reading is outside its safe limits).
  final bool alarm;

  const VitalCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    this.status = 'NORMAL',
    this.color = const Color(0xFF38E08F),
    this.trend = const [],
    this.footer = '',
    this.pulseBpm,
    this.alarm = false,
  });

  static const _red = Color(0xFFE65F72);

  @override
  Widget build(BuildContext context) {
    final accent = alarm ? _red : color;
    // Greyed out when the alarm is off or there is no reading.
    final off = status == 'OFF' || status == 'NO DATA';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: alarm ? AppColors.alarmCard : AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: alarm
              ? _red.withValues(alpha: .65)
              : AppColors.text.withValues(alpha: .06),
          width: alarm ? 1.6 : 1,
        ),
        boxShadow: alarm
            ? [BoxShadow(color: _red.withValues(alpha: .22), blurRadius: 18)]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: pulseBpm != null
                    ? _PulsingIcon(icon: icon, size: 15, color: accent, bpm: pulseBpm!)
                    : Icon(icon, size: 15, color: accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.text.withValues(alpha: .65),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: off
                      ? AppColors.text.withValues(alpha: .08)
                      : accent.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: off ? AppColors.text.withValues(alpha: .5) : accent,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.2),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: FittedBox(
                    key: ValueKey<String>(value),
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 38,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        color: off ? AppColors.text.withValues(alpha: .35) : accent,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: TextStyle(
                    color: AppColors.text.withValues(alpha: .5),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 34,
            child: Sparkline(values: trend, color: accent),
          ),
          if (footer.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              footer,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.text.withValues(alpha: .4),
                fontSize: 10.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Icon that beats once per heartbeat.
class _PulsingIcon extends StatefulWidget {
  final IconData icon;
  final double size;
  final Color color;
  final int bpm;

  const _PulsingIcon({
    required this.icon,
    required this.size,
    required this.color,
    required this.bpm,
  });

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static Duration _periodFor(int bpm) =>
      Duration(milliseconds: (60000 / bpm.clamp(30, 220)).round());

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _periodFor(widget.bpm),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant _PulsingIcon old) {
    super.didUpdateWidget(old);
    if (old.bpm != widget.bpm) {
      _controller.duration = _periodFor(widget.bpm);
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // A quick beat at the start of every period, then rest.
        final t = _controller.value;
        final beat = t < 0.35 ? sin(pi * t / 0.35) : 0.0;
        return Transform.scale(
          scale: 1 + 0.32 * beat,
          child: Icon(widget.icon, size: widget.size, color: widget.color),
        );
      },
    );
  }
}
