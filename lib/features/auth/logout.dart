import 'package:flutter/material.dart';

import '../../core/alarm_service.dart';
import '../../core/device_service.dart';
import '../../core/app_state.dart';
import '../../core/auth_service.dart';
import '../../core/vitals_store.dart';
import 'login_page.dart';
import '../../core/app_colors.dart';

const _red = Color(0xFFE65F72);

/// Asks for confirmation, then stops the monitoring, signs out of Firebase and
/// goes back to the login page. Used by the side menu and the Settings page.
Future<void> confirmLogout(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Log out',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content:  Text(
        'Are you sure you want to log out?',
        style: TextStyle(color: AppColors.text.withValues(alpha: .7)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: TextButton.styleFrom(foregroundColor: _red),
          child: const Text('Log out'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  // Stop the data feed and any ringing alarm before leaving.
  await DeviceService.instance.stop();
  AlarmService.instance.stopMonitoring();
  VitalsStore.instance.stop();
  await AuthService.signOut();
  if (!context.mounted) return;

  currentUserName.value = '';

  Navigator.of(context).pushAndRemoveUntil(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (_, animation, _) => const LoginPage(),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
    (route) => false,
  );
}
