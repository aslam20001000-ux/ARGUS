import 'package:flutter/material.dart';

import '../../core/alarm_service.dart';
import '../../core/app_colors.dart';
import '../../core/app_state.dart';
import '../../core/auth_service.dart';
import '../../core/device_service.dart';
import '../../core/ews.dart';
import '../../core/page_route.dart';
import '../../core/responsive.dart';
import '../../core/settings_store.dart';
import '../../core/vitals_store.dart';
import '../bladder/bladder_page.dart';
import '../monitor/monitor_home.dart';
import '../profile/patient_profile_page.dart';
import 'app_drawer.dart';

Color get _blue => AppColors.blue;
Color get _cyan => AppColors.cyan;
Color get _green => AppColors.green;
Color get _red => AppColors.red;
Color get _amber => AppColors.amber;
Color get _violet => AppColors.violet;

void _open(BuildContext context, Widget page) =>
    Navigator.push(context, appRoute<void>(page));

bool _rtl(BuildContext context) =>
    Directionality.of(context) == TextDirection.rtl;

/// Home page: greeting, a live patient overview, the app's modules and the
/// latest alarms.
class FeatureSelectionPage extends StatelessWidget {
  const FeatureSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isArabic,
      builder: (context, arabic, _) => Directionality(
        textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          backgroundColor: AppColors.bg,
          drawer: const AppDrawer(current: AppSection.home),
          appBar: AppBar(
            backgroundColor: AppColors.bg,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            elevation: 0,
            toolbarHeight: 52,
            automaticallyImplyLeading: false,
            leading: const DrawerMenuButton(),
            actions: const [
              Padding(
                padding: EdgeInsetsDirectional.only(end: 14),
                child: _DeviceChip(),
              ),
            ],
          ),
          body: SafeArea(
            child: ContentFrame(
              maxWidth: 1120,
              child: LayoutBuilder(
                builder: (context, box) {
                  final wide = box.maxWidth >= 860;
                  final side = wide ? 28.0 : 18.0;
                  return ListView(
                    padding: EdgeInsets.fromLTRB(side, 4, side, 32),
                    children: wide ? _wideBody() : _phoneBody(),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _phoneBody() => const [
    _Greeting(),
    SizedBox(height: 16),
    _PatientHero(wide: false),
    _SectionLabel(en: 'Modules', ar: 'الأقسام'),
    _Modules(),
    _RecentAlarms(),
  ];

  List<Widget> _wideBody() => const [
    _Greeting(),
    SizedBox(height: 18),
    IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 7, child: _PatientHero(wide: true)),
          SizedBox(width: 18),
          Expanded(flex: 5, child: _Modules()),
        ],
      ),
    ),
    _RecentAlarms(),
  ];
}

// ================================================================ greeting

class _Greeting extends StatelessWidget {
  const _Greeting();

  static const _daysEn = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _daysAr = [
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];
  static const _monthsEn = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const _monthsAr = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? tr('Good morning', 'صباح الخير')
        : now.hour < 18
        ? tr('Good afternoon', 'مساء الخير')
        : tr('Good evening', 'مساء الخير');
    final date = isArabic.value
        ? '${_daysAr[now.weekday - 1]}، ${now.day} ${_monthsAr[now.month - 1]}'
        : '${_daysEn[now.weekday - 1]}, ${_monthsEn[now.month - 1]} ${now.day}';

    return ValueListenableBuilder<String>(
      valueListenable: currentUserName,
      builder: (context, name, _) {
        final shown = name.trim().isEmpty
            ? AuthService.accountName
            : name.trim();
        final first = shown.split(RegExp(r'\s+')).first;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                date.toUpperCase(),
                style: TextStyle(
                  color: AppColors.text.withValues(alpha: .45),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                first.isEmpty ? greeting : '$greeting, $first',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 26,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tr(
                  'Here is how your patient is doing right now.',
                  'هذه حالة المريض الآن.',
                ),
                style: TextStyle(
                  color: AppColors.text.withValues(alpha: .55),
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Small "Live / Demo / Offline" chip in the app bar.
class _DeviceChip extends StatelessWidget {
  const _DeviceChip();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DeviceService.instance,
      builder: (context, _) {
        final (
          Color color,
          String text,
        ) = switch (DeviceService.instance.status) {
          DeviceStatus.connected => (_green, tr('Live', 'متصل')),
          DeviceStatus.connecting => (_amber, tr('Connecting', 'جارٍ الاتصال')),
          DeviceStatus.lost => (_red, tr('Offline', 'غير متصل')),
          DeviceStatus.off => (_blue, tr('Demo data', 'بيانات تجريبية')),
        };
        return Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: color.withValues(alpha: .3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  text,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
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

// ============================================================ patient hero

class _PatientHero extends StatelessWidget {
  final bool wide;
  const _PatientHero({required this.wide});

  @override
  Widget build(BuildContext context) {
    final store = VitalsStore.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([
        store.vitals,
        AlarmService.instance,
        SettingsStore.instance,
      ]),
      builder: (context, _) {
        final v = store.vitals.value;
        final alarms = AlarmService.instance;
        final settings = SettingsStore.instance;
        final active = alarms.activeCount;
        final ews = Ews.compute(v);
        final p = patientProfile;
        final name = p.name.trim().isEmpty
            ? AuthService.accountName
            : p.name.trim();

        bool bad(AlarmParam param) => alarms.levels[param] != AlarmLevel.normal;

        final vitals = [
          _HeroVital(
            icon: Icons.favorite_rounded,
            label: tr('Heart rate', 'النبض'),
            value: showInt(v.hr),
            unit: 'bpm',
            alarm: bad(AlarmParam.heartRate),
          ),
          _HeroVital(
            icon: Icons.water_drop_rounded,
            label: 'SpO₂',
            value: showInt(v.spo2),
            unit: '%',
            alarm: bad(AlarmParam.spo2),
          ),
          _HeroVital(
            icon: Icons.air_rounded,
            label: tr('Resp. rate', 'التنفس'),
            value: showInt(v.rr),
            unit: '/min',
            alarm: bad(AlarmParam.respRate),
          ),
          _HeroVital(
            icon: Icons.thermostat_rounded,
            label: tr('Temperature', 'الحرارة'),
            value: showDouble(
              v.temp == null ? null : settings.toDisplayTemp(v.temp!),
              1,
            ),
            unit: settings.tempSymbol,
            alarm: bad(AlarmParam.temperature),
          ),
        ];

        // Tablets in portrait have room for all four in one row.
        final perRow = wide || MediaQuery.sizeOf(context).width >= 560 ? 4 : 2;

        final waiting = active == 0 && !v.hasAny;
        final statusColor = active > 0
            ? const Color(0xFFFF8597)
            : waiting
            ? Colors.white.withValues(alpha: .8)
            : const Color(0xFF7CF0B8);
        final statusText = active > 0
            ? tr(
                '$active alarm${active == 1 ? '' : 's'} active',
                '$active تنبيه نشط',
              )
            : waiting
            ? tr('Waiting for data', 'في انتظار القراءات')
            : tr('Stable', 'مستقر');
        final statusIcon = active > 0
            ? Icons.warning_amber_rounded
            : waiting
            ? Icons.hourglass_empty_rounded
            : Icons.check_circle_rounded;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(26),
            onTap: () => _open(context, const MonitorHome()),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: active > 0
                      ? const [
                          Color(0xFFB8324A),
                          Color(0xFF8E2238),
                          Color(0xFF5E1627),
                        ]
                      : AppColors.heroGradient,
                ),
              ),
              padding: EdgeInsets.all(wide ? 24 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ----- patient row
                  Row(
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
                          _initials(name),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
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
                              [
                                p.id,
                                if (p.room.isNotEmpty) p.room,
                              ].join('  •  '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .7),
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .18),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 14, color: statusColor),
                            const SizedBox(width: 5),
                            Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: wide ? 22 : 18),

                  // ----- vitals
                  // (No LayoutBuilder: the wide layout measures this card
                  // with IntrinsicHeight.)
                  for (var r = 0; r < vitals.length; r += perRow) ...[
                    if (r > 0) const SizedBox(height: 10),
                    Row(
                      children: [
                        for (var i = r; i < r + perRow; i++) ...[
                          if (i > r) const SizedBox(width: 10),
                          Expanded(child: vitals[i]),
                        ],
                      ],
                    ),
                  ],
                  if (wide) const Spacer() else const SizedBox(height: 16),
                  if (wide) const SizedBox(height: 18),

                  // ----- early warning score + open monitor
                  _EwsBar(ews: ews),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeroVital extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final bool alarm;

  const _HeroVital({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.alarm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: alarm
            ? Colors.white.withValues(alpha: .24)
            : Colors.white.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: alarm
              ? Colors.white.withValues(alpha: .7)
              : Colors.white.withValues(alpha: .14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: Colors.white.withValues(alpha: .8)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .75),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (alarm)
                const Icon(Icons.error_rounded, size: 15, color: Colors.white),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: value),
                  if (value != '--')
                    TextSpan(
                      text: ' $unit',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: .65),
                      ),
                    ),
                ],
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EwsBar extends StatelessWidget {
  final EwsResult ews;
  const _EwsBar({required this.ews});

  @override
  Widget build(BuildContext context) {
    final (Color color, String risk) = ews.noData
        ? (Colors.white.withValues(alpha: .6), tr('No data', 'لا توجد بيانات'))
        : switch (ews.risk) {
            EwsRisk.low => (
              const Color(0xFF7CF0B8),
              tr('Low risk', 'خطر منخفض'),
            ),
            EwsRisk.medium => (
              const Color(0xFFFFD27A),
              tr('Medium risk', 'خطر متوسط'),
            ),
            EwsRisk.high => (
              const Color(0xFFFF8597),
              tr('High risk', 'خطر مرتفع'),
            ),
          };
    final fraction = ews.noData ? 0.0 : ews.score / EwsResult.maxScore;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      tr('Early warning score', 'مؤشر الإنذار المبكر'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .75),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      ews.noData
                          ? risk
                          : '${ews.score}/${EwsResult.maxScore}  •  $risk',
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 6,
                    color: color,
                    backgroundColor: Colors.white.withValues(alpha: .14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _rtl(context)
                  ? Icons.arrow_back_rounded
                  : Icons.arrow_forward_rounded,
              size: 19,
              color: AppColors.heroGradient[1],
            ),
          ),
        ],
      ),
    );
  }
}

String _initials(String name) {
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

// ================================================================= modules

class _Modules extends StatelessWidget {
  const _Modules();

  @override
  Widget build(BuildContext context) {
    final store = VitalsStore.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([store.vitals, AlarmService.instance]),
      builder: (context, _) {
        final v = store.vitals.value;
        final bladder = v.bladderPercent;
        final bladderLimit =
            AlarmService.instance.limits[AlarmParam.bladder]!.high;
        final bladderColor = bladder == null
            ? AppColors.text.withValues(alpha: .4)
            : bladder >= bladderLimit
            ? _red
            : bladder >= 60
            ? _amber
            : _green;
        final p = patientProfile;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ModuleCard(
              icon: Icons.monitor_heart_rounded,
              color: _blue,
              title: tr('Medical Monitor', 'مراقبة المريض'),
              subtitle: tr(
                'Live ECG, vitals and alarms',
                'تخطيط القلب والعلامات الحيوية والتنبيهات',
              ),
              trailing: _MiniStat(
                value: showInt(v.hr),
                label: 'bpm',
                color: _blue,
              ),
              onTap: () => _open(context, const MonitorHome()),
            ),
            const SizedBox(height: 12),
            _ModuleCard(
              icon: Icons.water_drop_rounded,
              color: _cyan,
              title: tr('Bladder', 'المثانة'),
              subtitle: tr(
                'Filling level from bio-impedance',
                'مستوى الامتلاء من المعاوقة',
              ),
              trailing: _MiniStat(
                value: bladder == null ? '--' : '${bladder.round()}%',
                label: tr('filled', 'ممتلئ'),
                color: bladderColor,
              ),
              progress: bladder == null ? null : bladder / 100,
              progressColor: bladderColor,
              onTap: () => _open(context, const BladderPage()),
            ),
            const SizedBox(height: 12),
            _ModuleCard(
              icon: Icons.badge_rounded,
              color: _violet,
              title: tr('Patient Profile', 'ملف المريض'),
              subtitle:
                  [
                        if (p.age.isNotEmpty) '${p.age} y',
                        if (p.bloodGroup.isNotEmpty) p.bloodGroup,
                        if (p.doctor.isNotEmpty) p.doctor,
                      ]
                      .join('  •  ')
                      .ifEmpty(
                        tr(
                          'Identity, history and medications',
                          'البيانات والأدوية',
                        ),
                      ),
              onTap: () => _open(context, const PatientProfilePage()),
            ),
            const SizedBox(height: 12),
            _ModuleCard(
              icon: Icons.insights_rounded,
              color: _amber,
              title: tr('History & Reports', 'السجل والتقارير'),
              subtitle: tr(
                'Trends over 24 h and PDF report',
                'الرسوم البيانية وتقرير PDF',
              ),
              onTap: () => _open(context, const MonitorHome(initialIndex: 2)),
            ),
          ],
        );
      },
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final double? progress;
  final Color? progressColor;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.progress,
    this.progressColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .13),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: color, size: 23),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.text.withValues(alpha: .55),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 10),
                      trailing!,
                    ],
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.text.withValues(alpha: .3),
                    ),
                  ],
                ),
                if (progress != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      color: progressColor ?? color,
                      backgroundColor: AppColors.chip,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _MiniStat({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: AppColors.text.withValues(alpha: .45),
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ========================================================== recent alarms

class _SectionLabel extends StatelessWidget {
  final String en;
  final String ar;
  final Widget? action;

  const _SectionLabel({required this.en, required this.ar, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 0, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              tr(en, ar),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class _RecentAlarms extends StatelessWidget {
  const _RecentAlarms();

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return tr('just now', 'الآن');
    final m = d.inMinutes;
    if (m < 60) return tr('$m min ago', 'منذ $m د');
    if (d.inHours < 24) return tr('${d.inHours} h ago', 'منذ ${d.inHours} س');
    return tr('${d.inDays} d ago', 'منذ ${d.inDays} يوم');
  }

  static IconData _icon(AlarmParam p) => switch (p) {
    AlarmParam.heartRate => Icons.favorite_rounded,
    AlarmParam.spo2 => Icons.water_drop_rounded,
    AlarmParam.respRate => Icons.air_rounded,
    AlarmParam.temperature => Icons.thermostat_rounded,
    AlarmParam.ecg => Icons.monitor_heart_rounded,
    AlarmParam.bladder => Icons.opacity_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AlarmService.instance,
      builder: (context, _) {
        final events = AlarmService.instance.history.take(3).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionLabel(
              en: 'Recent alarms',
              ar: 'آخر التنبيهات',
              action: TextButton(
                onPressed: () =>
                    _open(context, const MonitorHome(initialIndex: 1)),
                child: Text(tr('View all', 'عرض الكل')),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.cardShadow,
              ),
              child: events.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 22,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _green.withValues(alpha: .13),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.verified_rounded,
                              color: _green,
                              size: 21,
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr('No alarms so far', 'لا توجد تنبيهات'),
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tr(
                                    'Every reading has stayed inside its limits.',
                                    'كل القراءات داخل الحدود.',
                                  ),
                                  style: TextStyle(
                                    color: AppColors.text.withValues(
                                      alpha: .55,
                                    ),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < events.length; i++) ...[
                          if (i > 0)
                            Divider(
                              height: 1,
                              indent: 66,
                              endIndent: 16,
                              color: AppColors.border,
                            ),
                          _alarmRow(events[i]),
                        ],
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _alarmRow(AlarmEvent e) {
    final color = e.level == AlarmLevel.low ? _amber : _red;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_icon(e.param), color: color, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _ago(e.time),
                  style: TextStyle(
                    color: AppColors.text.withValues(alpha: .5),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            e.valueText,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
