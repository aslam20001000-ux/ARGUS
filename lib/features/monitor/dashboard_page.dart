import 'package:flutter/material.dart';

import '../../core/device_service.dart';
import '../../core/alarm_service.dart';
import '../../core/app_colors.dart';
import '../../core/app_state.dart';
import '../../core/page_route.dart';
import '../../core/responsive.dart';
import '../../core/settings_store.dart';
import '../../core/vitals_store.dart';
import '../../core/widgets/vital_card.dart';
import '../../core/widgets/waveform_card.dart';
import '../bladder/bladder_page.dart';
import '../profile/patient_profile_page.dart';
import 'ews_card.dart';
import 'vital_detail_sheet.dart';

Color get _green => AppColors.green;
Color get _red => AppColors.red;
Color get _amber => AppColors.amber;
Color get _cyan => AppColors.cyan;
Color get _orange => AppColors.orange;

/// Bedside-monitor style overview: patient strip, big ECG trace and one card
/// per reading (with a short trend line and its alarm limits).
class DashboardPage extends StatelessWidget {
  final String patientName;
  // null = no reading (shown as "--").
  final int? heartRate;
  final int? spo2;
  final int? respiratoryRate;
  final double? temperature;

  const DashboardPage({
    super.key,
    required this.patientName,
    required this.heartRate,
    required this.spo2,
    required this.respiratoryRate,
    required this.temperature,
  });

  @override
  Widget build(BuildContext context) {
    final service = AlarmService.instance;
    final settings = SettingsStore.instance;

    return ListenableBuilder(
      listenable: Listenable.merge([service, settings]),
      builder: (context, _) {
        final ecgAlarm = service.levels[AlarmParam.ecg] != AlarmLevel.normal;
        final samples = VitalsStore.instance.samplesWithin(
          const Duration(minutes: 5),
        );

        /// Trend values of one reading (temperature in the chosen unit).
        List<double> trendOf(AlarmParam p) => [
          for (final s in samples)
            if (AlarmService.valueOf(p, s.data) case final v?)
              p == AlarmParam.temperature ? settings.toDisplayTemp(v) : v,
        ];

        String limitsText(AlarmParam p) {
          final l = service.limits[p]!;
          if (!l.enabled) return 'Alarm off';
          final unit = AlarmService.unitOf(p);
          String f(double v) => AlarmService.formatNumber(p, v);
          return p == AlarmParam.bladder
              ? 'Alarm above ${f(l.high)}$unit'
              : 'Limits ${f(l.low)} – ${f(l.high)} $unit';
        }

        Widget vital(
          AlarmParam p,
          String title,
          String value,
          String unit,
          IconData icon,
          Color color, {
          VoidCallback? onTap,
        }) {
          // Tap a card for a bigger chart with min / average / max.
          return GestureDetector(
            onTap:
                onTap ??
                () => showVitalDetail(
                  context,
                  param: p,
                  title: title,
                  color: color,
                ),
            child: VitalCard(
              title: title,
              value: value,
              unit: unit,
              icon: icon,
              color: color,
              status: service.statusLabel(p),
              alarm: service.levels[p] != AlarmLevel.normal,
              trend: trendOf(p),
              footer: limitsText(p),
              pulseBpm: p == AlarmParam.heartRate ? heartRate : null,
            ),
          );
        }

        final bladderValue = VitalsStore.instance.vitals.value.bladderPercent;

        final hr = vital(
          AlarmParam.heartRate,
          'Heart Rate',
          showInt(heartRate),
          'BPM',
          Icons.favorite,
          _green,
        );
        final sp = vital(
          AlarmParam.spo2,
          'SpO₂',
          showInt(spo2),
          '%',
          Icons.air,
          _cyan,
        );
        final rr = vital(
          AlarmParam.respRate,
          'Resp. Rate',
          showInt(respiratoryRate),
          'RPM',
          Icons.waves,
          _amber,
        );
        final tp = vital(
          AlarmParam.temperature,
          'Temperature',
          showDouble(
            temperature == null ? null : settings.toDisplayTemp(temperature!),
            1,
          ),
          settings.tempSymbol,
          Icons.thermostat,
          _orange,
        );
        final bl = vital(
          AlarmParam.bladder,
          'Bladder',
          showDouble(bladderValue, 0),
          '%',
          Icons.water_drop,
          AppColors.violet,
          onTap: () =>
              Navigator.push(context, appRoute<void>(const BladderPage())),
        );
        final ews = EwsCard(vitals: VitalsStore.instance.vitals.value);

        return ContentFrame(
          maxWidth: 1200,
          child: LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth;
              final ecgHeight = w >= 900 ? 280.0 : (w >= 600 ? 230.0 : 190.0);

              final ecg = WaveformCard(
                title: 'ECG  •  Lead II',
                color: ecgAlarm ? _red : _green,
                height: ecgHeight,
                heartRate: heartRate,
              );

              // Phone: 2 cards per row. Tablet: 4 in a row. Desktop: all 5.
              final Widget tiles = w >= 900
                  ? AdaptiveGrid(columns: 5, children: [hr, sp, rr, tp, bl])
                  : Column(
                      children: [
                        AdaptiveGrid(
                          columns: w >= 600 ? 4 : 2,
                          children: [hr, sp, rr, tp],
                        ),
                        const SizedBox(height: 12),
                        bl,
                      ],
                    );

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _patientStrip(context, service.activeCount),
                    const SizedBox(height: 14),
                    // Desktop: ECG and the warning score side by side.
                    if (w >= 900)
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(flex: 7, child: ecg),
                            const SizedBox(width: 14),
                            Expanded(flex: 4, child: ews),
                          ],
                        ),
                      )
                    else ...[
                      ecg,
                      const SizedBox(height: 14),
                      ews,
                    ],
                    const SizedBox(height: 14),
                    tiles,
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// Patient banner (same style as the home page): name and details on the
  /// left, alarm and device status on the right. Opens the patient profile.
  Widget _patientStrip(BuildContext context, int activeAlarms) {
    final alarm = activeAlarms > 0;
    final p = patientProfile;
    final details = [
      p.id,
      if (p.room.isNotEmpty) p.room,
      if (p.age.isNotEmpty) '${p.age} y',
      if (p.gender.isNotEmpty) p.gender,
      if (p.bloodGroup.isNotEmpty) p.bloodGroup,
    ].join('  •  ');

    Widget pill(String text, IconData icon, Color dot) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: dot),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: dot,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );

    const okColor = Color(0xFF7CF0B8);
    const badColor = Color(0xFFFFB3BF);

    final statusPills = [
      alarm
          ? pill(
              '$activeAlarms alarm${activeAlarms == 1 ? '' : 's'}',
              Icons.warning_amber_rounded,
              badColor,
            )
          : pill('All normal', Icons.check_circle_rounded, okColor),
      ListenableBuilder(
        listenable: DeviceService.instance,
        builder: (context, _) {
          if (!VitalsStore.instance.usingDevice) {
            return pill(
              'Demo data',
              Icons.science_outlined,
              Colors.white.withValues(alpha: .85),
            );
          }
          return DeviceService.instance.connected
              ? pill('Live device', Icons.wifi_rounded, okColor)
              : pill('Device lost', Icons.link_off_rounded, badColor);
        },
      ),
    ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () =>
            Navigator.push(context, appRoute<void>(const PatientProfilePage())),
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: alarm
                  ? const [
                      Color(0xFFB8324A),
                      Color(0xFF8E2238),
                      Color(0xFF5E1627),
                    ]
                  : AppColors.heroGradient,
            ),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 12,
            spacing: 12,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: .16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .35),
                      ),
                    ),
                    child: Text(
                      _initials(patientName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patientName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          details,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .72),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Wrap(spacing: 8, runSpacing: 8, children: statusPills),
            ],
          ),
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}
