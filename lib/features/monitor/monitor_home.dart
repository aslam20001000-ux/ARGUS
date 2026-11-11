import 'package:flutter/material.dart';

import '../../core/alarm_service.dart';
import '../../core/app_state.dart';
import '../../core/auth_service.dart';
import '../../core/vitals_store.dart';
import '../home/app_drawer.dart';
import '../settings/settings_page.dart';
import 'alarm_page.dart';
import 'dashboard_page.dart';
import 'history_page.dart';
import '../../core/app_colors.dart';

class MonitorHome extends StatefulWidget {
  /// Which tab opens first: 0 Dashboard, 1 Alarms, 2 History, 3 Settings.
  final int initialIndex;

  const MonitorHome({super.key, this.initialIndex = 0});

  @override
  State<MonitorHome> createState() => _MonitorHomeState();
}

class _MonitorHomeState extends State<MonitorHome> {
  late int currentIndex = widget.initialIndex;

  final VitalsStore store = VitalsStore.instance;

  int get heartRate => store.vitals.value.hr;
  int get spo2 => store.vitals.value.spo2;
  int get respiratoryRate => store.vitals.value.rr;
  double get temperature => store.vitals.value.temp;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The patient's name comes from the patient profile (not from the login).
    final patientName = patientProfile.name.trim().isEmpty
        ? AuthService.accountName
        : patientProfile.name.trim();

    final pages = [
      DashboardPage(
        patientName: patientName,
        heartRate: heartRate,
        spo2: spo2,
        respiratoryRate: respiratoryRate,
        temperature: temperature,
      ),
      const AlarmPage(),
      const HistoryPage(),
      const SettingsPage(),
    ];

    // Big screens (desktop / wide tablet): side navigation instead of the
    // bottom bar.
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final content = AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      reverseDuration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0.035, 0),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slideAnimation, child: child),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<int>(currentIndex),
        child: pages[currentIndex],
      ),
    );

    return Scaffold(
      drawer: const AppDrawer(current: AppSection.monitor),
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
        child: wide
            ? Row(
                children: [
                  _rail(),
                  VerticalDivider(
                    width: 1,
                    color: AppColors.text.withValues(alpha: .08),
                  ),
                  Expanded(child: content),
                ],
              )
            : content,
      ),
      bottomNavigationBar: wide ? null : _bottomBar(),
    );
  }

  static const _red = Color(0xFFE65F72);

  /// Red badge with the number of active alarms on the Alarms tab.
  Widget _alarmIcon(IconData icon, int active) => Badge(
    isLabelVisible: active > 0,
    backgroundColor: _red,
    textColor: Colors.white,
    label: Text('$active'),
    child: Icon(icon, color: active > 0 ? _red : null),
  );

  Widget _bottomBar() {
    return ListenableBuilder(
      listenable: AlarmService.instance,
      builder: (context, _) {
        final active = AlarmService.instance.activeCount;
        return NavigationBar(
          backgroundColor: AppColors.nav,
          selectedIndex: currentIndex,
          onDestinationSelected: (index) =>
              setState(() => currentIndex = index),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: _alarmIcon(Icons.notifications_none, active),
              selectedIcon: _alarmIcon(Icons.notifications, active),
              label: 'Alarms',
            ),
            const NavigationDestination(
              icon: Icon(Icons.show_chart),
              label: 'History',
            ),
            const NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        );
      },
    );
  }

  Widget _rail() {
    return ListenableBuilder(
      listenable: AlarmService.instance,
      builder: (context, _) {
        final active = AlarmService.instance.activeCount;
        return NavigationRail(
          backgroundColor: AppColors.nav,
          selectedIndex: currentIndex,
          labelType: NavigationRailLabelType.all,
          onDestinationSelected: (index) =>
              setState(() => currentIndex = index),
          destinations: [
            const NavigationRailDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: Text('Dashboard'),
            ),
            NavigationRailDestination(
              icon: _alarmIcon(Icons.notifications_none, active),
              selectedIcon: _alarmIcon(Icons.notifications, active),
              label: const Text('Alarms'),
            ),
            const NavigationRailDestination(
              icon: Icon(Icons.show_chart),
              label: Text('History'),
            ),
            const NavigationRailDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: Text('Settings'),
            ),
          ],
        );
      },
    );
  }
}
