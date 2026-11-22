import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/auth_service.dart';
import '../../core/user_role.dart';
import '../../core/user_service.dart';

/// Admin only: see every account and change its role.
class ManageUsersPage extends StatefulWidget {
  const ManageUsersPage({super.key});

  @override
  State<ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> {
  late Future<List<UserRecord>> _future = UserService.listUsers();

  void _reload() => setState(() => _future = UserService.listUsers());

  Future<void> _change(UserRecord u, UserRole role) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await UserService.setRole(u.uid, role);
      messenger.showSnackBar(
        SnackBar(
          content: Text('${u.email} is now ${role.label}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not change the role. Check your internet.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: const Text(
          'Manage users',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<List<UserRecord>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load the users.\n'
                  'Check your internet and the Firestore rules.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.text.withValues(alpha: .6)),
                ),
              ),
            );
          }
          final users = snap.data ?? [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Doctor: can edit alarm limits and the patient profile.\n'
                'Nurse: view only (can still silence alarms).\n'
                'Admin: everything, plus this page.',
                style: TextStyle(
                  color: AppColors.text.withValues(alpha: .54),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              for (final u in users) _tile(u),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(UserRecord u) {
    final isMe = u.uid == AuthService.uid;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        boxShadow: AppColors.cardShadow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  u.name.isEmpty ? u.email : u.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isMe ? '${u.email}  (you)' : u.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.text.withValues(alpha: .54),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          DropdownButton<UserRole>(
            value: u.role,
            underline: const SizedBox.shrink(),
            items: [
              for (final r in UserRole.values)
                DropdownMenuItem(value: r, child: Text(r.label)),
            ],
            // You cannot change your own role (so there is always an admin).
            onChanged: isMe
                ? null
                : (r) {
                    if (r != null && r != u.role) _change(u, r);
                  },
          ),
        ],
      ),
    );
  }
}
