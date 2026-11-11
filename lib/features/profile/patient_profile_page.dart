import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/auth_service.dart';
import '../../core/profile_storage.dart';
import '../../core/responsive.dart';
import '../home/app_drawer.dart';
import '../../core/app_colors.dart';

class PatientProfilePage extends StatefulWidget {
  const PatientProfilePage({super.key});

  @override
  State<PatientProfilePage> createState() => _PatientProfilePageState();
}

class _PatientProfilePageState extends State<PatientProfilePage> {
  bool editing = false;
  late final TextEditingController idController;
  late final TextEditingController nameController;
  late final TextEditingController ageController;
  late final TextEditingController heightController;
  late final TextEditingController weightController;
  late final TextEditingController roomController;
  late final TextEditingController doctorController;
  late final TextEditingController diseasesController;
  late final TextEditingController allergiesController;
  late final TextEditingController medicationsController;
  late final TextEditingController emergencyController;
  late final TextEditingController notesController;
  String gender = patientProfile.gender;

  static const List<String> _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  // Null when the saved value is not one of the standard blood groups.
  String? selectedBlood = _bloodGroups.contains(patientProfile.bloodGroup)
      ? patientProfile.bloodGroup
      : null;

  @override
  void initState() {
    super.initState();
    idController = TextEditingController(text: patientProfile.id);
    nameController = TextEditingController(text: patientProfile.name);
    ageController = TextEditingController(text: patientProfile.age);
    heightController = TextEditingController(text: patientProfile.height);
    weightController = TextEditingController(text: patientProfile.weight);
    roomController = TextEditingController(text: patientProfile.room);
    doctorController = TextEditingController(text: patientProfile.doctor);
    diseasesController = TextEditingController(
      text: patientProfile.chronicDiseases,
    );
    allergiesController = TextEditingController(text: patientProfile.allergies);
    medicationsController = TextEditingController(
      text: patientProfile.medications,
    );
    emergencyController = TextEditingController(
      text: patientProfile.emergencyContact,
    );
    notesController = TextEditingController(text: patientProfile.notes);
  }

  @override
  void dispose() {
    for (final controller in [
      idController,
      nameController,
      ageController,
      heightController,
      weightController,
      roomController,
      doctorController,
      diseasesController,
      allergiesController,
      medicationsController,
      emergencyController,
      notesController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _saveProfile() {
    patientProfile
      ..id = idController.text.trim().isEmpty
          ? 'PT-001'
          : idController.text.trim()
      ..name = nameController.text.trim().isEmpty
          ? AuthService.accountName
          : nameController.text.trim()
      ..age = ageController.text.trim()
      ..gender = gender
      ..bloodGroup = selectedBlood ?? ''
      ..height = heightController.text.trim()
      ..weight = weightController.text.trim()
      ..room = roomController.text.trim()
      ..doctor = doctorController.text.trim()
      ..chronicDiseases = diseasesController.text.trim()
      ..allergies = allergiesController.text.trim()
      ..medications = medicationsController.text.trim()
      ..emergencyContact = emergencyController.text.trim()
      ..notes = notesController.text.trim();
    ProfileStorage.save();
    setState(() => editing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Patient profile saved successfully'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF54A9FF)),
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
        borderSide: const BorderSide(color: Color(0xFF54A9FF), width: 1.5),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      enabled: editing,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: _decoration(label, icon),
    );
  }

  Widget _infoTile(
    IconData icon,
    String title,
    String value, {
    Color color = const Color(0xFF54A9FF),
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.text.withValues(alpha: .055)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:  TextStyle(color: AppColors.text.withValues(alpha: .54), fontSize: 11),
                ),
                const SizedBox(height: 3),
                Text(
                  value.isEmpty ? '—' : value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = patientProfile;
    return Scaffold(
      backgroundColor: AppColors.bg,
      drawer: const AppDrawer(current: AppSection.profile),
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: const DrawerMenuButton(),
        title: const Text(
          'Patient Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: editing
                ? _saveProfile
                : () => setState(() => editing = true),
            icon: Icon(editing ? Icons.check_rounded : Icons.edit_rounded),
            color: editing ? const Color(0xFF38E08F) : const Color(0xFF54A9FF),
          ),
        ],
      ),
      body: ContentFrame(
        maxWidth: 760,
        child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient:  LinearGradient(
                  colors: [AppColors.cardAlt, AppColors.card],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFF54A9FF).withValues(alpha: .16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF54A9FF).withValues(alpha: .12),
                      border: Border.all(
                        color: const Color(0xFF54A9FF).withValues(alpha: .35),
                      ),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Color(0xFF54A9FF),
                      size: 38,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${p.id}  •  ${p.room}',
                          style:  TextStyle(
                            color: AppColors.text.withValues(alpha: .54),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF38E08F,
                            ).withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'UNDER MONITORING',
                            style: TextStyle(
                              color: Color(0xFF38E08F),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (editing) ...[
              _field(idController, 'Patient ID', Icons.badge_outlined),
              const SizedBox(height: 12),
              _field(nameController, 'Full Name', Icons.person_outline),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      ageController,
                      'Age',
                      Icons.cake_outlined,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: gender,
                      decoration: _decoration('Gender', Icons.wc_outlined),
                      items: const [
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(
                          value: 'Female',
                          child: Text('Female'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => gender = value ?? gender),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedBlood,
                isExpanded: true,
                decoration: _decoration(
                  'Blood Group',
                  Icons.bloodtype_outlined,
                ),
                dropdownColor: AppColors.card,
                hint: const Text('Select blood group'),
                items: [
                  for (final group in _bloodGroups)
                    DropdownMenuItem(value: group, child: Text(group)),
                ],
                onChanged: (value) => setState(() => selectedBlood = value),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      heightController,
                      'Height (cm)',
                      Icons.height,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field(
                      weightController,
                      'Weight (kg)',
                      Icons.monitor_weight_outlined,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _field(roomController, 'Room / Bed', Icons.bed_outlined),
              const SizedBox(height: 12),
              _field(
                doctorController,
                'Attending Doctor',
                Icons.medical_services_outlined,
              ),
              const SizedBox(height: 12),
              _field(
                diseasesController,
                'Chronic Diseases',
                Icons.healing_outlined,
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              _field(
                allergiesController,
                'Allergies',
                Icons.warning_amber_rounded,
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              _field(
                medicationsController,
                'Current Medications',
                Icons.medication_outlined,
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              _field(
                emergencyController,
                'Emergency Contact',
                Icons.contact_phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _field(
                notesController,
                'Clinical Notes',
                Icons.notes_outlined,
                maxLines: 4,
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _saveProfile,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Save Patient Profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF54A9FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ] else ...[
              const Text(
                'Patient Overview',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              IntrinsicHeight(child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _infoTile(
                      Icons.cake_outlined,
                      'AGE',
                      '${p.age} years',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _infoTile(Icons.wc_outlined, 'GENDER', p.gender),
                  ),
                ],
              )),
              const SizedBox(height: 10),
              IntrinsicHeight(child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _infoTile(
                      Icons.bloodtype_outlined,
                      'BLOOD GROUP',
                      p.bloodGroup,
                      color: const Color(0xFFE65F72),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _infoTile(Icons.height, 'HEIGHT', '${p.height} cm'),
                  ),
                ],
              )),
              const SizedBox(height: 10),
              IntrinsicHeight(child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _infoTile(
                      Icons.monitor_weight_outlined,
                      'WEIGHT',
                      '${p.weight} kg',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _infoTile(
                      Icons.medical_services_outlined,
                      'DOCTOR',
                      p.doctor,
                    ),
                  ),
                ],
              )),
              const SizedBox(height: 18),
              _infoTile(
                Icons.healing_outlined,
                'CHRONIC DISEASES',
                p.chronicDiseases,
                color: const Color(0xFFFFB454),
              ),
              const SizedBox(height: 10),
              _infoTile(
                Icons.warning_amber_rounded,
                'ALLERGIES',
                p.allergies,
                color: const Color(0xFFFFB454),
              ),
              const SizedBox(height: 10),
              _infoTile(
                Icons.medication_outlined,
                'CURRENT MEDICATIONS',
                p.medications,
                color: const Color(0xFF38E08F),
              ),
              const SizedBox(height: 10),
              _infoTile(
                Icons.contact_phone_outlined,
                'EMERGENCY CONTACT',
                p.emergencyContact,
              ),
              const SizedBox(height: 10),
              _infoTile(
                Icons.notes_outlined,
                'CLINICAL NOTES',
                p.notes,
                color: const Color(0xFF38E08F),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF38E08F).withValues(alpha: .15),
                  ),
                ),
                child:  Row(
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      color: Color(0xFF38E08F),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Patient profile is available to the monitoring modules for identification and clinical context.',
                        style: TextStyle(
                          color: AppColors.text.withValues(alpha: .7),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        ),
      ),
    );
  }
}
