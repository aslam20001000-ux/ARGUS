import 'package:flutter/material.dart';

import '../../core/alarm_service.dart';
import '../../core/app_colors.dart';
import '../../core/app_state.dart';
import '../../core/auth_service.dart';
import '../../core/page_route.dart';
import '../../core/responsive.dart';
import '../../core/settings_store.dart';
import '../../core/vitals_store.dart';
import '../../core/widgets/argus_eye.dart';
import '../bladder/bladder_page.dart';
import '../monitor/monitor_home.dart';
import '../profile/patient_profile_page.dart';
import 'app_drawer.dart';

const _blue = Color(0xFF54A9FF);
const _green = Color(0xFF38E08F);
const _red = Color(0xFFE65F72);
const _amber = Color(0xFFFFB454);

/// Home page: who is signed in, a live summary of the patient, the main
/// features and quick shortcuts.
class FeatureSelectionPage extends StatelessWidget {
  const FeatureSelectionPage({super.key});

  void _open(BuildContext context, Widget page) =>
      Navigator.push(context, appRoute<void>(page));

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
          ),
          body: SafeArea(
            child: ContentFrame(
              maxWidth: 1100,
              child: LayoutBuilder(
                builder: (context, box) {
                  final wide = box.maxWidth >= 720;
                  return ListView(
                    padding: EdgeInsets.fromLTRB(
                      wide ? 28 : 18,
                      6,
                      wide ? 28 : 18,
                      28,
                    ),
                    children: wide
                        ? _wideBody(context)
                        : _phoneBody(context),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _monitorCard(BuildContext context) => _bigCard(
    context,
    icon: Icons.monitor_heart,
    color: _blue,
    title: tr('Medical Monitor', 'مراقبة المريض'),
    subtitle: tr(
      'Live vital signs, ECG, SpO₂ and alarms',
      'العلامات الحيوية وتخطيط القلب والأكسجين والتنبيهات',
    ),
    onTap: () => _open(context, const MonitorHome()),
  );

  Widget _bladderTile(BuildContext context) => _tile(
    context,
    icon: Icons.water_drop_outlined,
    color: _green,
    title: tr('Bladder', 'المثانة'),
    subtitle: tr('Filling level from impedance', 'مستوى الامتلاء من المعاوقة'),
    onTap: () => _open(context, const BladderPage()),
  );

  Widget _patientTile(BuildContext context) => _tile(
    context,
    icon: Icons.badge_outlined,
    color: _blue,
    title: tr('Patient', 'المريض'),
    subtitle: tr(
      'Identity, history and medications',
      'البيانات والتاريخ المرضي والأدوية',
    ),
    onTap: () => _open(context, const PatientProfilePage()),
  );

  Widget _historyTile(BuildContext context) => _tile(
    context,
    icon: Icons.show_chart_rounded,
    color: _amber,
    title: tr('History', 'السجل'),
    subtitle: tr('Trends and PDF report', 'الرسوم البيانية وتقرير PDF'),
    compact: true,
    onTap: () => _open(context, const MonitorHome(initialIndex: 2)),
  );

  /// Phones: everything in one column.
  List<Widget> _phoneBody(BuildContext context) => [
    _hero(),
    const SizedBox(height: 14),
    _summary(context),
    _label(tr('FEATURES', 'الخدمات')),
    _monitorCard(context),
    const SizedBox(height: 12),
    AdaptiveGrid(
      columns: 2,
      children: [_bladderTile(context), _patientTile(context)],
    ),
    _label(tr('QUICK ACCESS', 'وصول سريع')),
    AdaptiveGrid(
      columns: 2,
      children: [_alarmsShortcut(context), _historyTile(context)],
    ),
  ];

  /// Tablets / desktop: welcome + live summary side by side, features in
  /// three columns.
  List<Widget> _wideBody(BuildContext context) => [
    IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 4, child: _hero()),
          const SizedBox(width: 16),
          Expanded(flex: 6, child: _summary(context)),
        ],
      ),
    ),
    _label(tr('FEATURES', 'الخدمات')),
    AdaptiveGrid(
      columns: 3,
      spacing: 16,
      children: [
        _tile(
          context,
          icon: Icons.monitor_heart,
          color: _blue,
          title: tr('Medical Monitor', 'مراقبة المريض'),
          subtitle: tr(
            'Live vital signs, ECG, SpO₂ and alarms',
            'العلامات الحيوية وتخطيط القلب والأكسجين والتنبيهات',
          ),
          onTap: () => _open(context, const MonitorHome()),
        ),
        _bladderTile(context),
        _patientTile(context),
      ],
    ),
    _label(tr('QUICK ACCESS', 'وصول سريع')),
    AdaptiveGrid(
      columns: 3,
      spacing: 16,
      children: [_alarmsShortcut(context), _historyTile(context)],
    ),
  ];

  // ---------------------------------------------------------------- pieces

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
    child: Text(
      text,
      style: TextStyle(
        color: AppColors.text.withValues(alpha: .42),
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
      ),
    ),
  );

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.cardAlt, AppColors.card],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _blue.withValues(alpha: .16)),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.card,
              border: Border.all(color: _blue.withValues(alpha: .4)),
            ),
            child: Center(
              child: CustomPaint(
                size: const Size(32, 20),
                painter: ArgusEyePainter(),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ValueListenableBuilder<String>(
              valueListenable: currentUserName,
              builder: (context, name, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('Welcome back', 'أهلاً بعودتك'),
                    style: TextStyle(
                      color: AppColors.text.withValues(alpha: .54),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name.trim().isEmpty ? 'ARGUS' : name.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                                  ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Live summary: patient + main readings + alarm status.
  Widget _summary(BuildContext context) {
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
        final active = alarms.activeCount;
        final hasAlarm = active > 0;
        final accent = hasAlarm ? _red : _green;
        final settings = SettingsStore.instance;
        final name = patientProfile.name.trim().isEmpty
            ? AuthService.accountName
            : patientProfile.name.trim();

        Widget metric(String label, String value, AlarmParam p) {
          final bad = alarms.levels[p] != AlarmLevel.normal;
          return Expanded(
            child: Column(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: bad ? _red : AppColors.text,
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
        }

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => _open(context, const MonitorHome()),
            child: Ink(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: hasAlarm ? AppColors.alarmCard : AppColors.card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: accent.withValues(alpha: .35)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Text(
                        hasAlarm
                            ? tr('$active alarm(s) active', '$active تنبيه نشط')
                            : tr('All normal', 'كل شيء طبيعي'),
                        style: TextStyle(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      metric('BPM', '${v.hr}', AlarmParam.heartRate),
                      metric('SpO₂', '${v.spo2}%', AlarmParam.spo2),
                      metric('RR', '${v.rr}', AlarmParam.respRate),
                      metric(
                        settings.tempSymbol,
                        settings.toDisplayTemp(v.temp).toStringAsFixed(1),
                        AlarmParam.temperature,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _bigCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withValues(alpha: .25)),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 31),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.text.withValues(alpha: .54),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.arrow_back_ios_new
                    : Icons.arrow_forward_ios,
                color: color,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool compact = false,
    Widget? badge,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: .22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .13),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: color, size: 25),
                  ),
                  const Spacer(),
                  badge ?? const SizedBox.shrink(),
                ],
              ),
              SizedBox(height: compact ? 12 : 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppColors.text.withValues(alpha: .54),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _alarmsShortcut(BuildContext context) {
    return ListenableBuilder(
      listenable: AlarmService.instance,
      builder: (context, _) {
        final active = AlarmService.instance.activeCount;
        return _tile(
          context,
          icon: Icons.notifications_active_outlined,
          color: active > 0 ? _red : _green,
          title: tr('Alarms', 'التنبيهات'),
          subtitle: active > 0
              ? tr('$active active now', '$active نشط الآن')
              : tr('Limits and alarm log', 'الحدود وسجل التنبيهات'),
          compact: true,
          badge: active > 0
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$active',
                    style:  TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                )
              : null,
          onTap: () => _open(context, const MonitorHome(initialIndex: 1)),
        );
      },
    );
  }
}
