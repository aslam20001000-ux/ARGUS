import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/auth_service.dart';
import '../../core/profile_storage.dart';
import '../../core/responsive.dart';
import '../home/app_drawer.dart';
import '../../core/app_colors.dart';

const _blue = Color(0xFF54A9FF);
const _cyan = Color(0xFF4FD8E8);
const _green = Color(0xFF38E08F);
const _amber = Color(0xFFFFB547);
const _red = Color(0xFFE65F72);
const _violet = Color(0xFF9B8CFF);

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

  @override
  Widget build(BuildContext context) {
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
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: editing
                ? Row(
                    children: [
                      TextButton(
                        onPressed: () => setState(() => editing = false),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: AppColors.text.withValues(alpha: .6),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      FilledButton.icon(
                        onPressed: _saveProfile,
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Save'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _green,
                          foregroundColor: const Color(0xFF06231A),
                        ),
                      ),
                    ],
                  )
                : FilledButton.tonalIcon(
                    onPressed: () => setState(() => editing = true),
                    icon: const Icon(Icons.edit_rounded, size: 17),
                    label: const Text('Edit'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _blue.withValues(alpha: .14),
                      foregroundColor: _blue,
                    ),
                  ),
          ),
        ],
      ),
      body: ContentFrame(
        maxWidth: 1120,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: editing
              ? KeyedSubtree(key: const ValueKey('edit'), child: _editView())
              : const KeyedSubtree(
                  key: ValueKey('view'),
                  child: _ProfileView(),
                ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- edit

  InputDecoration _decoration(String label, IconData icon) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _blue, size: 20),
      filled: true,
      fillColor: AppColors.bg,
      border: border(AppColors.text.withValues(alpha: .07)),
      enabledBorder: border(AppColors.text.withValues(alpha: .07)),
      focusedBorder: border(_blue, 1.5),
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
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: _decoration(label, icon),
    );
  }

  Widget _editView() {
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 760;
        Widget pair(Widget a, Widget b) => wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: a),
                  const SizedBox(width: 12),
                  Expanded(child: b),
                ],
              )
            : Column(children: [a, const SizedBox(height: 12), b]);

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
          children: [
            _EditSection(
              icon: Icons.badge_rounded,
              color: _blue,
              title: 'Identity',
              children: [
                pair(
                  _field(nameController, 'Full Name', Icons.person_outline),
                  _field(idController, 'Patient ID', Icons.badge_outlined),
                ),
                pair(
                  _field(roomController, 'Room / Bed', Icons.bed_outlined),
                  _field(
                    doctorController,
                    'Attending Doctor',
                    Icons.medical_services_outlined,
                  ),
                ),
              ],
            ),
            _EditSection(
              icon: Icons.accessibility_new_rounded,
              color: _cyan,
              title: 'Body',
              children: [
                pair(
                  _field(
                    ageController,
                    'Age',
                    Icons.cake_outlined,
                    keyboardType: TextInputType.number,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: gender,
                    decoration: _decoration('Gender', Icons.wc_outlined),
                    dropdownColor: AppColors.card,
                    items: const [
                      DropdownMenuItem(value: 'Male', child: Text('Male')),
                      DropdownMenuItem(value: 'Female', child: Text('Female')),
                    ],
                    onChanged: (value) =>
                        setState(() => gender = value ?? gender),
                  ),
                ),
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
                pair(
                  _field(
                    heightController,
                    'Height (cm)',
                    Icons.height,
                    keyboardType: TextInputType.number,
                  ),
                  _field(
                    weightController,
                    'Weight (kg)',
                    Icons.monitor_weight_outlined,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            _EditSection(
              icon: Icons.medical_information_rounded,
              color: _amber,
              title: 'Medical record',
              subtitle: 'Separate several items with commas',
              children: [
                _field(
                  diseasesController,
                  'Chronic Diseases',
                  Icons.healing_outlined,
                  maxLines: 2,
                ),
                _field(
                  allergiesController,
                  'Allergies',
                  Icons.warning_amber_rounded,
                  maxLines: 2,
                ),
                _field(
                  medicationsController,
                  'Current Medications',
                  Icons.medication_outlined,
                  maxLines: 2,
                ),
              ],
            ),
            _EditSection(
              icon: Icons.contact_phone_rounded,
              color: _green,
              title: 'Contact & notes',
              children: [
                _field(
                  emergencyController,
                  'Emergency Contact',
                  Icons.contact_phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                _field(
                  notesController,
                  'Clinical Notes',
                  Icons.notes_outlined,
                  maxLines: 4,
                ),
              ],
            ),
            const SizedBox(height: 6),
            FilledButton.icon(
              onPressed: _saveProfile,
              icon: const Icon(Icons.save_rounded),
              label: const Text(
                'Save Patient Profile',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 17),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EditSection extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const _EditSection({
    required this.icon,
    required this.color,
    required this.title,
    required this.children,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(icon: icon, color: color, title: title, sub: subtitle),
          const SizedBox(height: 16),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            children[i],
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// View mode
// ---------------------------------------------------------------------------

BoxDecoration _cardDecoration({Color? tint}) => BoxDecoration(
  color: tint == null
      ? AppColors.card
      : Color.alphaBlend(tint.withValues(alpha: .06), AppColors.card),
  borderRadius: BorderRadius.circular(24),
  border: Border.all(
    color:
        tint?.withValues(alpha: .22) ?? AppColors.text.withValues(alpha: .055),
  ),
);

/// Splits "a, b\nc" into ["a", "b", "c"].
List<String> _items(String s) => [
  for (final part in s.split(RegExp(r'[,\n،;]')))
    if (part.trim().isNotEmpty) part.trim(),
];

String _initials(String name) {
  final parts = name
      .replaceAll(RegExp(r'^(dr\.?|د\.?)\s*', caseSensitive: false), '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  final first = parts.first.characters.first;
  final last = parts.length > 1 ? parts.last.characters.first : '';
  return (first + last).toUpperCase();
}

class _ProfileView extends StatelessWidget {
  const _ProfileView();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        // Tablets (landscape and most portrait) and laptops: two columns.
        final wide = box.maxWidth >= 760;
        final left = [
          const _BodyCard(),
          const SizedBox(height: 16),
          const _CareTeamCard(),
        ];
        final right = [
          const _MedicalRecordCard(),
          const SizedBox(height: 16),
          const _NotesCard(),
        ];
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 32),
          children: [
            _HeroBanner(wide: wide),
            const SizedBox(height: 16),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: Column(children: left)),
                  const SizedBox(width: 16),
                  Expanded(flex: 6, child: Column(children: right)),
                ],
              )
            else ...[
              ...left,
              const SizedBox(height: 16),
              ...right,
            ],
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 13,
                  color: AppColors.text.withValues(alpha: .35),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Shared with the monitoring modules for identification '
                    'and clinical context.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.text.withValues(alpha: .38),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ----- Hero ---------------------------------------------------------------

class _HeroBanner extends StatelessWidget {
  final bool wide;
  const _HeroBanner({required this.wide});

  @override
  Widget build(BuildContext context) {
    final p = patientProfile;
    final chips = [
      _HeroChip(Icons.badge_outlined, p.id),
      if (p.room.isNotEmpty) _HeroChip(Icons.bed_outlined, p.room),
      if (p.bloodGroup.isNotEmpty)
        _HeroChip(Icons.bloodtype_rounded, p.bloodGroup, color: _red),
      if (p.age.isNotEmpty)
        _HeroChip(Icons.cake_outlined, '${p.age} y · ${p.gender}'),
    ];

    final avatar = Container(
      width: wide ? 116 : 92,
      height: wide ? 116 : 92,
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(colors: [_cyan, _blue, _violet, _cyan]),
      ),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1C4C7E), Color(0xFF0E2744)],
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                _initials(p.name),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: wide ? 40 : 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
            Positioned(
              right: wide ? 6 : 3,
              bottom: wide ? 6 : 3,
              child: Container(
                width: wide ? 22 : 18,
                height: wide ? 22 : 18,
                decoration: BoxDecoration(
                  color: _green,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0E2744), width: 3),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final info = Column(
      crossAxisAlignment: wide
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _MonitoringBadge(),
        const SizedBox(height: 10),
        Text(
          p.name,
          textAlign: wide ? TextAlign.start : TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: wide ? 32 : 26,
            height: 1.1,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (p.doctor.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Under the care of ${p.doctor}',
            textAlign: wide ? TextAlign.start : TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .65),
              fontSize: 13.5,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: wide ? WrapAlignment.start : WrapAlignment.center,
          children: chips,
        ),
      ],
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF123A66), Color(0xFF0B2546), Color(0xFF0A1B33)],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: IgnorePointer(child: CustomPaint(painter: _HeroArt())),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                wide ? 32 : 20,
                wide ? 30 : 24,
                wide ? 32 : 20,
                wide ? 30 : 22,
              ),
              child: wide
                  ? Row(
                      children: [
                        avatar,
                        const SizedBox(width: 26),
                        Expanded(child: info),
                      ],
                    )
                  : Column(
                      children: [avatar, const SizedBox(height: 16), info],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Decorative glow circles and an ECG trace behind the hero content.
class _HeroArt extends CustomPainter {
  const _HeroArt();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      Offset(size.width * .92, size.height * .1),
      size.height * .9,
      Paint()
        ..shader =
            RadialGradient(
              colors: [_cyan.withValues(alpha: .22), Colors.transparent],
            ).createShader(
              Rect.fromCircle(
                center: Offset(size.width * .92, size.height * .1),
                radius: size.height * .9,
              ),
            ),
    );
    canvas.drawCircle(
      Offset(size.width * .05, size.height * 1.05),
      size.height * .7,
      Paint()
        ..shader =
            RadialGradient(
              colors: [_violet.withValues(alpha: .16), Colors.transparent],
            ).createShader(
              Rect.fromCircle(
                center: Offset(size.width * .05, size.height * 1.05),
                radius: size.height * .7,
              ),
            ),
    );

    // ECG trace across the lower part.
    // Kept near the bottom edge so it never runs behind the chips.
    final y0 = size.height - 22;
    final path = Path()..moveTo(0, y0);
    const beat = 150.0;
    for (double x = 0; x < size.width; x += beat) {
      path
        ..lineTo(x + 50, y0)
        ..lineTo(x + 60, y0 - 3)
        ..lineTo(x + 68, y0)
        ..lineTo(x + 76, y0 + 4)
        ..lineTo(x + 84, y0 - 16)
        ..lineTo(x + 92, y0 + 7)
        ..lineTo(x + 100, y0)
        ..lineTo(x + 118, y0 - 5)
        ..lineTo(x + 130, y0)
        ..lineTo(x + beat, y0);
    }
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: [
            _cyan.withValues(alpha: 0),
            _cyan.withValues(alpha: .28),
            _cyan.withValues(alpha: .05),
          ],
        ).createShader(Offset.zero & size)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _HeroChip(this.icon, this.text, {this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: .12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color.withValues(alpha: .85)),
          const SizedBox(width: 7),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonitoringBadge extends StatefulWidget {
  const _MonitoringBadge();

  @override
  State<_MonitoringBadge> createState() => _MonitoringBadgeState();
}

class _MonitoringBadgeState extends State<_MonitoringBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 11, 5),
      decoration: BoxDecoration(
        color: _green.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _green.withValues(alpha: .35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 6 + 8 * _c.value,
                    height: 6 + 8 * _c.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _green.withValues(alpha: .45 * (1 - _c.value)),
                    ),
                  ),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: _green,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'UNDER MONITORING',
            style: TextStyle(
              color: _green,
              fontSize: 10.5,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ----- Body + BMI -----------------------------------------------------------

class _BodyCard extends StatelessWidget {
  const _BodyCard();

  @override
  Widget build(BuildContext context) {
    final p = patientProfile;
    final h = double.tryParse(p.height.replaceAll(',', '.'));
    final w = double.tryParse(p.weight.replaceAll(',', '.'));
    final bmi = (h != null && w != null && h > 0) ? w / pow(h / 100, 2) : null;

    Widget stat(String label, String value, String unit, IconData icon) =>
        Expanded(
          child: Column(
            children: [
              Icon(icon, size: 20, color: _blue.withValues(alpha: .8)),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: value.isEmpty ? '—' : value),
                      if (value.isNotEmpty && unit.isNotEmpty)
                        TextSpan(
                          text: ' $unit',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text.withValues(alpha: .5),
                          ),
                        ),
                    ],
                  ),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.text.withValues(alpha: .5),
                ),
              ),
            ],
          ),
        );

    Widget divider() => Container(
      width: 1,
      height: 46,
      color: AppColors.text.withValues(alpha: .07),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle(
            icon: Icons.accessibility_new_rounded,
            color: _cyan,
            title: 'Body metrics',
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              stat('Age', p.age, 'yrs', Icons.cake_outlined),
              divider(),
              stat(
                'Gender',
                p.gender,
                '',
                p.gender == 'Female'
                    ? Icons.female_rounded
                    : Icons.male_rounded,
              ),
              divider(),
              stat('Height', p.height, 'cm', Icons.height_rounded),
              divider(),
              stat('Weight', p.weight, 'kg', Icons.monitor_weight_outlined),
            ],
          ),
          const SizedBox(height: 20),
          _BmiGauge(bmi: bmi),
        ],
      ),
    );
  }
}

class _BmiGauge extends StatelessWidget {
  final double? bmi;
  const _BmiGauge({required this.bmi});

  static const _min = 15.0, _max = 40.0;

  @override
  Widget build(BuildContext context) {
    final b = bmi;
    final (label, color) = b == null
        ? ('Add height & weight', AppColors.text.withValues(alpha: .45))
        : b < 18.5
        ? ('Underweight', _cyan)
        : b < 25
        ? ('Normal', _green)
        : b < 30
        ? ('Overweight', _amber)
        : ('Obese', _red);

    double pos(double v) => ((v - _min) / (_max - _min)).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'BMI',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: AppColors.text.withValues(alpha: .55),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                b == null ? '--' : b.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 26,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth;
              return SizedBox(
                height: 22,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 7,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: LinearGradient(
                            colors: const [_cyan, _green, _green, _amber, _red],
                            stops: [
                              pos(17),
                              pos(19.5),
                              pos(24),
                              pos(27.5),
                              pos(32),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (b != null)
                      Positioned(
                        left: w * pos(b) - 11,
                        top: 0,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: color, width: 5),
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: .5),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, box) {
              final muted = TextStyle(
                fontSize: 10,
                color: AppColors.text.withValues(alpha: .4),
              );
              return SizedBox(
                height: 14,
                child: Stack(
                  children: [
                    for (final v in [18.5, 25.0, 30.0])
                      Positioned(
                        left: box.maxWidth * pos(v) - 12,
                        child: SizedBox(
                          width: 24,
                          child: Text(
                            v.toStringAsFixed(v % 1 == 0 ? 0 : 1),
                            textAlign: TextAlign.center,
                            style: muted,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ----- Medical record -------------------------------------------------------

class _MedicalRecordCard extends StatelessWidget {
  const _MedicalRecordCard();

  @override
  Widget build(BuildContext context) {
    final p = patientProfile;
    final allergies = _items(p.allergies);
    final noAllergy =
        allergies.isEmpty ||
        allergies.every(
          (a) =>
              RegExp(r'\bno\b|none|nka|لا', caseSensitive: false).hasMatch(a),
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle(
            icon: Icons.medical_information_rounded,
            color: _amber,
            title: 'Medical record',
          ),
          const SizedBox(height: 16),
          _RecordBlock(
            icon: Icons.healing_rounded,
            color: _amber,
            title: 'Chronic conditions',
            items: _items(p.chronicDiseases),
            empty: 'None recorded',
          ),
          const SizedBox(height: 12),
          _RecordBlock(
            icon: noAllergy
                ? Icons.verified_rounded
                : Icons.warning_amber_rounded,
            color: noAllergy ? _green : _red,
            title: 'Allergies',
            items: allergies,
            empty: 'No known allergies',
            highlight: !noAllergy,
          ),
          const SizedBox(height: 12),
          _RecordBlock(
            icon: Icons.medication_rounded,
            color: _violet,
            title: 'Current medications',
            items: _items(p.medications),
            empty: 'No medications',
            pill: true,
          ),
        ],
      ),
    );
  }
}

class _RecordBlock extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final List<String> items;
  final String empty;
  final bool highlight;
  final bool pill;

  const _RecordBlock({
    required this.icon,
    required this.color,
    required this.title,
    required this.items,
    required this.empty,
    this.highlight = false,
    this.pill = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: highlight ? .10 : .05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: highlight ? .4 : .14),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.5,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text.withValues(alpha: .5),
                  ),
                ),
                const SizedBox(height: 8),
                if (items.isEmpty)
                  Text(
                    empty,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text.withValues(alpha: .7),
                    ),
                  )
                else
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final item in items)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(pill ? 30 : 10),
                            border: Border.all(
                              color: color.withValues(alpha: .3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (pill) ...[
                                Icon(Icons.circle, size: 7, color: color),
                                const SizedBox(width: 6),
                              ],
                              Flexible(
                                child: Text(
                                  item,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ----- Care team ------------------------------------------------------------

class _CareTeamCard extends StatelessWidget {
  const _CareTeamCard();

  @override
  Widget build(BuildContext context) {
    final p = patientProfile;

    Widget row({
      required Widget leading,
      required String label,
      required String value,
      required IconData trailing,
      required Color color,
    }) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.text.withValues(alpha: .5),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? '—' : value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .14),
              shape: BoxShape.circle,
            ),
            child: Icon(trailing, color: color, size: 18),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle(
            icon: Icons.groups_rounded,
            color: _blue,
            title: 'Care team',
          ),
          const SizedBox(height: 14),
          row(
            leading: Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [_blue, _violet]),
              ),
              child: Text(
                _initials(p.doctor),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
            label: 'Attending doctor',
            value: p.doctor,
            trailing: Icons.medical_services_rounded,
            color: _blue,
          ),
          const SizedBox(height: 10),
          row(
            leading: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _red.withValues(alpha: .14),
              ),
              child: const Icon(Icons.emergency_rounded, color: _red),
            ),
            label: 'Emergency contact',
            value: p.emergencyContact,
            trailing: Icons.call_rounded,
            color: _green,
          ),
        ],
      ),
    );
  }
}

// ----- Notes ----------------------------------------------------------------

class _NotesCard extends StatelessWidget {
  const _NotesCard();

  @override
  Widget build(BuildContext context) {
    final notes = patientProfile.notes;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: _cardDecoration(tint: _green),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle(
            icon: Icons.sticky_note_2_rounded,
            color: _green,
            title: 'Clinical notes',
          ),
          const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: _green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    notes.isEmpty ? 'No notes yet.' : notes,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.55,
                      fontStyle: notes.isEmpty
                          ? FontStyle.italic
                          : FontStyle.normal,
                      color: AppColors.text.withValues(alpha: .82),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ----- Shared ---------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? sub;
  const _SectionTitle({
    required this.icon,
    required this.color,
    required this.title,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            if (sub != null)
              Text(
                sub!,
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.text.withValues(alpha: .5),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
