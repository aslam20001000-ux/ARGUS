import 'package:flutter/material.dart';

import '../../core/alarm_service.dart';
import '../../core/alarm_sound.dart';
import '../../core/app_state.dart';
import '../../core/auth_service.dart';
import '../../core/device_service.dart';
import '../../core/profile_storage.dart';
import '../../core/responsive.dart';
import '../../core/settings_store.dart';
import '../auth/logout.dart';
import '../monitor/alarm_page.dart';
import '../../core/app_colors.dart';

const _blue = Color(0xFF54A9FF);
const _green = Color(0xFF38E08F);
const _red = Color(0xFFE65F72);
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

  void _openLanguage(BuildContext context) {
    final settings = SettingsStore.instance;
    _showChoiceSheet<bool>(
      context,
      title: 'Language',
      footer:
          'The login, sign-up and home pages are translated. The other pages '
          'are still in English.',
      selected: isArabic.value,
      onSelected: settings.setArabic,
      choices: const [
        _Choice(false, 'English', 'Left-to-right'),
        _Choice(true, 'العربية', 'Right-to-left'),
      ],
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

  void _openSpeed(BuildContext context) {
    final settings = SettingsStore.instance;
    _showChoiceSheet<double>(
      context,
      title: 'Waveform Speed',
      footer: 'Changes how wide each heartbeat looks on the ECG wave.',
      selected: settings.waveformSpeed,
      onSelected: settings.setWaveformSpeed,
      choices: const [
        _Choice(12.5, '12.5 mm/s', 'Slow sweep • more beats on the screen'),
        _Choice(25, '25 mm/s', 'Standard clinical speed'),
        _Choice(50, '50 mm/s', 'Fast sweep • beats spread out, more detail'),
      ],
    );
  }

  void _openUnits(BuildContext context) {
    final settings = SettingsStore.instance;
    _showChoiceSheet<TempUnit>(
      context,
      title: 'Temperature Unit',
      footer:
          'Applies to the temperature reading, its alarm limits and the alarm history.',
      selected: settings.tempUnit,
      onSelected: settings.setTempUnit,
      choices: const [
        _Choice(TempUnit.celsius, 'Celsius (°C)', 'Metric'),
        _Choice(TempUnit.fahrenheit, 'Fahrenheit (°F)', 'Imperial'),
      ],
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

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final settings = SettingsStore.instance;

    return ListenableBuilder(
      listenable: Listenable.merge([
        settings,
        AlarmService.instance,
        currentUserName,
        darkMode,
        isArabic,
      ]),
      builder: (context, _) {
        final alarms = AlarmService.instance;
        final savedName = AuthService.displayName;
        final accountText =
            '${savedName.isEmpty ? 'Name not set' : savedName}  •  ${AuthService.email}';
        final enabledCount = alarms.limits.values
            .where((l) => l.enabled)
            .length;

        final volumeText = !settings.soundEnabled
            ? 'Sound off'
            : '${(settings.volume * 100).round()}%';

        final deviceText = settings.deviceHost.isEmpty
            ? 'Not configured'
            : '${settings.deviceHost}:${settings.devicePort} • '
                  '${settings.deviceConnected ? 'Connected' : 'Not connected'}';

        return ContentFrame(
          maxWidth: 720,
          child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            if (showHeader)
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Settings',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),

            _section('Account'),
            _tile(
              icon: Icons.person_outline_rounded,
              title: 'Your name',
              subtitle: accountText,
              onTap: () => _editName(context),
            ),
            _tile(
              icon: Icons.lock_reset_rounded,
              title: 'Change password',
              subtitle: 'Choose a new password for this account',
              onTap: () => _changePassword(context),
            ),

            _section('Alarms'),
            _tile(
              icon: Icons.notifications,
              title: 'Alarm Settings',
              subtitle:
                  '$enabledCount of ${AlarmParam.values.length} alarms on • edit limits',
              onTap: () => _openAlarmSettings(context),
            ),
            _tile(
              icon: !settings.soundEnabled || settings.volume == 0
                  ? Icons.volume_off
                  : Icons.volume_up,
              title: 'Alarm Volume',
              subtitle: volumeText,
              onTap: () => _openVolume(context),
            ),
            _switchTile(
              icon: Icons.vibration,
              title: 'Vibration',
              subtitle: 'Vibrate while an alarm is active',
              value: settings.vibrationEnabled,
              onChanged: settings.setVibration,
            ),
            _switchTile(
              icon: Icons.notifications_active_outlined,
              title: 'Notifications',
              subtitle: 'Notify me about new alarms when the app is in the background',
              value: settings.notificationsEnabled,
              onChanged: settings.setNotifications,
            ),

            _section('Display'),
            _tile(
              icon: Icons.language_rounded,
              title: 'Language',
              subtitle: isArabic.value ? 'العربية' : 'English',
              onTap: () => _openLanguage(context),
            ),
            _switchTile(
              icon: Icons.dark_mode_outlined,
              title: 'Dark mode',
              subtitle: darkMode.value ? 'Dark theme' : 'Light theme',
              value: darkMode.value,
              onChanged: settings.setDarkMode,
            ),
            _tile(
              icon: Icons.speed,
              title: 'Waveform Speed',
              subtitle: '${_speedText(settings.waveformSpeed)} mm/s',
              onTap: () => _openSpeed(context),
            ),
            _tile(
              icon: Icons.straighten,
              title: 'Units',
              subtitle: 'Temperature: ${settings.tempSymbol}',
              onTap: () => _openUnits(context),
            ),

            _section('Device'),
            _tile(
              icon: Icons.wifi,
              title: 'Device Connection',
              subtitle: deviceText,
              onTap: () => _openDevice(context),
            ),

            _section('Session'),
            ListTile(
              onTap: () => confirmLogout(context),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 4,
                horizontal: 4,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _red.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.logout_rounded, color: _red),
              ),
              title: const Text('Log out', style: TextStyle(color: _red)),
              subtitle:  Text(
                'Sign out of this account',
                style: TextStyle(color: AppColors.text.withValues(alpha: .54)),
              ),
            ),
          ],
          ),
        );
      },
    );
  }

  static String _speedText(double speed) =>
      speed == speed.roundToDouble()
          ? speed.toStringAsFixed(0)
          : speed.toStringAsFixed(1);

  Widget _section(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
      child: Text(
        text.toUpperCase(),
        style:  TextStyle(
          color: AppColors.text.withValues(alpha: .38),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  Widget _iconBox(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.chip,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: _iconBox(icon),
      title: Text(title),
      subtitle: Text(subtitle, style:  TextStyle(color: AppColors.text.withValues(alpha: .54))),
      trailing:  Icon(Icons.chevron_right, color: AppColors.text.withValues(alpha: .38)),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      onTap: () => onChanged(!value),
      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: _iconBox(icon),
      title: Text(title),
      subtitle: Text(subtitle, style:  TextStyle(color: AppColors.text.withValues(alpha: .54))),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}

// ======================================================== choice bottom sheet

class _Choice<T> {
  final T value;
  final String label;
  final String description;

  const _Choice(this.value, this.label, this.description);
}

void _showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<_Choice<T>> choices,
  required T selected,
  required ValueChanged<T> onSelected,
  String? footer,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: _card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10),
            for (final c in choices)
              ListTile(
                onTap: () {
                  onSelected(c.value);
                  Navigator.pop(sheetContext);
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                title: Text(
                  c.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: c.value == selected ? _blue : null,
                  ),
                ),
                subtitle: Text(
                  c.description,
                  style:  TextStyle(color: AppColors.text.withValues(alpha: .54), fontSize: 12),
                ),
                trailing: c.value == selected
                    ? const Icon(Icons.check_circle, color: _blue)
                    :  Icon(Icons.circle_outlined, color: AppColors.text.withValues(alpha: .24)),
              ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
                child: Text(
                  footer,
                  style:  TextStyle(color: AppColors.text.withValues(alpha: .38), fontSize: 11.5),
                ),
              ),
          ],
        ),
      ),
    ),
  );
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
                  subtitle:  Text(
                    'Beep while an alarm is active',
                    style: TextStyle(color: AppColors.text.withValues(alpha: .54), fontSize: 12),
                  ),
                  value: enabled,
                  onChanged: settings.setSoundEnabled,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.volume_down,
                      color: enabled ? AppColors.text.withValues(alpha: .7) : AppColors.text.withValues(alpha: .24),
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
                      color: enabled ? AppColors.text.withValues(alpha: .7) : AppColors.text.withValues(alpha: .24),
                    ),
                  ],
                ),
                Center(
                  child: Text(
                    enabled ? '${(settings.volume * 100).round()}%' : 'Muted',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: enabled ? _green : AppColors.text.withValues(alpha: .38),
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
        borderSide: const BorderSide(color: _blue, width: 1.5),
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
                  color: connected ? _green : AppColors.text.withValues(alpha: .38),
                ),
                const SizedBox(width: 8),
                Text(
                  statusText,
                  style: TextStyle(
                    color: connected ? _green : AppColors.text.withValues(alpha: .54),
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
              Text(_error!, style: const TextStyle(color: _red, fontSize: 12)),
            ],
            const SizedBox(height: 12),
             Text(
              'The IP is printed in the ESP32 Serial Monitor after it joins '
              'the Wi-Fi. The phone and the ESP32 must be on the same network.',
              style: TextStyle(color: AppColors.text.withValues(alpha: .38), fontSize: 11.5),
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
              prefixIcon: const Icon(Icons.person_outline, color: _blue),
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
                borderSide: const BorderSide(color: _blue, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 10),
           Text(
            'This is your own name (shown in the menu and on the home page). '
            'It is saved in your account, separate from your email and '
            'from the patient\'s name.',
            style: TextStyle(color: AppColors.text.withValues(alpha: .38), fontSize: 11.5),
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
    prefixIcon: const Icon(Icons.lock_outline, color: _blue),
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
      borderSide: const BorderSide(color: _blue, width: 1.5),
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
                style: const TextStyle(
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
