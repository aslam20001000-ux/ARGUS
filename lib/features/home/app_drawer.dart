import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/auth_service.dart';
import '../../core/page_route.dart';
import '../../core/widgets/argus_eye.dart';
import '../auth/logout.dart';
import '../bladder/bladder_page.dart';
import '../monitor/monitor_home.dart';
import '../profile/patient_profile_page.dart';
import '../settings/settings_page.dart';
import '../../core/app_colors.dart';

Color get _blue => AppColors.blue;
Color get _red => AppColors.red;

/// The pages that can be opened from the side menu.
enum AppSection { home, monitor, bladder, profile }

/// The "menu" button that opens the side menu (put it in an AppBar).
class DrawerMenuButton extends StatelessWidget {
  const DrawerMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Menu',
      icon: const Icon(Icons.menu_rounded),
      onPressed: () => Scaffold.of(context).openDrawer(),
    );
  }
}

/// Side menu: every feature, plus Settings and Log out.
class AppDrawer extends StatelessWidget {
  /// The page that is open now (it is highlighted in the menu).
  final AppSection current;

  const AppDrawer({super.key, required this.current});

  void _openSection(BuildContext context, AppSection target) {
    final navigator = Navigator.of(context);
    navigator.pop(); // close the menu
    if (target == current) return;

    if (target == AppSection.home) {
      navigator.popUntil((route) => route.isFirst);
      return;
    }

    final Widget page = switch (target) {
      AppSection.monitor => const MonitorHome(),
      AppSection.bladder => const BladderPage(),
      AppSection.profile => const PatientProfilePage(),
      AppSection.home => const SizedBox.shrink(),
    };

    // Keep the home page at the bottom so "back" always returns to it.
    navigator.pushAndRemoveUntil(
      appRoute<void>(page),
      (route) => route.isFirst,
    );
  }

  void _openSettings(BuildContext context) {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(appRoute<void>(const SettingsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.nav,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 4),
                children: [
                  _sectionLabel('FEATURES'),
                  _item(context, Icons.apps_rounded, 'Home', AppSection.home),
                  _item(
                    context,
                    Icons.monitor_heart,
                    'Medical Monitor',
                    AppSection.monitor,
                  ),
                  _item(
                    context,
                    Icons.water_drop_outlined,
                    'Bladder Monitor',
                    AppSection.bladder,
                  ),
                  _item(
                    context,
                    Icons.badge_outlined,
                    'Patient Profile',
                    AppSection.profile,
                  ),
                ],
              ),
            ),
            Divider(color: AppColors.text.withValues(alpha: .12), height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                children: [
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text(
                      'Settings',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onTap: () => _openSettings(context),
                  ),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    leading: Icon(Icons.logout_rounded, color: _red),
                    title: Text(
                      'Log out',
                      style: TextStyle(
                        color: _red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () => confirmLogout(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.cardAlt, AppColors.nav],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          bottom: BorderSide(color: AppColors.text.withValues(alpha: .06)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.card,
              border: Border.all(color: _blue.withValues(alpha: .38)),
            ),
            child: Center(
              child: CustomPaint(
                size: const Size(36, 22),
                painter: ArgusEyePainter(),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'ARGUS',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
              color: AppColors.text.withValues(alpha: .54),
            ),
          ),
          const SizedBox(height: 6),
          ValueListenableBuilder<String>(
            valueListenable: currentUserName,
            builder: (context, name, _) {
              final shown = name.trim().isEmpty
                  ? AuthService.username
                  : name.trim();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shown,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AuthService.email,
                    style: TextStyle(
                      color: AppColors.text.withValues(alpha: .54),
                      fontSize: 12,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.text.withValues(alpha: .38),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context,
    IconData icon,
    String title,
    AppSection section,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: ListTile(
        selected: section == current,
        selectedColor: _blue,
        selectedTileColor: _blue.withValues(alpha: .12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        onTap: () => _openSection(context, section),
      ),
    );
  }
}
