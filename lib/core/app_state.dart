import 'package:flutter/material.dart';

/// Name of the account that is logged in. Each account is one person, so
/// this is normally the same person as [patientProfile] (whose name can be
/// edited separately in the profile page).
final ValueNotifier<String> currentUserName = ValueNotifier<String>('');

final ValueNotifier<bool> isArabic = ValueNotifier<bool>(false);

/// Picks the Arabic or English text depending on the chosen language.
String tr(String en, String ar) => isArabic.value ? ar : en;

/// true = dark theme, false = light theme (saved in Settings).
final ValueNotifier<bool> darkMode = ValueNotifier<bool>(true);

final PatientProfileData patientProfile = PatientProfileData();

class PatientProfileData {
  String id = 'PT-001';
  String name = 'John Doe';
  String age = '45';
  String gender = 'Male';
  String bloodGroup = 'O+';
  String height = '175';
  String weight = '78';
  String room = 'ICU Room 04';
  String doctor = 'Dr. Ahmed Hassan';
  String chronicDiseases = 'Hypertension';
  String allergies = 'No known allergies';
  String medications = 'Amlodipine 5 mg';
  String emergencyContact = '+20 100 000 0000';
  String notes = 'Patient under continuous monitoring.';

  /// Birth date typed at sign-up (yyyy-mm-dd), '' if unknown.
  String birthDate = '';

  Map<String, String> toJson() => {
    'id': id,
    'name': name,
    'age': age,
    'gender': gender,
    'bloodGroup': bloodGroup,
    'height': height,
    'weight': weight,
    'room': room,
    'doctor': doctor,
    'chronicDiseases': chronicDiseases,
    'allergies': allergies,
    'medications': medications,
    'emergencyContact': emergencyContact,
    'notes': notes,
    'birthDate': birthDate,
  };

  /// Copies the given values in; missing keys keep their current value.
  void applyJson(Map<String, dynamic> j) {
    String pick(String key, String current) =>
        j[key] is String ? j[key] as String : current;
    id = pick('id', id);
    name = pick('name', name);
    age = pick('age', age);
    gender = pick('gender', gender);
    bloodGroup = pick('bloodGroup', bloodGroup);
    height = pick('height', height);
    weight = pick('weight', weight);
    room = pick('room', room);
    doctor = pick('doctor', doctor);
    chronicDiseases = pick('chronicDiseases', chronicDiseases);
    allergies = pick('allergies', allergies);
    medications = pick('medications', medications);
    emergencyContact = pick('emergencyContact', emergencyContact);
    notes = pick('notes', notes);
    birthDate = pick('birthDate', birthDate);
  }

  /// Back to the default (demo) values.
  void reset() => applyJson(PatientProfileData().toJson());
}
