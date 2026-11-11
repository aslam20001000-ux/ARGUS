import 'package:flutter/material.dart';

import '../../core/alarm_service.dart';
import '../../core/app_colors.dart';
import '../../core/settings_store.dart';
import '../../core/vitals_store.dart';
import 'trend_chart.dart';

/// Bottom sheet with a big chart and min / average / max of one reading.
void showVitalDetail(
  BuildContext context, {
  required AlarmParam param,
  required String title,
  required Color color,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    constraints: const BoxConstraints(maxWidth: 720),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (_) => _VitalDetailSheet(param: param, title: title, color: color),
  );
}

class _VitalDetailSheet extends StatefulWidget {
  final AlarmParam param;
  final String title;
  final Color color;

  const _VitalDetailSheet({
    required this.param,
    required this.title,
    required this.color,
  });

  @override
  State<_VitalDetailSheet> createState() => _VitalDetailSheetState();
}

class _VitalDetailSheetState extends State<_VitalDetailSheet> {
  static const _ranges = <(String, Duration)>[
    ('5 min', Duration(minutes: 5)),
    ('15 min', Duration(minutes: 15)),
    ('1 h', Duration(hours: 1)),
  ];
  int _range = 1;

  @override
  Widget build(BuildContext context) {
    final p = widget.param;
    final store = VitalsStore.instance;
    final settings = SettingsStore.instance;

    return ListenableBuilder(
      listenable: Listenable.merge([store.vitals, settings]),
      builder: (context, _) {
        double conv(double v) =>
            p == AlarmParam.temperature ? settings.toDisplayTemp(v) : v;
        String f(double v) => p == AlarmParam.temperature
            ? v.toStringAsFixed(1)
            : v.toStringAsFixed(0);

        final duration = _ranges[_range].$2;
        final samples = store.samplesWithin(duration);
        final times = [for (final s in samples) s.time];
        final values = [
          for (final s in samples) conv(AlarmService.valueOf(p, s.data)),
        ];
        final now = conv(AlarmService.valueOf(p, store.vitals.value));
        final limit = AlarmService.instance.limits[p]!;
        final unit = AlarmService.unitOf(p);

        Widget stat(String label, String value) => Expanded(
          child: Column(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.text.withValues(alpha: .5),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        );

        double? minV, maxV, avg;
        if (values.isNotEmpty) {
          minV = values.reduce((a, b) => a < b ? a : b);
          maxV = values.reduce((a, b) => a > b ? a : b);
          avg = values.reduce((a, b) => a + b) / values.length;
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '${f(now)} $unit',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: widget.color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (var i = 0; i < _ranges.length; i++)
                      ChoiceChip(
                        label: Text(_ranges[i].$1),
                        selected: _range == i,
                        onSelected: (_) => setState(() => _range = i),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 190,
                  child: values.length < 2
                      ? Center(
                          child: Text(
                            'Collecting data…',
                            style: TextStyle(
                              color: AppColors.text.withValues(alpha: .5),
                            ),
                          ),
                        )
                      : TrendChart(
                          times: times,
                          values: values,
                          range: duration,
                          color: widget.color,
                          lowLimit: (limit.enabled && p != AlarmParam.bladder)
                              ? conv(limit.low)
                              : null,
                          highLimit: limit.enabled ? conv(limit.high) : null,
                          decimals: p == AlarmParam.temperature ? 1 : 0,
                        ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    stat('MIN', minV == null ? '-' : f(minV)),
                    stat('AVERAGE', avg == null ? '-' : f(avg)),
                    stat('MAX', maxV == null ? '-' : f(maxV)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Dashed red lines are the alarm limits.',
                  style: TextStyle(
                    color: AppColors.text.withValues(alpha: .4),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
