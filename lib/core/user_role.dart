import 'package:flutter/foundation.dart';

/// What a signed-in person is allowed to do.
///
/// * admin  – everything, and can change other people's roles.
/// * doctor – edit alarm limits and the patient profile.
/// * nurse  – view everything, silence alarms, but cannot edit limits or the
///            patient profile.
enum UserRole {
  admin,
  doctor,
  nurse;

  String get label => switch (this) {
    UserRole.admin => 'Admin',
    UserRole.doctor => 'Doctor',
    UserRole.nurse => 'Nurse',
  };

  bool get canEditLimits => this != UserRole.nurse;
  bool get canEditProfile => this != UserRole.nurse;
  bool get canManageUsers => this == UserRole.admin;

  static UserRole parse(Object? value) => UserRole.values.firstWhere(
    (r) => r.name == value,
    orElse: () => UserRole.nurse,
  );
}

/// Role of the person who is signed in now (nurse = least privileges until
/// the real role is loaded).
final ValueNotifier<UserRole> currentRole = ValueNotifier<UserRole>(
  UserRole.nurse,
);
