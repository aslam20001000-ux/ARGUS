import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/profile_storage.dart';
import '../../core/auth_service.dart';
import '../../core/widgets/animated_action_button.dart';
import '../../core/widgets/argus_eye.dart';
import 'session.dart';
import '../../core/app_colors.dart';

/// Create-account flow (like Facebook): step 1 = name + birth date,
/// step 2 = email + password.
class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  static const _minAge = 13;

  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  int _step = 0;
  DateTime? _birthDate;
  bool _birthError = false;
  bool _busy = false;
  bool _hidePassword = true;
  AuthError? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  int? get _age {
    final b = _birthDate;
    if (b == null) return null;
    final now = DateTime.now();
    var age = now.year - b.year;
    if (now.month < b.month || (now.month == b.month && now.day < b.day)) {
      age--;
    }
    return age;
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25, 1, 1),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: isArabic.value ? 'تاريخ الميلاد' : 'Date of birth',
      initialEntryMode: DatePickerEntryMode.input,
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _birthError = false;
      });
    }
  }

  void _next() {
    final okName = _step1Key.currentState!.validate();
    final age = _age;
    final okAge = age != null && age >= _minAge;
    setState(() => _birthError = !okAge);
    if (okName && okAge) setState(() => _step = 1);
  }

  Future<void> _create() async {
    if (_busy || !_step2Key.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await AuthService.signUp(
      name: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    // The name typed here becomes the patient name in the profile
    // (instead of "John Doe").
    final b = _birthDate!;
    patientProfile
      ..reset()
      ..name = _nameController.text.trim()
      ..age = '${_age ?? ''}'
      ..birthDate =
          '${b.year}-${b.month.toString().padLeft(2, '0')}-${b.day.toString().padLeft(2, '0')}';
    await ProfileStorage.save();
    if (!mounted) return;
    openApp(context);
  }

  String _errorText(AuthError e, bool ar) => switch (e) {
    AuthError.emailInUse =>
      ar ? 'الإيميل مستخدم بالفعل' : 'This email is already in use',
    AuthError.invalidEmail =>
      ar ? 'مسموح فقط بإيميلات @gmail.com' : 'Only @gmail.com emails are allowed',
    AuthError.weakPassword =>
      ar ? 'كلمة المرور ضعيفة (6 أحرف على الأقل)' : 'Password is too weak',
    AuthError.network => ar ? 'لا يوجد اتصال بالإنترنت' : 'No internet connection',
    AuthError.tooManyRequests =>
      ar ? 'محاولات كثيرة، حاول بعد قليل' : 'Too many attempts. Try later',
    _ => ar ? 'حدث خطأ، حاول مرة أخرى' : 'Something went wrong. Try again',
  };

  InputDecoration _dec(String label, IconData icon, {Widget? suffix}) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF54A9FF)),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.bg.withValues(alpha: 0.72),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: border(AppColors.text.withValues(alpha: 0.08)),
      enabledBorder: border(AppColors.text.withValues(alpha: 0.08)),
      focusedBorder: border(const Color(0xFF54A9FF), 1.5),
      labelStyle: TextStyle(color: AppColors.text.withValues(alpha: 0.62)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isArabic,
      builder: (context, ar, _) {
        return Directionality(
          textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(
            backgroundColor: AppColors.bg,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _busy
                    ? null
                    : () => _step == 1
                          ? setState(() => _step = 0)
                          : Navigator.pop(context),
              ),
            ),
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      children: [
                        SizedBox(
                          width: 70,
                          height: 44,
                          child: CustomPaint(
                            painter: ArgusEyePainter(pulse: 0.5),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(26),
                          decoration: BoxDecoration(
                            color: AppColors.card.withValues(alpha: 0.91),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: const Color(0xFF54A9FF).withValues(alpha: 0.16),
                            ),
                          ),
                          child: _step == 0 ? _stepOne(ar) : _stepTwo(ar),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _title(String t, String sub) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        t,
        style:  TextStyle(
          color: AppColors.text,
          fontSize: 23,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        sub,
        style: TextStyle(color: AppColors.text.withValues(alpha: 0.5), fontSize: 12),
      ),
      const SizedBox(height: 24),
    ],
  );

  Widget _button(String text, VoidCallback onTap) => AnimatedActionButton(
    onPressed: _busy ? null : onTap,
    style: ElevatedButton.styleFrom(
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 17),
      backgroundColor: const Color(0xFF54A9FF),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    child: _busy
        ? const SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
          )
        : Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
  );

  Widget _stepOne(bool ar) {
    final b = _birthDate;
    final dateText = b == null
        ? (ar ? 'تاريخ الميلاد' : 'Date of birth')
        : '${b.day.toString().padLeft(2, '0')}/${b.month.toString().padLeft(2, '0')}/${b.year}'
              '   ($_age ${ar ? 'سنة' : 'years'})';
    return Form(
      key: _step1Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(
            ar ? 'إنشاء حساب' : 'Create account',
            ar ? 'الخطوة 1 من 2 — اسمك وسنك' : 'Step 1 of 2 — your name and age',
          ),
          TextFormField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            decoration: _dec(ar ? 'الاسم' : 'Full name', Icons.person_outline_rounded),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? (ar ? 'من فضلك أدخل اسمك' : 'Please enter your name')
                : null,
          ),
          const SizedBox(height: 15),
          InkWell(
            onTap: _pickBirthDate,
            borderRadius: BorderRadius.circular(16),
            child: InputDecorator(
              decoration: _dec(
                ar ? 'تاريخ الميلاد' : 'Date of birth',
                Icons.cake_outlined,
              ).copyWith(
                errorText: _birthError
                    ? (b == null
                          ? (ar ? 'اختر تاريخ ميلادك' : 'Choose your birth date')
                          : (ar
                                ? 'لازم السن يكون $_minAge سنة أو أكتر'
                                : 'You must be at least $_minAge'))
                    : null,
              ),
              child: Text(
                dateText,
                style: TextStyle(
                  color: b == null ? AppColors.text.withValues(alpha: .54) : AppColors.text,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _button(ar ? 'التالي' : 'Next', _next),
        ],
      ),
    );
  }

  Widget _stepTwo(bool ar) {
    return Form(
      key: _step2Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(
            ar ? 'الإيميل وكلمة المرور' : 'Email and password',
            ar ? 'الخطوة 2 من 2' : 'Step 2 of 2',
          ),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() => _error = null),
            decoration: _dec(
              ar ? 'الإيميل' : 'Email',
              Icons.email_outlined,
            ).copyWith(hintText: 'name@gmail.com'),
            validator: (v) {
              return AuthService.isAllowedEmail(v ?? '')
                  ? null
                  : (ar
                        ? 'اكتب إيميل @gmail.com صحيح'
                        : 'Enter a valid @gmail.com address');
            },
          ),
          const SizedBox(height: 15),
          TextFormField(
            controller: _passwordController,
            obscureText: _hidePassword,
            textInputAction: TextInputAction.next,
            decoration: _dec(
              ar ? 'كلمة المرور' : 'Password',
              Icons.lock_outline_rounded,
              suffix: IconButton(
                icon: Icon(
                  _hidePassword ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.text.withValues(alpha: .54),
                ),
                onPressed: () => setState(() => _hidePassword = !_hidePassword),
              ),
            ),
            validator: (v) => (v ?? '').length < 6
                ? (ar ? '6 أحرف على الأقل' : 'At least 6 characters')
                : null,
          ),
          const SizedBox(height: 15),
          TextFormField(
            controller: _confirmController,
            obscureText: _hidePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _create(),
            decoration: _dec(
              ar ? 'تأكيد كلمة المرور' : 'Confirm password',
              Icons.lock_outline_rounded,
            ),
            validator: (v) => v != _passwordController.text
                ? (ar ? 'كلمتا المرور غير متطابقتين' : 'Passwords do not match')
                : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(
              _errorText(_error!, ar),
              style: const TextStyle(
                color: Color(0xFFE65F72),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 24),
          _button(ar ? 'إنشاء الحساب' : 'Create account', _create),
        ],
      ),
    );
  }
}
