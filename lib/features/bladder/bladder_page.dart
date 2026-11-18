import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/alarm_service.dart';
import '../../core/vitals_store.dart';
import '../../core/responsive.dart';
import '../home/app_drawer.dart';
import '../../core/app_colors.dart';

const _blue = Color(0xFF54A9FF);
const _cyan = Color(0xFF4FD8E8);
const _green = Color(0xFF38E08F);
const _amber = Color(0xFFFFB547);
const _red = Color(0xFFE65F72);

// ---------------------------------------------------------------------------
// Zones
// ---------------------------------------------------------------------------

enum _Zone { none, low, moderate, nearFull, over }

_Zone _zoneOf(double? p, double limit, {bool alarm = false}) {
  if (p == null) return _Zone.none;
  if (alarm || p >= limit) return _Zone.over;
  if (p >= limit * .75) return _Zone.nearFull;
  if (p >= 30) return _Zone.moderate;
  return _Zone.low;
}

extension on _Zone {
  Color get color => switch (this) {
    _Zone.none => AppColors.text.withValues(alpha: .4),
    _Zone.low => _green,
    _Zone.moderate => _blue,
    _Zone.nearFull => _amber,
    _Zone.over => _red,
  };

  String get label => switch (this) {
    _Zone.none => 'No reading',
    _Zone.low => 'Low',
    _Zone.moderate => 'Moderate',
    _Zone.nearFull => 'Getting full',
    _Zone.over => 'Above safe limit',
  };

  String get hint => switch (this) {
    _Zone.none => 'Waiting for the impedance sensor.',
    _Zone.low => 'Bladder is nearly empty. No action needed.',
    _Zone.moderate => 'Filling normally within the safe range.',
    _Zone.nearFull => 'Approaching the safe limit. Plan voiding soon.',
    _Zone.over => 'Safe limit exceeded. Voiding is recommended now.',
  };

  IconData get icon => switch (this) {
    _Zone.none => Icons.sensors_off_rounded,
    _Zone.low => Icons.check_circle_rounded,
    _Zone.moderate => Icons.water_drop_rounded,
    _Zone.nearFull => Icons.trending_up_rounded,
    _Zone.over => Icons.warning_amber_rounded,
  };
}

/// Fill rate in %/hour from a least-squares fit of the last [window].
double? _fillRate(List<(DateTime, double)> pts, Duration window) {
  final from = DateTime.now().subtract(window);
  final recent = pts.where((e) => e.$1.isAfter(from)).toList();
  if (recent.length < 3) return null;
  final t0 = recent.first.$1;
  final xs = [for (final e in recent) e.$1.difference(t0).inSeconds / 3600];
  final ys = [for (final e in recent) e.$2];
  final n = xs.length;
  final mx = xs.reduce((a, b) => a + b) / n;
  final my = ys.reduce((a, b) => a + b) / n;
  var num = 0.0, den = 0.0;
  for (var i = 0; i < n; i++) {
    num += (xs[i] - mx) * (ys[i] - my);
    den += (xs[i] - mx) * (xs[i] - mx);
  }
  if (den == 0) return null;
  return num / den;
}

String _formatDuration(double hours) {
  final m = (hours * 60).round();
  if (m < 1) return '< 1 min';
  if (m < 60) return '$m min';
  final h = m ~/ 60, r = m % 60;
  return r == 0 ? '$h h' : '$h h $r m';
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class BladderPage extends StatefulWidget {
  const BladderPage({super.key});

  @override
  State<BladderPage> createState() => _BladderPageState();
}

class _BladderPageState extends State<BladderPage>
    with SingleTickerProviderStateMixin {
  final VitalsStore store = VitalsStore.instance;

  /// Drives the liquid surface and the gauge glow.
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  Duration _range = const Duration(hours: 1);

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
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reading = store.vitals.value.bladderPercent;
    final impedance = store.vitals.value.impedance;
    final limit = AlarmService.instance.limits[AlarmParam.bladder]!.high;
    final alarm =
        AlarmService.instance.levels[AlarmParam.bladder] != AlarmLevel.normal;
    final zone = _zoneOf(reading, limit, alarm: alarm);

    final all = store.samplesWithin(const Duration(hours: 6));
    final fill = [
      for (final s in all)
        if (s.data.bladderPercent case final p?) (s.time, p),
    ];
    final imp = [
      for (final s in all.where(
        (s) => s.time.isAfter(
          DateTime.now().subtract(const Duration(minutes: 15)),
        ),
      ))
        ?s.data.impedance,
    ];
    final rate = _fillRate(fill, const Duration(minutes: 15));
    final lastHour = fill.where(
      (e) => e.$1.isAfter(DateTime.now().subtract(const Duration(hours: 1))),
    );
    final peak = lastHour.isEmpty
        ? null
        : lastHour.map((e) => e.$2).reduce(max);

    String timeToLimit;
    if (reading == null) {
      timeToLimit = '--';
    } else if (reading >= limit) {
      timeToLimit = 'Reached';
    } else if (rate == null || rate < .5) {
      timeToLimit = 'Stable';
    } else {
      timeToLimit = _formatDuration((limit - reading) / rate);
    }

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
          maxWidth: 1100,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: LayoutBuilder(
                builder: (context, box) {
                  final wide = box.maxWidth >= 760;
                  final metrics = [
                    _Metric(
                      icon: Icons.sensors_rounded,
                      color: _cyan,
                      label: 'Impedance',
                      value: showDouble(impedance, 1),
                      unit: 'Ω',
                      spark: imp,
                    ),
                    _Metric(
                      icon: rate != null && rate < 0
                          ? Icons.south_east_rounded
                          : Icons.north_east_rounded,
                      color: _blue,
                      label: 'Fill rate',
                      value: rate == null
                          ? '--'
                          : '${rate >= 0 ? '+' : ''}${rate.toStringAsFixed(1)}',
                      unit: '%/h',
                    ),
                    _Metric(
                      icon: Icons.schedule_rounded,
                      color: _amber,
                      label: 'Time to limit',
                      value: timeToLimit,
                      unit: '',
                    ),
                    _Metric(
                      icon: Icons.vertical_align_top_rounded,
                      color: _red,
                      label: 'Peak · 1 h',
                      value: showDouble(peak, 0),
                      unit: '%',
                    ),
                  ];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(live: store.usingDevice, noData: reading == null),
                      const SizedBox(height: 18),
                      _HeroCard(
                        wide: wide,
                        reading: reading,
                        limit: limit,
                        zone: zone,
                        wave: _wave,
                        footer: wide
                            ? _ZoneLegend(limit: limit, current: zone)
                            : null,
                      ),
                      const SizedBox(height: 14),
                      _MetricGrid(metrics: metrics, columns: wide ? 4 : 2),
                      const SizedBox(height: 14),
                      _TrendCard(
                        points: fill,
                        limit: limit,
                        range: _range,
                        onRange: (r) => setState(() => _range = r),
                      ),
                      if (!wide) ...[
                        const SizedBox(height: 14),
                        _ZoneLegend(limit: limit, current: zone),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'Prototype: filling is estimated from bio-impedance '
                        '(40–180 Ω → 0–100 %). Calibration will be added when '
                        'the ESP32 sensor is connected.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.text.withValues(alpha: .36),
                          fontSize: 11,
                          height: 1.45,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final bool live;
  final bool noData;
  const _Header({required this.live, required this.noData});

  @override
  Widget build(BuildContext context) {
    final (text, color) = noData
        ? ('No signal', AppColors.text.withValues(alpha: .5))
        : live
        ? ('Live sensor', _green)
        : ('Simulation', _amber);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bladder Filling',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                'Continuous bio-impedance monitoring',
                style: TextStyle(
                  color: AppColors.text.withValues(alpha: .5),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: color.withValues(alpha: .3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PulseDot(color: color, active: !noData),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  final bool active;
  const _PulseDot({required this.color, required this.active});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: [
            if (widget.active)
              Container(
                width: 6 + 8 * _c.value,
                height: 6 + 8 * _c.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: .4 * (1 - _c.value)),
                ),
              ),
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero: radial gauge with the bladder inside + status panel
// ---------------------------------------------------------------------------

class _HeroCard extends StatelessWidget {
  final bool wide;
  final double? reading;
  final double limit;
  final _Zone zone;
  final Animation<double> wave;

  /// Extra content under the capacity bar (zone legend on wide screens).
  final Widget? footer;

  const _HeroCard({
    required this.wide,
    required this.reading,
    required this.limit,
    required this.zone,
    required this.wave,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final c = zone.color;
    final gauge = AspectRatio(
      aspectRatio: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: reading ?? 0),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _GaugePainter(
                    value: v,
                    limit: limit,
                    noData: reading == null,
                    glow: wave,
                  ),
                ),
              ),
              FractionallySizedBox(
                widthFactor: .56,
                heightFactor: .56,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 5,
                      child: CustomPaint(
                        painter: _BladderPainter(
                          percent: v,
                          color: c,
                          noData: reading == null,
                          wave: wave,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      flex: 4,
                      child: FittedBox(
                        child: Column(
                          children: [
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: reading == null
                                        ? '--'
                                        : v.toStringAsFixed(0),
                                  ),
                                  TextSpan(
                                    text: '%',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.text.withValues(
                                        alpha: .5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              style: TextStyle(
                                fontSize: 52,
                                height: 1,
                                fontWeight: FontWeight.w900,
                                color: AppColors.text,
                                fontFeatures: const [
                                  ui.FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'FILLED',
                              style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 2.4,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text.withValues(alpha: .45),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final panel = Column(
      crossAxisAlignment: wide
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'CURRENT STATUS',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w700,
            color: AppColors.text.withValues(alpha: .45),
          ),
        ),
        const SizedBox(height: 10),
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
          decoration: BoxDecoration(
            color: c.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.withValues(alpha: .28)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(zone.icon, color: c, size: 23),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      zone.label,
                      style: TextStyle(
                        color: c,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      zone.hint,
                      style: TextStyle(
                        color: AppColors.text.withValues(alpha: .62),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _CapacityBar(percent: reading, limit: limit, color: c),
        if (footer case final f?) ...[const SizedBox(height: 20), f],
      ],
    );

    return Container(
      padding: EdgeInsets.all(wide ? 26 : 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: RadialGradient(
          center: wide ? const Alignment(-.55, -.1) : const Alignment(0, -.45),
          radius: 1.1,
          colors: [
            Color.alphaBlend(c.withValues(alpha: .10), AppColors.card),
            AppColors.card,
          ],
        ),
        border: Border.all(color: AppColors.text.withValues(alpha: .06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppColors.dark ? .25 : .035),
            blurRadius: AppColors.dark ? 30 : 20,
            offset: Offset(0, AppColors.dark ? 12 : 6),
          ),
        ],
      ),
      child: wide
          ? Row(
              children: [
                SizedBox(width: 320, child: gauge),
                const SizedBox(width: 34),
                Expanded(child: panel),
              ],
            )
          : Column(
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: gauge,
                ),
                const SizedBox(height: 18),
                panel,
              ],
            ),
    );
  }
}

/// Segmented capacity bar (like a battery) with the safe-limit marker.
class _CapacityBar extends StatelessWidget {
  final double? percent;
  final double limit;
  final Color color;
  const _CapacityBar({
    required this.percent,
    required this.limit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    const segments = 20;
    final lit = ((percent ?? 0) / 100 * segments).round();
    final limitSeg = (limit / 100 * segments).round();
    final muted = AppColors.text.withValues(alpha: .45);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Capacity',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.text.withValues(alpha: .7),
              ),
            ),
            const Spacer(),
            Icon(
              Icons.flag_rounded,
              size: 13,
              color: _red.withValues(alpha: .8),
            ),
            const SizedBox(width: 4),
            Text(
              'Safe limit ${limit.round()}%',
              style: TextStyle(fontSize: 11.5, color: muted),
            ),
          ],
        ),
        const SizedBox(height: 9),
        SizedBox(
          height: 22,
          child: Row(
            children: [
              for (var i = 0; i < segments; i++) ...[
                if (i > 0) SizedBox(width: i == limitSeg ? 6 : 3),
                Expanded(
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 250 + i * 15),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: i < lit
                          ? (i >= limitSeg ? _red : color)
                          : AppColors.text.withValues(
                              alpha: i >= limitSeg ? .10 : .06,
                            ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text('0', style: TextStyle(fontSize: 10.5, color: muted)),
            const Spacer(),
            Text('50', style: TextStyle(fontSize: 10.5, color: muted)),
            const Spacer(),
            Text('100 %', style: TextStyle(fontSize: 10.5, color: muted)),
          ],
        ),
      ],
    );
  }
}

/// 270° gauge: a ring of segments lit up to the current value in zone
/// colours, a glowing progress arc and the safe-limit notch.
class _GaugePainter extends CustomPainter {
  final double value;
  final double limit;
  final bool noData;
  final Animation<double> glow;

  _GaugePainter({
    required this.value,
    required this.limit,
    required this.noData,
    required this.glow,
  }) : super(repaint: glow);

  static const _start = pi * .75;
  static const _sweep = pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final R = size.shortestSide / 2;
    final v = (value / 100).clamp(0.0, 1.0);
    final zoneColor = _zoneOf(noData ? null : value, limit).color;

    // Outer ticks.
    const ticks = 60;
    for (var i = 0; i <= ticks; i++) {
      final f = i / ticks;
      final a = _start + _sweep * f;
      final major = i % 10 == 0;
      final on = !noData && f <= v + 1e-6;
      final color = on
          ? _zoneOf(f * 100, limit).color
          : AppColors.text.withValues(alpha: major ? .22 : .10);
      final r1 = R - (major ? 14 : 10);
      final r2 = R - 2;
      canvas.drawLine(
        c + Offset(cos(a), sin(a)) * r1,
        c + Offset(cos(a), sin(a)) * r2,
        Paint()
          ..color = color
          ..strokeWidth = major ? 3 : 2
          ..strokeCap = StrokeCap.round,
      );
    }

    // Track.
    final rr = R - 30;
    final rect = Rect.fromCircle(center: c, radius: rr);
    canvas.drawArc(
      rect,
      _start,
      _sweep,
      false,
      Paint()
        ..color = AppColors.text.withValues(alpha: .06)
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    if (!noData && v > 0) {
      final shader = SweepGradient(
        startAngle: 0,
        endAngle: _sweep,
        colors: [
          _cyan,
          _blue,
          if (zoneColor == _amber || zoneColor == _red) _amber,
          if (zoneColor == _red) _red,
        ],
        transform: const GradientRotation(_start),
      ).createShader(rect);

      // Soft glow under the arc, breathing slowly.
      final breathe = .35 + .2 * sin(glow.value * 2 * pi);
      canvas.drawArc(
        rect,
        _start,
        _sweep * v,
        false,
        Paint()
          ..color = zoneColor.withValues(alpha: breathe)
          ..strokeWidth = 16
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      canvas.drawArc(
        rect,
        _start,
        _sweep * v,
        false,
        Paint()
          ..shader = shader
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );

      // Knob at the end.
      final a = _start + _sweep * v;
      final k = c + Offset(cos(a), sin(a)) * rr;
      canvas.drawCircle(
        k,
        10,
        Paint()..color = zoneColor.withValues(alpha: .3),
      );
      canvas.drawCircle(k, 6.5, Paint()..color = Colors.white);
      canvas.drawCircle(k, 3.5, Paint()..color = zoneColor);
    }

    // Safe-limit notch across the track.
    final la = _start + _sweep * (limit / 100).clamp(0.0, 1.0);
    final dir = Offset(cos(la), sin(la));
    canvas.drawLine(
      c + dir * (rr - 12),
      c + dir * (rr + 12),
      Paint()
        ..color = _red
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // 0 / 100 labels at the ends of the arc.
    void label(String s, double f) {
      final a = _start + _sweep * f;
      final tp = TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            color: AppColors.text.withValues(alpha: .4),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final p = c + Offset(cos(a), sin(a)) * (rr + 4);
      tp.paint(canvas, p + Offset(-tp.width / 2, 12));
    }

    label('0', 0);
    label('100', 1);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.value != value || old.limit != limit || old.noData != noData;
}

/// Glass bladder with animated liquid, drawn to fit any box.
class _BladderPainter extends CustomPainter {
  final double percent;
  final Color color;
  final bool noData;
  final Animation<double> wave;

  _BladderPainter({
    required this.percent,
    required this.color,
    required this.noData,
    required this.wave,
  }) : super(repaint: wave);

  @override
  void paint(Canvas canvas, Size size) {
    final bh = min(size.height * .92, size.width * .95);
    final bw = bh * .95;
    final cx = size.width / 2;
    final t = (size.height - bh) / 2 + bh * .04;
    final b = t + bh * .9;
    final l = cx - bw / 2, r = cx + bw / 2;

    // Shape in a unit box (0..1), like an upside-down pear: a wide dome
    // with a slight dip in the middle, tapering to the neck at the bottom.
    Offset p(double nx, double ny) => Offset(l + bw * nx, t + (b - t) * ny);
    void cubic(Path path, Offset c1, Offset c2, Offset e) =>
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, e.dx, e.dy);

    final start = p(.43, 1);
    final body = Path()..moveTo(start.dx, start.dy);
    cubic(body, p(.30, .93), p(.03, .80), p(.03, .50));
    cubic(body, p(.03, .16), p(.24, .02), p(.40, .04));
    cubic(body, p(.45, .05), p(.47, .08), p(.50, .08));
    cubic(body, p(.53, .08), p(.55, .05), p(.60, .04));
    cubic(body, p(.76, .02), p(.97, .16), p(.97, .50));
    cubic(body, p(.97, .80), p(.70, .93), p(.57, 1));
    body.close();

    // Urethra stub under the neck.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(cx - bw * .07, b - 2, cx + bw * .07, b + bh * .08),
        Radius.circular(bw * .05),
      ),
      Paint()..color = color.withValues(alpha: noData ? .12 : .35),
    );

    final glass = Rect.fromLTRB(l, t, r, b);
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.text.withValues(alpha: .03),
            AppColors.text.withValues(alpha: .07),
          ],
        ).createShader(glass),
    );

    final f = (percent / 100).clamp(0.0, 1.0);
    final top = t - bh * .02;
    final level = b - (b - top) * f;
    final phase = wave.value * 2 * pi;

    canvas.save();
    canvas.clipPath(body);
    if (!noData && f > 0) {
      Path surface(double shift, double amp) {
        final p = Path()..moveTo(l - 4, b + 4);
        for (double x = l - 4; x <= r + 4; x += 2) {
          p.lineTo(x, level + sin((x - l) / bw * 2 * pi + shift) * amp);
        }
        return p
          ..lineTo(r + 4, b + 4)
          ..close();
      }

      final amp = bh * .025;
      canvas.drawPath(
        surface(phase + pi, amp),
        Paint()..color = color.withValues(alpha: .3),
      );
      canvas.drawPath(
        surface(phase, amp * .8),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: .95),
              color.withValues(alpha: .55),
            ],
          ).createShader(Rect.fromLTRB(l, level, r, b)),
      );
      final bubble = Paint()..color = Colors.white.withValues(alpha: .28);
      for (var i = 0; i < 5; i++) {
        final p = (wave.value * 1.5 + i / 5) % 1;
        final y = b - (b - level) * p;
        final x = cx + sin(i * 2.3 + p * 5) * bw * .22;
        if (y > level + bh * .05) {
          canvas.drawCircle(Offset(x, y), bh * (.012 + (i % 3) * .006), bubble);
        }
      }
    }
    // Specular highlight.
    canvas.drawPath(
      Path()
        ..moveTo(l + bw * .16, t + bh * .2)
        ..quadraticBezierTo(
          l + bw * .06,
          t + bh * .4,
          l + bw * .14,
          t + bh * .58,
        ),
      Paint()
        ..color = Colors.white.withValues(alpha: .35)
        ..strokeWidth = bh * .035
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    canvas.restore();

    canvas.drawPath(
      body,
      Paint()
        ..color = noData
            ? AppColors.text.withValues(alpha: .2)
            : color.withValues(alpha: .9)
        ..strokeWidth = max(1.6, bh * .025)
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _BladderPainter old) =>
      old.percent != percent || old.color != color || old.noData != noData;
}

// ---------------------------------------------------------------------------
// Metrics
// ---------------------------------------------------------------------------

class _Metric {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String unit;
  final List<double> spark;
  const _Metric({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.unit,
    this.spark = const [],
  });
}

class _MetricGrid extends StatelessWidget {
  final List<_Metric> metrics;
  final int columns;
  const _MetricGrid({required this.metrics, required this.columns});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < metrics.length; i += columns) {
      final row = metrics.skip(i).take(columns).toList();
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 12));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < row.length; j++) ...[
                if (j > 0) const SizedBox(width: 12),
                Expanded(child: _MetricTile(m: row[j])),
              ],
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

class _MetricTile extends StatelessWidget {
  final _Metric m;
  const _MetricTile({required this.m});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.text.withValues(alpha: .05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: m.color.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(m.icon, color: m.color, size: 17),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  m.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.text.withValues(alpha: .58),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: m.value),
                  if (m.unit.isNotEmpty)
                    TextSpan(
                      text: ' ${m.unit}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text.withValues(alpha: .5),
                      ),
                    ),
                ],
              ),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
          ),
          if (m.spark.length >= 2) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 22,
              child: CustomPaint(
                painter: _SparkPainter(m.spark, m.color),
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  _SparkPainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final lo = data.reduce(min), hi = data.reduce(max);
    final span = max(hi - lo, 1e-6);
    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final x = size.width * i / (data.length - 1);
      final y = size.height - size.height * (data[i] - lo) / span;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    final area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: .25), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => true;
}

// ---------------------------------------------------------------------------
// Trend chart with range picker and touch read-out
// ---------------------------------------------------------------------------

class _TrendCard extends StatefulWidget {
  final List<(DateTime, double)> points;
  final double limit;
  final Duration range;
  final ValueChanged<Duration> onRange;

  const _TrendCard({
    required this.points,
    required this.limit,
    required this.range,
    required this.onRange,
  });

  @override
  State<_TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends State<_TrendCard> {
  double? _touchX;

  static const _ranges = [
    ('15m', Duration(minutes: 15)),
    ('1h', Duration(hours: 1)),
    ('6h', Duration(hours: 6)),
  ];

  @override
  Widget build(BuildContext context) {
    final from = DateTime.now().subtract(widget.range);
    final pts = widget.points.where((e) => e.$1.isAfter(from)).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.text.withValues(alpha: .05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Filling trend',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.text.withValues(alpha: .05),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(
                  children: [
                    for (final (label, d) in _ranges)
                      GestureDetector(
                        onTap: () => widget.onRange(d),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: d == widget.range
                                ? _blue
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: d == widget.range
                                  ? Colors.white
                                  : AppColors.text.withValues(alpha: .6),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 190,
            child: pts.length < 2
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.hourglass_empty_rounded,
                          color: AppColors.text.withValues(alpha: .3),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Collecting readings…',
                          style: TextStyle(
                            color: AppColors.text.withValues(alpha: .45),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : GestureDetector(
                    onPanDown: (d) =>
                        setState(() => _touchX = d.localPosition.dx),
                    onPanUpdate: (d) =>
                        setState(() => _touchX = d.localPosition.dx),
                    onPanEnd: (_) => setState(() => _touchX = null),
                    onPanCancel: () => setState(() => _touchX = null),
                    child: CustomPaint(
                      painter: _TrendPainter(
                        points: pts,
                        limit: widget.limit,
                        from: from,
                        range: widget.range,
                        touchX: _touchX,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

void _dashed(Canvas canvas, Offset a, Offset b, Paint paint) {
  const dash = 5.0, gap = 4.0;
  final len = (b - a).distance;
  if (len == 0) return;
  final dir = (b - a) / len;
  for (double d = 0; d < len; d += dash + gap) {
    canvas.drawLine(a + dir * d, a + dir * min(d + dash, len), paint);
  }
}

class _TrendPainter extends CustomPainter {
  final List<(DateTime, double)> points;
  final double limit;
  final DateTime from;
  final Duration range;
  final double? touchX;

  _TrendPainter({
    required this.points,
    required this.limit,
    required this.from,
    required this.range,
    this.touchX,
  });

  TextPainter _tp(String s, Color c, {double size = 10, bool bold = false}) =>
      TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            color: c,
            fontSize: size,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final chart = Rect.fromLTRB(32, 6, size.width, size.height - 20);
    final span = range.inMilliseconds.toDouble();
    double yOf(double v) => chart.bottom - chart.height * (v / 100).clamp(0, 1);
    Offset at(DateTime t, double v) => Offset(
      chart.left + chart.width * (t.difference(from).inMilliseconds / span),
      yOf(v),
    );
    final muted = AppColors.text.withValues(alpha: .4);

    // Zone bands.
    final lim = limit.clamp(0.0, 100.0);
    canvas.drawRect(
      Rect.fromLTRB(chart.left, yOf(100), chart.right, yOf(lim)),
      Paint()..color = _red.withValues(alpha: .07),
    );
    canvas.drawRect(
      Rect.fromLTRB(chart.left, yOf(lim), chart.right, yOf(lim * .75)),
      Paint()..color = _amber.withValues(alpha: .05),
    );

    // Grid + y labels.
    final grid = Paint()
      ..color = AppColors.text.withValues(alpha: .07)
      ..strokeWidth = 1;
    for (final v in [0, 25, 50, 75, 100]) {
      final y = yOf(v.toDouble());
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
      final tp = _tp('$v', muted);
      tp.paint(canvas, Offset(chart.left - 8 - tp.width, y - tp.height / 2));
    }

    // X labels.
    final mins = range.inMinutes;
    for (final f in [0.0, .5, 1.0]) {
      final m = (mins * (1 - f)).round();
      final label = f == 1
          ? 'now'
          : m >= 60
          ? '-${(m / 60).toStringAsFixed(m % 60 == 0 ? 0 : 1)}h'
          : '-${m}m';
      final tp = _tp(label, muted);
      final x = (chart.left + chart.width * f - tp.width * f).clamp(
        chart.left,
        size.width - tp.width,
      );
      tp.paint(canvas, Offset(x, chart.bottom + 6));
    }

    // Limit line.
    _dashed(
      canvas,
      Offset(chart.left, yOf(lim)),
      Offset(chart.right, yOf(lim)),
      Paint()
        ..color = _red.withValues(alpha: .7)
        ..strokeWidth = 1.3,
    );
    final lt = _tp('LIMIT', _red.withValues(alpha: .85), size: 9, bold: true);
    lt.paint(canvas, Offset(chart.right - lt.width, yOf(lim) - lt.height - 2));

    // Smooth line.
    final o = [for (final p in points) at(p.$1, p.$2)];
    final line = Path()..moveTo(o.first.dx, o.first.dy);
    for (var i = 1; i < o.length; i++) {
      final mid = Offset(
        (o[i - 1].dx + o[i].dx) / 2,
        (o[i - 1].dy + o[i].dy) / 2,
      );
      line.quadraticBezierTo(o[i - 1].dx, o[i - 1].dy, mid.dx, mid.dy);
    }
    line.lineTo(o.last.dx, o.last.dy);

    final area = Path.from(line)
      ..lineTo(o.last.dx, chart.bottom)
      ..lineTo(o.first.dx, chart.bottom)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_blue.withValues(alpha: .32), _blue.withValues(alpha: 0)],
        ).createShader(chart),
    );

    // Line coloured by zone height.
    final ls = (1 - lim / 100).clamp(0.0, 1.0);
    final as_ = (1 - lim * .75 / 100).clamp(ls, 1.0);
    canvas.drawPath(
      line,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [_red, _red, _amber, _amber, _blue, _cyan],
          stops: [0, ls, ls, as_, as_, 1],
        ).createShader(chart)
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );

    final last = o.last;
    final lastColor = _zoneOf(points.last.$2, limit).color;
    canvas.drawCircle(
      last,
      9,
      Paint()..color = lastColor.withValues(alpha: .25),
    );
    canvas.drawCircle(last, 4.5, Paint()..color = lastColor);

    // Touch read-out.
    final tx = touchX;
    if (tx != null) {
      var best = 0;
      for (var i = 1; i < o.length; i++) {
        if ((o[i].dx - tx).abs() < (o[best].dx - tx).abs()) best = i;
      }
      final p = o[best];
      canvas.drawLine(
        Offset(p.dx, chart.top),
        Offset(p.dx, chart.bottom),
        Paint()
          ..color = AppColors.text.withValues(alpha: .25)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(p, 6, Paint()..color = Colors.white);
      canvas.drawCircle(p, 3.5, Paint()..color = _blue);

      final t = points[best].$1;
      final hh = t.hour.toString().padLeft(2, '0');
      final mm = t.minute.toString().padLeft(2, '0');
      final tp = _tp(
        '${points[best].$2.toStringAsFixed(0)}%  ·  $hh:$mm',
        Colors.white,
        size: 12,
        bold: true,
      );
      final w = tp.width + 18, h = tp.height + 10;
      final bx = (p.dx - w / 2).clamp(chart.left, size.width - w);
      final by = max(0.0, p.dy - h - 12);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(bx, by, w, h),
          const Radius.circular(9),
        ),
        Paint()..color = const Color(0xFF1B2B40),
      );
      tp.paint(canvas, Offset(bx + 9, by + 5));
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => true;
}

// ---------------------------------------------------------------------------
// Zone legend
// ---------------------------------------------------------------------------

class _ZoneLegend extends StatelessWidget {
  final double limit;
  final _Zone current;
  const _ZoneLegend({required this.limit, required this.current});

  @override
  Widget build(BuildContext context) {
    final near = (limit * .75).round();
    final lim = limit.round();
    final items = [
      (_Zone.low, '0 – 30 %'),
      (_Zone.moderate, '30 – $near %'),
      (_Zone.nearFull, '$near – $lim %'),
      (_Zone.over, '≥ $lim %'),
    ];
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.text.withValues(alpha: .05)),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final perRow = box.maxWidth >= 640 ? 4 : 2;
          final w = (box.maxWidth - 8 * (perRow - 1)) / perRow;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (z, range) in items)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: w,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: z == current
                        ? z.color.withValues(alpha: .13)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: z == current
                          ? z.color.withValues(alpha: .4)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: z.color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              z.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: z == current
                                    ? z.color
                                    : AppColors.text.withValues(alpha: .8),
                              ),
                            ),
                            Text(
                              range,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.text.withValues(alpha: .45),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
