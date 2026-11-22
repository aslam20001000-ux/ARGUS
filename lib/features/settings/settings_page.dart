import 'package:flutter/material.dart';

import '../../core/alarm_service.dart';
import '../../core/alarm_sound.dart';
import '../../core/app_state.dart';
import '../../core/auth_service.dart';
import '../../core/device_service.dart';
import '../../core/page_route.dart';
import '../../core/profile_storage.dart';
import '../../core/responsive.dart';
import '../../core/settings_store.dart';
import '../../core/user_role.dart';
import '../auth/logout.dart';
import '../monitor/alarm_page.dart';
import '../../core/app_colors.dart';
import 'manage_users_page.dart';

Color get _blue => AppColors.blue;
Color get _cyan => AppColors.cyan;
Color get _green => AppColors.green;
Color get _amber => AppColors.amber;
Color get _violet => AppColors.violet;
Color get _red => AppColors.red;
Color get _card => AppColors.card;

class SettingsPage extends StatelessWidget {
  /// Hide the "Settings" title row when the page already has an app bar.
  final bool showHeader;

  const SettingsPage({super.key, this.showHeader = true});

  Future<void> _editName(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(initial: AuthService.displayName),
    );
    if (result == null) return;

    try {
      final oldName = AuthService.accountName;
      await AuthService.updateDisplayName(result);
      currentUserName.value = result.isEmpty ? AuthService.username : result;
      // The patient shown in the app follows your name (until you rename
      // the patient yourself in the Patient Profile).
      if (patientProfile.name.trim().isEmpty ||
          patientProfile.name == 'John Doe' ||
          patientProfile.name == oldName) {
        patientProfile.name = AuthService.accountName;
        ProfileStorage.save();
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Name saved'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not save the name. Check your internet.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _changePassword(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<({String current, String next})>(
      context: context,
      builder: (_) => const _PasswordDialog(),
    );
    if (result == null) return;

    final error = await AuthService.changePassword(result.current, result.next);
    final text = switch (error) {
      null => 'Password changed',
      AuthError.invalidCredentials => 'Current password is incorrect',
      AuthError.weakPassword => 'New password is too weak',
      AuthError.network => 'No internet connection',
      AuthError.tooManyRequests => 'Too many attempts. Try again later',
      _ => 'Could not change the password. Try again',
    };
    messenger.showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  // ------------------------------------------------------------ open items

  void _openAlarmSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            backgroundColor: AppColors.bg,
            elevation: 0,
            title: const Text(
              'Alarm Settings',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          body: const SafeArea(child: AlarmPage(showHeader: false)),
        ),
      ),
    );
  }

  void _openVolume(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _VolumeSheet(),
    );
  }

  Future<void> _openDevice(BuildContext context) async {
    final settings = SettingsStore.instance;
    final result = await showDialog<({String host, int port})>(
      context: context,
      builder: (_) =>
          _DeviceDialog(host: settings.deviceHost, port: settings.devicePort),
    );
    if (result != null) {
      settings.setDevice(result.host, result.port);
      // Empty address = demo data; otherwise connect to the ESP32 now.
      DeviceService.instance.start();
    }
  }

  void _openManageUsers(BuildContext context) {
    Navigator.push(context, appRoute<void>(const ManageUsersPage()));
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final settings = SettingsStore.instance;

    return ListenableBuilder(
      listenable: Listenable.merge([
        settings,
        AlarmService.instance,
        DeviceService.instance,
        currentUserName,
        currentRole,
        darkMode,
        isArabic,
      ]),
      builder: (context, _) {
        final alarms = AlarmService.instance;
        final role = currentRole.value;
        final enabledCount = alarms.limits.values
            .where((l) => l.enabled)
            .length;
        final totalAlarms = AlarmParam.values.length;
        final muted = !settings.soundEnabled || settings.volume == 0;

        // ---------------------------------------------------------- groups
        final alarmsGroup = _Group(
          icon: Icons.notifications_rounded,
          color: _red,
          title: 'Alarms',
          sub: 'Limits, sound and alerts',
          children: [
            _NavRow(
              icon: Icons.tune_rounded,
              color: _red,
              title: 'Alarm limits',
              subtitle: 'High / low limit of each vital',
              trailing: _Pill(
                '$enabledCount / $totalAlarms on',
                color: enabledCount == totalAlarms ? _green : _amber,
              ),
              onTap: () => _openAlarmSettings(context),
            ),
            _NavRow(
              icon: muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: _amber,
              title: 'Alarm volume',
              subtitle: muted
                  ? 'Muted — alarms will not beep'
                  : 'Tap to adjust or test the sound',
              trailing: _Pill(
                muted ? 'Muted' : '${(settings.volume * 100).round()}%',
                color: muted ? _red : _blue,
              ),
              onTap: () => _openVolume(context),
            ),
            _SwitchRow(
              icon: Icons.notifications_active_outlined,
              color: _violet,
              title: 'Background notifications',
              subtitle: 'Notify me about alarms when the app is closed',
              value: settings.notificationsEnabled,
              onChanged: settings.setNotifications,
            ),
          ],
        );

        final displayGroup = _Group(
          icon: Icons.palette_outlined,
          color: _blue,
          title: 'Display',
          sub: 'Language, ECG speed and units',
          children: [
            _SegmentRow<bool>(
              icon: Icons.language_rounded,
              color: _blue,
              title: 'Language',
              subtitle: isArabic.value
                  ? 'Some pages are still in English'
                  : null,
              selected: isArabic.value,
              onChanged: settings.setArabic,
              options: const [(false, 'English'), (true, 'العربية')],
            ),
            _SegmentRow<double>(
              icon: Icons.speed_rounded,
              color: _cyan,
              title: 'ECG sweep speed',
              subtitle: 'mm/s — 25 is the standard clinical speed',
              selected: settings.waveformSpeed,
              onChanged: settings.setWaveformSpeed,
              options: [
                for (final s in SettingsStore.waveformSpeeds)
                  (s, _speedText(s)),
              ],
            ),
            _SegmentRow<TempUnit>(
              icon: Icons.thermostat_rounded,
              color: _amber,
              title: 'Temperature unit',
              subtitle: 'Also used for the alarm limits and history',
              selected: settings.tempUnit,
              onChanged: settings.setTempUnit,
              options: const [
                (TempUnit.celsius, '°C'),
                (TempUnit.fahrenheit, '°F'),
              ],
            ),
          ],
        );

        final deviceGroup = _Group(
          icon: Icons.memory_rounded,
          color: _green,
          title: 'Device',
          sub: 'ESP32 monitor connection',
          children: [_DeviceRow(onTap: () => _openDevice(context))],
        );

        final accountGroup = _Group(
          icon: Icons.manage_accounts_outlined,
          color: _cyan,
          title: 'Account & security',
          sub: 'Your sign-in details',
          children: [
            _NavRow(
              icon: Icons.person_outline_rounded,
              color: _cyan,
              title: 'Display name',
              subtitle: AuthService.displayName.isEmpty
                  ? 'Not set'
                  : AuthService.displayName,
              onTap: () => _editName(context),
            ),
            _NavRow(
              icon: Icons.lock_reset_rounded,
              color: _blue,
              title: 'Change password',
              subtitle: 'Choose a new password for this account',
              onTap: () => _changePassword(context),
            ),
            if (role.canManageUsers)
              _NavRow(
                icon: Icons.admin_panel_settings_outlined,
                color: _violet,
                title: 'Manage users',
                subtitle: 'Change the role of each account',
                onTap: () => _openManageUsers(context),
              ),
          ],
        );

        final logout = _LogoutButton(onTap: () => confirmLogout(context));

        return LayoutBuilder(
          builder: (context, box) {
            final wide = box.maxWidth >= 760;
            const gap = SizedBox(height: 16);

            return ContentFrame(
              maxWidth: 1120,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 32),
                children: [
                  if (showHeader)
                    const Padding(
                      padding: EdgeInsets.only(top: 12, bottom: 14),
                      child: Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  _AccountCard(wide: wide, onEdit: () => _editName(context)),
                  gap,
                  _QuickToggles(settings: settings),
                  gap,
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [alarmsGroup, gap, deviceGroup],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            children: [
                              displayGroup,
                              gap,
                              accountGroup,
                              gap,
                              logout,
                            ],
                          ),
                        ),
                      ],
                    )
                  else ...[
                    alarmsGroup,
                    gap,
                    displayGroup,
                    gap,
                    deviceGroup,
                    gap,
                    accountGroup,
                    gap,
                    logout,
                  ],
                  const SizedBox(height: 18),
                  Center(
                    child: Text(
                      'Settings are saved on this device automatically.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.text.withValues(alpha: .38),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static String _speedText(double speed) => speed == speed.roundToDouble()
      ? speed.toStringAsFixed(0)
      : speed.toStringAsFixed(1);
}

// ============================================================ building blocks

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

/// Gradient header with the signed-in account.
class _AccountCard extends StatelessWidget {
  final bool wide;
  final VoidCallback onEdit;

  const _AccountCard({required this.wide, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final displayName = AuthService.displayName;
    final name = displayName.isEmpty ? AuthService.accountName : displayName;
    final email = AuthService.email;

    final avatar = Container(
      width: wide ? 76 : 64,
      height: wide ? 76 : 64,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(colors: AppColors.heroRing),
      ),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.heroAvatar,
          ),
        ),
        child: Text(
          _initials(name),
          style: TextStyle(
            color: Colors.white,
            fontSize: wide ? 28 : 23,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: EdgeInsets.all(wide ? 24 : 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.heroGradient,
          ),
        ),
        child: Row(
          children: [
            avatar,
            SizedBox(width: wide ? 20 : 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: wide ? 22 : 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .65),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: onEdit,
              tooltip: 'Edit name',
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: .12),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.edit_rounded, size: 19),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three big on/off tiles for the settings people change most often.
class _QuickToggles extends StatelessWidget {
  final SettingsStore settings;

  const _QuickToggles({required this.settings});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ToggleTile(
            icon: settings.soundEnabled
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
            label: 'Sound',
            value: settings.soundEnabled,
            color: _blue,
            onChanged: settings.setSoundEnabled,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ToggleTile(
            icon: Icons.vibration_rounded,
            label: 'Vibration',
            value: settings.vibrationEnabled,
            color: _violet,
            onChanged: settings.setVibration,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ToggleTile(
            icon: darkMode.value
                ? Icons.dark_mode_rounded
                : Icons.light_mode_rounded,
            label: 'Dark mode',
            value: darkMode.value,
            color: _amber,
            onChanged: settings.setDarkMode,
          ),
        ),
      ],
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dim = AppColors.text.withValues(alpha: .45);
    return Material(
      color: value ? color.withValues(alpha: .14) : _card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: value
                  ? color.withValues(alpha: .5)
                  : AppColors.text.withValues(alpha: .07),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: value ? color : dim, size: 22),
                  const Spacer(),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: value
                          ? color
                          : AppColors.text.withValues(alpha: .18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value ? 'On' : 'Off',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: value ? color : dim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A titled card holding a list of rows separated by thin dividers.
class _Group extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String sub;
  final List<Widget> children;

  const _Group({
    required this.icon,
    required this.color,
    required this.title,
    required this.sub,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        boxShadow: AppColors.cardShadow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.text.withValues(alpha: .06)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        sub,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.text.withValues(alpha: .5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 62,
                endIndent: 16,
                color: AppColors.text.withValues(alpha: .06),
              ),
            children[i],
          ],
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _RowIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _RowIcon(this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.chip,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _RowText extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _RowText(this.title, this.subtitle);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.text.withValues(alpha: .54),
            ),
          ),
        ],
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;

  const _Pill(this.text, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Row that opens another page, sheet or dialog.
class _NavRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _NavRow({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
        child: Row(
          children: [
            _RowIcon(icon, color),
            const SizedBox(width: 12),
            Expanded(child: _RowText(title, subtitle)),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.text.withValues(alpha: .35),
            ),
          ],
        ),
      ),
    );
  }
}

/// Row with an on/off switch.
class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
        child: Row(
          children: [
            _RowIcon(icon, color),
            const SizedBox(width: 12),
            Expanded(child: _RowText(title, subtitle)),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// Row with the choices shown inline as a segmented control (no extra sheet).
class _SegmentRow<T> extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final T selected;
  final ValueChanged<T> onChanged;
  final List<(T, String)> options;

  const _SegmentRow({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onChanged,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    final segments = SegmentedButton<T>(
      showSelectedIcon: false,
      segments: [
        for (final (value, label) in options)
          ButtonSegment<T>(value: value, label: Text(label)),
      ],
      selected: {selected},
      onSelectionChanged: (s) => onChanged(s.first),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
        side: WidgetStatePropertyAll(
          BorderSide(color: AppColors.text.withValues(alpha: .12)),
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? _blue.withValues(alpha: .18)
              : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? _blue
              : AppColors.text.withValues(alpha: .7),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, box) {
        final header = Row(
          children: [
            _RowIcon(icon, color),
            const SizedBox(width: 12),
            Expanded(child: _RowText(title, subtitle)),
          ],
        );

        // Enough room: control on the same line. Otherwise below the title.
        if (box.maxWidth >= 420) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                Expanded(child: header),
                const SizedBox(width: 12),
                segments,
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 46),
                child: segments,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Live connection status of the ESP32 with a button to configure it.
class _DeviceRow extends StatelessWidget {
  final VoidCallback onTap;

  const _DeviceRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsStore.instance;
    final device = DeviceService.instance;
    final configured = settings.deviceHost.isNotEmpty;

    final (Color color, String status, IconData icon) = switch (device.status) {
      DeviceStatus.connected => (_green, 'Connected', Icons.wifi_rounded),
      DeviceStatus.connecting => (
        _amber,
        'Connecting…',
        Icons.wifi_find_rounded,
      ),
      DeviceStatus.lost => (
        _red,
        'Connection lost – retrying',
        Icons.wifi_off_rounded,
      ),
      DeviceStatus.off => (
        AppColors.text.withValues(alpha: .5),
        configured ? 'Not connected' : 'Demo data',
        Icons.science_outlined,
      ),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: .35)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    configured
                        ? '${settings.deviceHost}:${settings.devicePort}'
                        : 'No ESP32 address set',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.text.withValues(alpha: .54),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: _blue.withValues(alpha: .14),
                foregroundColor: _blue,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(configured ? 'Edit' : 'Connect'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;

  const _LogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _red.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _red.withValues(alpha: .3)),
          ),
          child: Row(
            children: [
              Icon(Icons.logout_rounded, color: _red),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Log out',
                  style: TextStyle(
                    color: _red,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: _red),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================ volume sheet

class _VolumeSheet extends StatelessWidget {
  const _VolumeSheet();

  @override
  Widget build(BuildContext context) {
    final settings = SettingsStore.instance;

    return SafeArea(
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          final enabled = settings.soundEnabled;

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Alarm Volume',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Alarm sound'),
                  subtitle: Text(
                    'Beep while an alarm is active',
                    style: TextStyle(
                      color: AppColors.text.withValues(alpha: .54),
                      fontSize: 12,
                    ),
                  ),
                  value: enabled,
                  onChanged: settings.setSoundEnabled,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.volume_down,
                      color: enabled
                          ? AppColors.text.withValues(alpha: .7)
                          : AppColors.text.withValues(alpha: .24),
                    ),
                    Expanded(
                      child: Slider(
                        value: settings.volume,
                        onChanged: enabled ? settings.setVolume : null,
                        onChangeEnd: enabled
                            ? (_) => AlarmSound.instance.preview()
                            : null,
                      ),
                    ),
                    Icon(
                      Icons.volume_up,
                      color: enabled
                          ? AppColors.text.withValues(alpha: .7)
                          : AppColors.text.withValues(alpha: .24),
                    ),
                  ],
                ),
                Center(
                  child: Text(
                    enabled ? '${(settings.volume * 100).round()}%' : 'Muted',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: enabled
                          ? _green
                          : AppColors.text.withValues(alpha: .38),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: enabled ? AlarmSound.instance.preview : null,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Test sound'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _blue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ============================================================ device dialog

class _DeviceDialog extends StatefulWidget {
  final String host;
  final int port;

  const _DeviceDialog({required this.host, required this.port});

  @override
  State<_DeviceDialog> createState() => _DeviceDialogState();
}

class _DeviceDialogState extends State<_DeviceDialog> {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(text: widget.host);
    _portController = TextEditingController(text: '${widget.port}');
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _save() {
    final port = int.tryParse(_portController.text.trim());
    if (port == null || port < 1 || port > 65535) {
      setState(() => _error = 'Port must be a number between 1 and 65535');
      return;
    }
    Navigator.pop(context, (host: _hostController.text.trim(), port: port));
  }

  void _useDemo() {
    Navigator.pop(context, (host: '', port: widget.port));
  }

  InputDecoration _decoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
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
    final device = DeviceService.instance;
    final connected = device.connected;
    final statusText = switch (device.status) {
      DeviceStatus.connected => 'Connected',
      DeviceStatus.connecting => 'Connecting…',
      DeviceStatus.lost => 'Connection lost – retrying',
      DeviceStatus.off => 'Not connected (demo data)',
    };

    return AlertDialog(
      backgroundColor: _card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Device Connection',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 10,
                  color: connected
                      ? _green
                      : AppColors.text.withValues(alpha: .38),
                ),
                const SizedBox(width: 8),
                Text(
                  statusText,
                  style: TextStyle(
                    color: connected
                        ? _green
                        : AppColors.text.withValues(alpha: .54),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _hostController,
              keyboardType: TextInputType.url,
              decoration: _decoration('ESP32 address (IP)', '192.168.1.50'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _portController,
              keyboardType: TextInputType.number,
              decoration: _decoration('Port', '81'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: _red, fontSize: 12)),
            ],
            const SizedBox(height: 12),
            Text(
              'The IP is printed in the ESP32 Serial Monitor after it joins '
              'the Wi-Fi. The phone and the ESP32 must be on the same network.',
              style: TextStyle(
                color: AppColors.text.withValues(alpha: .38),
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (widget.host.isNotEmpty)
          TextButton(onPressed: _useDemo, child: const Text('Use demo data')),
        TextButton(onPressed: _save, child: const Text('Save & connect')),
      ],
    );
  }
}

// ============================================================== name dialog

class _NameDialog extends StatefulWidget {
  final String initial;

  const _NameDialog({required this.initial});

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Your name',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Full name',
              prefixIcon: Icon(Icons.person_outline, color: _blue),
              filled: true,
              fillColor: AppColors.bg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: AppColors.text.withValues(alpha: .07),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: AppColors.text.withValues(alpha: .07),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _blue, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'This is your own name (shown in the menu and on the home page). '
            'It is saved in your account, separate from your email and '
            'from the patient\'s name.',
            style: TextStyle(
              color: AppColors.text.withValues(alpha: .38),
              fontSize: 11.5,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// ============================================================ settings screen

/// Settings opened from the side menu (a full page with a back button).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: const SafeArea(child: SettingsPage(showHeader: false)),
    );
  }
}

// ============================================================ password dialog

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (_current.text.isEmpty) {
      setState(() => _error = 'Enter your current password');
    } else if (_new.text.length < 6) {
      setState(() => _error = 'New password must be at least 6 characters');
    } else if (_new.text != _confirm.text) {
      setState(() => _error = 'The new passwords do not match');
    } else if (_new.text == _current.text) {
      setState(() => _error = 'The new password must be different');
    } else {
      Navigator.pop(context, (current: _current.text, next: _new.text));
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(Icons.lock_outline, color: _blue),
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Change password',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _current,
              obscureText: _hide,
              autofocus: true,
              decoration: _dec('Current password').copyWith(
                suffixIcon: IconButton(
                  icon: Icon(_hide ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _hide = !_hide),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _new,
              obscureText: _hide,
              decoration: _dec('New password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              obscureText: _hide,
              onSubmitted: (_) => _submit(),
              decoration: _dec('Confirm new password'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(
                  color: _red,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('Change')),
      ],
    );
  }
}
