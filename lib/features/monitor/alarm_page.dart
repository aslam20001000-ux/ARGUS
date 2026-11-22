import 'package:flutter/material.dart';

import '../../core/alarm_service.dart';
import '../../core/app_colors.dart';
import '../../core/responsive.dart';
import '../../core/settings_store.dart';
import '../../core/vitals_store.dart';
import '../../core/widgets/ui.dart';

Color get _green => AppColors.green;
Color get _red => AppColors.red;
Color get _blue => AppColors.blue;
Color get _card => AppColors.card;

/// Live alarm status, the limits of every monitored signal and the alarm log.
class AlarmPage extends StatelessWidget {
  /// Hide the big "Alarms" title when the page is opened from Settings (the
  /// app bar already shows a title there).
  final bool showHeader;

  const AlarmPage({super.key, this.showHeader = true});

  @override
  Widget build(BuildContext context) {
    final service = AlarmService.instance;

    return ListenableBuilder(
      listenable: Listenable.merge([service, SettingsStore.instance]),
      builder: (context, _) {
        final v = VitalsStore.instance.vitals.value;

        return ContentFrame(
          maxWidth: 1100,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
            children: [
              if (showHeader)
                const PageHeader(
                  title: 'Alarms',
                  subtitle: 'Live status and limits for every monitored signal',
                ),
              _StatusHero(service: service),
              const SectionHeading('Alarm limits'),
              // 1 column on phones, 2 on tablets, 3 on wide screens.
              AdaptiveGrid(
                minTileWidth: 330,
                maxColumns: 3,
                children: [
                  for (final p in AlarmParam.values)
                    _LimitCard(param: p, vitals: v),
                ],
              ),
              SectionHeading(
                'Alarm log',
                action: service.history.isEmpty
                    ? null
                    : TextButton.icon(
                        onPressed: () => _confirmClear(context, service),
                        icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                        label: const Text('Clear'),
                      ),
              ),
              AlarmLogCard(
                events: service.history,
                showClock: true,
                emptyTitle: 'No alarms so far',
                emptyText: 'Every alarm that starts is listed here.',
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmClear(BuildContext context, AlarmService service) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Clear the alarm log?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'All ${service.history.length} entries will be removed. Active '
          'alarms are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: _red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok == true) service.clearHistory();
  }
}

// ============================================================ status hero

class _StatusHero extends StatelessWidget {
  final AlarmService service;
  const _StatusHero({required this.service});

  @override
  Widget build(BuildContext context) {
    final count = service.activeCount; // includes "device disconnected"
    final ok = count == 0;
    final names = [
      if (service.deviceLost) 'Device disconnected',
      ...service.activeParams.map(AlarmService.labelOf),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: ok
              ? AppColors.heroGradient
              : const [Color(0xFFB8324A), Color(0xFF8E2238), Color(0xFF5E1627)],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: .16),
              border: Border.all(color: Colors.white.withValues(alpha: .3)),
            ),
            child: Icon(
              ok ? Icons.verified_rounded : Icons.warning_amber_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ok
                      ? 'All clear'
                      : '$count active alarm${count == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                if (ok)
                  Text(
                    'Every enabled signal is inside its limits.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .75),
                      fontSize: 13,
                    ),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final n in names)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            n,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          if (!ok) ...[
            const SizedBox(width: 10),
            service.silenced
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .2),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.volume_off, size: 16, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'Silenced',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  )
                : FilledButton.icon(
                    onPressed: service.silence,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF8E2238),
                    ),
                    icon: const Icon(Icons.volume_off_rounded, size: 18),
                    label: const Text('Silence 2 min'),
                  ),
          ],
        ],
      ),
    );
  }
}

// ============================================================= limit card

class _LimitCard extends StatelessWidget {
  final AlarmParam param;
  final VitalsData vitals;

  const _LimitCard({required this.param, required this.vitals});

  String _limitText(AlarmLimit limit) {
    final p = param;
    if (p == AlarmParam.ecg) return 'Lead connection & rhythm';
    final unit = AlarmService.unitOf(p);
    final high = AlarmService.formatNumber(p, limit.high);
    if (p == AlarmParam.bladder) return 'Alarm above $high $unit';
    final low = AlarmService.formatNumber(p, limit.low);
    return 'Safe range $low – $high $unit';
  }

  @override
  Widget build(BuildContext context) {
    final service = AlarmService.instance;
    final p = param;
    final limit = service.limits[p]!;
    final level = service.levels[p]!;
    final enabled = limit.enabled;
    final active = enabled && level != AlarmLevel.normal;
    final status = service.statusLabel(p);
    final noData = status == 'NO DATA';
    final accent = !enabled || noData
        ? AppColors.text.withValues(alpha: .4)
        : active
        ? _red
        : _green;
    final value = AlarmService.valueOf(p, vitals);

    return AppCard(
      color: active ? AppColors.alarmCard : null,
      borderColor: active ? _red.withValues(alpha: .5) : null,
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardTitle(
            icon: alarmIcon(p),
            color: enabled ? (active ? _red : _blue) : accent,
            title: AlarmService.labelOf(p),
            subtitle: _limitText(limit),
            trailing: Switch(
              value: enabled,
              onChanged: (value) => service.setEnabled(p, value),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      AlarmService.formatValue(p, vitals),
                      style: TextStyle(
                        fontSize: p == AlarmParam.ecg ? 20 : 24,
                        fontWeight: FontWeight.w900,
                        color: enabled && !noData
                            ? AppColors.text
                            : AppColors.text.withValues(alpha: .38),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                StatusPill(status, color: accent),
              ],
            ),
          ),
          if (p != AlarmParam.ecg) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 6),
              child: SizedBox(
                height: 14,
                width: double.infinity,
                child: CustomPaint(
                  painter: _RangePainter(
                    param: p,
                    low: p == AlarmParam.bladder ? null : limit.low,
                    high: limit.high,
                    value: value,
                    enabled: enabled,
                    track: AppColors.chip,
                    safe: _green.withValues(alpha: .35),
                    marker: active ? _red : AppColors.text,
                    rtl: Directionality.of(context) == TextDirection.rtl,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: () => _editLimits(context, service, p),
                icon: const Icon(Icons.tune_rounded, size: 17),
                label: const Text('Edit limits'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _editLimits(
    BuildContext context,
    AlarmService service,
    AlarmParam p,
  ) async {
    final limit = service.limits[p]!;
    final result = await showDialog<({double low, double high})>(
      context: context,
      builder: (_) => _LimitsDialog(param: p, low: limit.low, high: limit.high),
    );
    if (result != null) {
      service.setLimits(p, result.low, result.high);
    }
  }
}

/// Horizontal bar over the allowed range of a signal: the safe band between
/// the limits and a dot for the current reading.
class _RangePainter extends CustomPainter {
  final AlarmParam param;
  final double? low;
  final double high;
  final double? value;
  final bool enabled;
  final Color track;
  final Color safe;
  final Color marker;
  final bool rtl;

  _RangePainter({
    required this.param,
    required this.low,
    required this.high,
    required this.value,
    required this.enabled,
    required this.track,
    required this.safe,
    required this.marker,
    required this.rtl,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final range = AlarmService.allowedRange[param];
    if (range == null) return;
    final (minV, maxV) = param == AlarmParam.bladder ? (0.0, 100.0) : range;
    double x(double v) {
      final f = ((v - minV) / (maxV - minV)).clamp(0.0, 1.0);
      return (rtl ? 1 - f : f) * size.width;
    }

    final cy = size.height / 2;
    const h = 6.0;
    final r = const Radius.circular(3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, cy - h / 2, size.width, h), r),
      Paint()..color = track,
    );
    if (enabled) {
      final a = x(low ?? minV);
      final b = x(high);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(a < b ? a : b, cy - h / 2, a < b ? b : a, cy + h / 2),
          r,
        ),
        Paint()..color = safe,
      );
    }
    final v = value;
    if (v != null) {
      final cx = x(v);
      canvas.drawCircle(Offset(cx, cy), 6.5, Paint()..color = marker);
      canvas.drawCircle(
        Offset(cx, cy),
        6.5,
        Paint()
          ..color = track
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_RangePainter old) =>
      old.low != low ||
      old.high != high ||
      old.value != value ||
      old.enabled != enabled ||
      old.marker != marker ||
      old.track != track ||
      old.rtl != rtl;
}

class _LimitsDialog extends StatefulWidget {
  final AlarmParam param;
  final double low;
  final double high;

  const _LimitsDialog({
    required this.param,
    required this.low,
    required this.high,
  });

  @override
  State<_LimitsDialog> createState() => _LimitsDialogState();
}

class _LimitsDialogState extends State<_LimitsDialog> {
  late final TextEditingController _lowController;
  late final TextEditingController _highController;
  String? _error;

  bool get _onlyHigh => widget.param == AlarmParam.bladder;

  @override
  void initState() {
    super.initState();
    _lowController = TextEditingController(
      text: AlarmService.formatNumber(widget.param, widget.low),
    );
    _highController = TextEditingController(
      text: AlarmService.formatNumber(widget.param, widget.high),
    );
  }

  @override
  void dispose() {
    _lowController.dispose();
    _highController.dispose();
    super.dispose();
  }

  double? _parse(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  void _save() {
    final shownLow = _onlyHigh ? widget.low : _parse(_lowController);
    final shownHigh = _parse(_highController);

    if (shownLow == null || shownHigh == null) {
      setState(() => _error = 'Enter valid numbers');
      return;
    }

    // Temperature is typed in the unit chosen in Settings but stored in °C.
    var low = shownLow;
    var high = shownHigh;
    if (widget.param == AlarmParam.temperature) {
      low = SettingsStore.instance.fromDisplayTemp(shownLow);
      high = SettingsStore.instance.fromDisplayTemp(shownHigh);
    }
    // Refuse limits that would silently switch the alarm off.
    final problem = AlarmService.checkLimits(widget.param, low, high);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    Navigator.pop(context, (low: low, high: high));
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppColors.bg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.text.withValues(alpha: .07)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.text.withValues(alpha: .07)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _blue, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unit = AlarmService.unitOf(widget.param);
    const keyboard = TextInputType.numberWithOptions(decimal: true);

    return AlertDialog(
      backgroundColor: _card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        '${AlarmService.labelOf(widget.param)} limits',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_onlyHigh) ...[
            TextField(
              controller: _lowController,
              keyboardType: keyboard,
              decoration: _decoration('Low limit ($unit)'),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _highController,
            keyboardType: keyboard,
            decoration: _decoration('High limit ($unit)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(_error!, style: TextStyle(color: _red, fontSize: 12)),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
