import 'package:flutter/material.dart';

import '../../core/alarm_service.dart';
import '../../core/app_colors.dart';
import '../../core/report_service.dart';
import '../../core/responsive.dart';
import '../../core/settings_store.dart';
import '../../core/vitals_store.dart';
import 'trend_chart.dart';

Color get _blue => AppColors.blue;
Color get _green => AppColors.green;
Color get _red => AppColors.red;
Color get _amber => AppColors.amber;

/// Trends of every reading over the last minutes / hours, plus the alarm log.
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  static const _ranges = <(String, Duration)>[
    ('15 min', Duration(minutes: 15)),
    ('1 h', Duration(hours: 1)),
    ('6 h', Duration(hours: 6)),
    ('24 h', Duration(hours: 24)),
  ];

  int _rangeIndex = 0;
  bool _exporting = false;

  Duration get _range => _ranges[_rangeIndex].$2;

  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ReportService.shareReport(_range, _ranges[_rangeIndex].$1);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not create the report. Try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    if (mounted) setState(() => _exporting = false);
  }

  @override
  Widget build(BuildContext context) {
    final store = VitalsStore.instance;
    final settings = SettingsStore.instance;

    return ListenableBuilder(
      listenable: Listenable.merge([
        store.vitals,
        AlarmService.instance,
        settings,
      ]),
      builder: (context, _) {
        final samples = store.samplesWithin(_range);
        final alarms = AlarmService.instance;
        final from = DateTime.now().subtract(_range);
        final events = [
          for (final e in alarms.history)
            if (!e.time.isBefore(from)) e,
        ];

        return ContentFrame(
          maxWidth: 1100,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'History',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _exporting ? null : _export,
                    icon: _exporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf_rounded, size: 18),
                    label: const Text('PDF report'),
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
                      selected: _rangeIndex == i,
                      onSelected: (_) => setState(() => _rangeIndex = i),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (samples.length < 2)
                _emptyCard()
              else ...[
                // 1 column on phones, 2 columns on wide screens.
                AdaptiveGrid(
                  minTileWidth: 460,
                  maxColumns: 2,
                  children: [
                    _chartCard(
                      AlarmParam.heartRate,
                      samples,
                      _blue,
                      alarms,
                      settings,
                    ),
                    _chartCard(
                      AlarmParam.spo2,
                      samples,
                      _green,
                      alarms,
                      settings,
                    ),
                    _chartCard(
                      AlarmParam.respRate,
                      samples,
                      _amber,
                      alarms,
                      settings,
                    ),
                    _chartCard(
                      AlarmParam.temperature,
                      samples,
                      _red,
                      alarms,
                      settings,
                    ),
                    _chartCard(
                      AlarmParam.bladder,
                      samples,
                      _blue,
                      alarms,
                      settings,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Alarm log',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '${events.length} in this period',
                    style: TextStyle(
                      color: AppColors.text.withValues(alpha: .54),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (events.isEmpty)
                _card(
                  child: Text(
                    'No alarms in this period.',
                    style: TextStyle(
                      color: AppColors.text.withValues(alpha: .54),
                    ),
                  ),
                )
              else
                for (final e in events) _eventTile(e),
            ],
          ),
        );
      },
    );
  }

  Widget _card({required Widget child, Color? color, bool spaced = true}) =>
      Container(
        width: double.infinity,
        margin: EdgeInsets.only(bottom: spaced ? 12 : 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color ?? AppColors.card,
          borderRadius: BorderRadius.circular(18),
        ),
        child: child,
      );

  Widget _emptyCard() => _card(
    child: Column(
      children: [
        Icon(Icons.show_chart, size: 46, color: _blue),
        const SizedBox(height: 10),
        const Text(
          'Collecting data…',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Charts appear after about 20 seconds of readings.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.text.withValues(alpha: .54)),
        ),
      ],
    ),
  );

  Widget _chartCard(
    AlarmParam p,
    List<VitalsSample> samples,
    Color color,
    AlarmService alarms,
    SettingsStore settings,
  ) {
    double conv(double v) =>
        p == AlarmParam.temperature ? settings.toDisplayTemp(v) : v;

    // Only the samples that have a reading for this parameter.
    final valid = [
      for (final s in samples)
        if (AlarmService.valueOf(p, s.data) != null) s,
    ];
    final times = [for (final s in valid) s.time];
    final values = [
      for (final s in valid) conv(AlarmService.valueOf(p, s.data)!),
    ];
    double? minV, maxV, avg;
    if (values.isNotEmpty) {
      minV = values.reduce((a, b) => a < b ? a : b);
      maxV = values.reduce((a, b) => a > b ? a : b);
      avg = values.reduce((a, b) => a + b) / values.length;
    }

    final limit = alarms.limits[p]!;
    final lowLimit = (limit.enabled && p != AlarmParam.bladder)
        ? conv(limit.low)
        : null;
    final highLimit = limit.enabled ? conv(limit.high) : null;

    String f(double? v) => showDouble(v, p == AlarmParam.temperature ? 1 : 0);
    final unit = AlarmService.unitOf(p);

    return _card(
      spaced: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AlarmService.labelOf(p),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                'min ${f(minV)}  •  avg ${f(avg)}  •  max ${f(maxV)} $unit',
                style: TextStyle(
                  color: AppColors.text.withValues(alpha: .6),
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 130,
            child: TrendChart(
              times: times,
              values: values,
              range: _range,
              color: color,
              lowLimit: lowLimit,
              highLimit: highLimit,
              decimals: p == AlarmParam.temperature ? 1 : 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _eventTile(AlarmEvent e) {
    final isLow = e.level == AlarmLevel.low;
    final color = e.level == AlarmLevel.alert ? _red : (isLow ? _amber : _red);
    final t = e.time;
    String two(int n) => n.toString().padLeft(2, '0');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        boxShadow: AppColors.cardShadow,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.message,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${AlarmService.labelOf(e.param)} • ${e.valueText}',
                  style: TextStyle(
                    color: AppColors.text.withValues(alpha: .54),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${two(t.hour)}:${two(t.minute)}:${two(t.second)}',
            style: TextStyle(
              color: AppColors.text.withValues(alpha: .54),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
