import 'package:flutter/material.dart';

import '../../core/alarm_service.dart';
import '../../core/app_colors.dart';
import '../../core/report_service.dart';
import '../../core/responsive.dart';
import '../../core/settings_store.dart';
import '../../core/vitals_store.dart';
import '../../core/widgets/ui.dart';
import 'trend_chart.dart';

Color get _blue => AppColors.blue;
Color get _cyan => AppColors.cyan;
Color get _green => AppColors.green;
Color get _amber => AppColors.amber;
Color get _orange => AppColors.orange;
Color get _violet => AppColors.violet;

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

        final charts = [
          (AlarmParam.heartRate, Icons.favorite_rounded, _green),
          (AlarmParam.spo2, Icons.water_drop_rounded, _cyan),
          (AlarmParam.respRate, Icons.air_rounded, _amber),
          (AlarmParam.temperature, Icons.thermostat_rounded, _orange),
          (AlarmParam.bladder, Icons.opacity_rounded, _violet),
        ];

        return ContentFrame(
          maxWidth: 1100,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
            children: [
              PageHeader(
                title: 'History',
                subtitle: 'Trends of every reading and the alarm log',
                trailing: FilledButton.icon(
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
              ),
              Row(
                children: [
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: [
                      for (var i = 0; i < _ranges.length; i++)
                        ButtonSegment(value: i, label: Text(_ranges[i].$1)),
                    ],
                    selected: {_rangeIndex},
                    onSelectionChanged: (s) =>
                        setState(() => _rangeIndex = s.first),
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SummaryStrip(
                readings: samples.length,
                alarms: events.length,
                covered: samples.length < 2
                    ? Duration.zero
                    : samples.last.time.difference(samples.first.time),
              ),
              const SizedBox(height: 14),
              if (samples.length < 2)
                AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  child: EmptyState(
                    icon: Icons.insights_rounded,
                    color: _blue,
                    title: 'Collecting data…',
                    text:
                        'A reading is saved every '
                        '${VitalsStore.sampleEvery.inSeconds} s. Charts appear '
                        'after the first two.',
                  ),
                )
              else
                // 1 column on phones, 2 columns on wide screens.
                AdaptiveGrid(
                  minTileWidth: 460,
                  maxColumns: 2,
                  children: [
                    for (final (p, icon, color) in charts)
                      _chartCard(p, icon, color, samples, alarms, settings),
                  ],
                ),
              SectionHeading(
                'Alarm log',
                action: Text(
                  '${events.length} in the last ${_ranges[_rangeIndex].$1}',
                  style: TextStyle(
                    color: AppColors.text.withValues(alpha: .5),
                    fontSize: 12,
                  ),
                ),
              ),
              AlarmLogCard(
                events: events,
                showClock: true,
                emptyTitle: 'No alarms in this period',
                emptyText: 'Every reading stayed inside its limits.',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chartCard(
    AlarmParam p,
    IconData icon,
    Color color,
    List<VitalsSample> samples,
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

    final decimals = p == AlarmParam.temperature ? 1 : 0;
    String f(double? v) => showDouble(v, decimals);
    final unit = AlarmService.unitOf(p);
    final now = values.isEmpty ? null : values.last;

    Widget stat(String label, double? v) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.chip,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              f(v),
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                color: AppColors.text.withValues(alpha: .5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardTitle(
            icon: icon,
            color: color,
            title: AlarmService.labelOf(p),
            subtitle: unit.isEmpty ? null : unit,
            trailing: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: f(now)),
                  if (now != null)
                    TextSpan(
                      text: ' $unit',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text.withValues(alpha: .5),
                      ),
                    ),
                ],
              ),
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 130,
            child: TrendChart(
              times: times,
              values: values,
              range: _range,
              color: color,
              lowLimit: lowLimit,
              highLimit: highLimit,
              decimals: decimals,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              stat('MIN', minV),
              const SizedBox(width: 8),
              stat('AVG', avg),
              const SizedBox(width: 8),
              stat('MAX', maxV),
            ],
          ),
        ],
      ),
    );
  }
}

/// Readings saved, alarms and time covered in the chosen period.
class _SummaryStrip extends StatelessWidget {
  final int readings;
  final int alarms;
  final Duration covered;

  const _SummaryStrip({
    required this.readings,
    required this.alarms,
    required this.covered,
  });

  static String _duration(Duration d) {
    if (d.inMinutes < 1) return '${d.inSeconds} s';
    if (d.inHours < 1) return '${d.inMinutes} min';
    final m = d.inMinutes % 60;
    return m == 0 ? '${d.inHours} h' : '${d.inHours} h $m min';
  }

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, Color color, String value, String label) =>
        Expanded(
          child: Row(
            children: [
              IconBox(icon: icon, color: color, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.text.withValues(alpha: .5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          item(Icons.storage_rounded, _blue, '$readings', 'Readings'),
          item(
            Icons.notifications_active_rounded,
            alarms > 0 ? AppColors.red : _green,
            '$alarms',
            'Alarms',
          ),
          item(Icons.schedule_rounded, _amber, _duration(covered), 'Covered'),
        ],
      ),
    );
  }
}
