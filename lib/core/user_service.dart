import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'user_role.dart';

/// One account as stored in Firestore: collection `users`, document = uid.
class UserRecord {
  final String uid;
  final String name;
  final String email;
  final UserRole role;

  const UserRecord({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
  });
}

/// Roles and account info in Cloud Firestore.
class UserService {
  UserService._();

  /// This account is the first admin. (It cannot be created from the sign-up
  /// screen, which only accepts @argus.com emails.)
  static const String bootstrapAdminEmail = 'admin@argus.app';

  static CollectionReference<Map<String, dynamic>> get _users =>
      FirebaseFirestore.instance.collection('users');

  static bool get _isBootstrapAdmin =>
      AuthService.email.toLowerCase() == bootstrapAdminEmail;

  static UserRole get _defaultRole =>
      _isBootstrapAdmin ? UserRole.admin : UserRole.nurse;

  /// Saves the account record right after sign-up.
  static Future<void> createRecord({
    required String name,
    required String birthDate,
  }) async {
    final uid = AuthService.uid;
    if (uid.isEmpty) return;
    try {
      await _users.doc(uid).set({
        'name': name.trim(),
        'email': AuthService.email,
        'role': _defaultRole.name,
        'birthDate': birthDate,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // The role is loaded again (and the record created) at the next start.
    }
  }

  /// Loads the signed-in person's role into [currentRole].
  /// Works offline too, using the role saved on this device last time.
  static Future<void> loadRole() async {
    final uid = AuthService.uid;
    if (uid.isEmpty) {
      currentRole.value = UserRole.nurse;
      return;
    }

    String? cached;
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      cached = prefs.getString('role_$uid');
    } catch (_) {}

    var role = cached != null ? UserRole.parse(cached) : _defaultRole;
    try {
      final snap = await _users
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 6));
      if (snap.exists) {
        role = UserRole.parse(snap.data()?['role']);
      } else {
        // Account made before roles existed: create its record now.
        role = _defaultRole;
        await _users.doc(uid).set({
          'name': AuthService.accountName,
          'email': AuthService.email,
          'role': role.name,
          'birthDate': '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await prefs?.setString('role_$uid', role.name);
    } catch (_) {
      // Offline or blocked by the rules: keep the saved / default role.
    }
    currentRole.value = role;
  }

  // ----- Admin only -----

  static Future<List<UserRecord>> listUsers() async {
    final snap = await _users.get();
    final list = [
      for (final d in snap.docs)
        UserRecord(
          uid: d.id,
          name: (d.data()['name'] as String?) ?? '',
          email: (d.data()['email'] as String?) ?? '',
          role: UserRole.parse(d.data()['role']),
        ),
    ];
    list.sort((a, b) => a.email.toLowerCase().compareTo(b.email.toLowerCase()));
    return list;
  }

  static Future<void> setRole(String uid, UserRole role) =>
      _users.doc(uid).update({'role': role.name});
}
