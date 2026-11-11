import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/auth_service.dart';
import '../../core/settings_store.dart';
import '../../core/page_route.dart';
import '../../core/widgets/animated_action_button.dart';
import '../../core/widgets/argus_eye.dart';
import 'session.dart';
import 'signup_page.dart';
import '../../core/app_colors.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  /// Reason of the last failed login (null = no error to show).
  AuthError? _authError;

  /// True while waiting for the server to answer.
  bool _signingIn = false;

  late final AnimationController _entryController;
  late final AnimationController _pulseController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _fadeAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.10), end: Offset.zero).animate(
          CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
        );

    _entryController.forward();

    // Hide the error message as soon as the user edits either field.
    _emailController.addListener(_clearLoginError);
    _passwordController.addListener(_clearLoginError);
  }

  void _clearLoginError() {
    if (_authError != null && mounted) setState(() => _authError = null);
  }

  String _errorText(AuthError error, bool arabic) => switch (error) {
    AuthError.invalidCredentials =>
      arabic
          ? 'الإيميل أو كلمة المرور غير صحيحة'
          : 'Incorrect email or password',
    AuthError.invalidEmail =>
      arabic ? 'مسموح فقط بإيميلات @gmail.com' : 'Only @gmail.com emails are allowed',
    AuthError.emailInUse =>
      arabic ? 'الإيميل مستخدم بالفعل' : 'This email is already in use',
    AuthError.weakPassword =>
      arabic ? 'كلمة المرور ضعيفة (6 أحرف على الأقل)' : 'Password is too weak',
    AuthError.tooManyRequests =>
      arabic
          ? 'محاولات كثيرة، حاول مرة أخرى بعد قليل'
          : 'Too many attempts. Try again later',
    AuthError.network =>
      arabic ? 'لا يوجد اتصال بالإنترنت' : 'No internet connection',
    AuthError.disabled =>
      arabic ? 'هذا الحساب موقوف' : 'This account is disabled',
    AuthError.cancelled =>
      arabic ? 'تم إلغاء تسجيل الدخول' : 'Sign-in was cancelled',
    AuthError.unknown =>
      arabic ? 'حدث خطأ، حاول مرة أخرى' : 'Something went wrong. Try again',
  };

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _forgotPassword() async {
    final arabic = isArabic.value;
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController(text: _emailController.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(arabic ? 'استعادة كلمة المرور' : 'Reset password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              arabic
                  ? 'اكتب إيميلك وهنبعتلك رابط لتغيير كلمة المرور.'
                  : 'Enter your email and we will send you a link to choose a new password.',
              style: TextStyle(
                color: AppColors.text.withValues(alpha: .6),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: InputDecoration(
                labelText: arabic ? 'الإيميل' : 'Email',
                prefixIcon: const Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(arabic ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(arabic ? 'إرسال' : 'Send link'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (email == null || email.isEmpty) return;

    final error = await AuthService.sendPasswordReset(email);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          error == null
              ? (arabic
                    ? 'لو الإيميل مسجّل، هيوصلك رابط تغيير كلمة المرور'
                    : 'If this email has an account, a reset link was sent')
              : _errorText(error, arabic),
        ),
      ),
    );
  }

  Future<void> _login() async {
    if (_signingIn) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _signingIn = true;
      _authError = null;
    });

    final error = await AuthService.signIn(
      _emailController.text,
      _passwordController.text,
    );
    if (!mounted) return;

    if (error != null) {
      setState(() {
        _signingIn = false;
        _authError = error;
      });
      return;
    }

    openApp(context);
  }

  Future<void> _google() async {
    if (_signingIn) return;
    setState(() {
      _signingIn = true;
      _authError = null;
    });
    final error = await AuthService.signInWithGoogle();
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _signingIn = false;
        _authError = error == AuthError.cancelled ? null : error;
      });
      return;
    }
    openApp(context);
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF54A9FF)),
      filled: true,
      fillColor: AppColors.bg.withValues(alpha: 0.72),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.text.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.text.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF54A9FF), width: 1.5),
      ),
      labelStyle: TextStyle(color: AppColors.text.withValues(alpha: 0.62)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isArabic,
      builder: (context, arabic, _) {
        final textDirection = arabic ? TextDirection.rtl : TextDirection.ltr;

        return Directionality(
          textDirection: textDirection,
          child: Scaffold(
            backgroundColor: AppColors.bg,
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 760;

                  return Stack(
                    children: [
                      // Subtle medical-tech background.
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _LoginBackgroundPainter(
                              pulse: _pulseController,
                            ),
                          ),
                        ),
                      ),

                      Center(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: isWide ? 40 : 20,
                            vertical: 30,
                          ),
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 1080,
                                ),
                                child: isWide
                                    ? _buildWideLogin(arabic, textDirection)
                                    : _buildCompactLogin(arabic, textDirection),
                              ),
                            ),
                          ),
                        ),
                      ),

                      Positioned(
                        top: 18,
                        right: arabic ? null : 18,
                        left: arabic ? 18 : null,
                        child: _LanguageButton(
                          arabic: arabic,
                          onTap: () => SettingsStore.instance.setArabic(!isArabic.value),
                        ),
                      ),

                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWideLogin(bool arabic, TextDirection textDirection) {
    return Row(
      children: [
        Expanded(
          flex: 11,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: 34),
            child: _buildWelcomePanel(arabic),
          ),
        ),
        Expanded(flex: 9, child: _buildLoginCard(arabic, textDirection)),
      ],
    );
  }

  Widget _buildCompactLogin(bool arabic, TextDirection textDirection) {
    return Column(
      children: [
        _buildBrandHeader(arabic),
        const SizedBox(height: 26),
        _buildLoginCard(arabic, textDirection),
      ],
    );
  }

  Widget _buildBrandHeader(bool arabic) {
    return Column(
      children: [
        _buildMedicalLogo(size: 92),
        const SizedBox(height: 18),
        Text(
          'ARGUS',
          style: TextStyle(
            color: AppColors.text.withValues(alpha: 0.94),
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          arabic
              ? 'نظام مراقبة ذكي للعلامات الحيوية'
              : 'Smart physiological monitoring system',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.text.withValues(alpha: 0.52),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomePanel(bool arabic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMedicalLogo(size: 94),
        const SizedBox(height: 28),
        Text(
          arabic ? 'مراقبة. دقة. أمان.' : 'MONITOR. PRECISION. CARE.',
          style:  TextStyle(
            color: AppColors.text,
            fontSize: 34,
            height: 1.08,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          arabic
              ? 'منصة طبية حديثة لمتابعة العلامات الحيوية والبيانات الفسيولوجية في الوقت الحقيقي.'
              : 'A modern medical platform for real-time monitoring of vital signs and physiological data.',
          style: TextStyle(
            color: AppColors.text.withValues(alpha: 0.60),
            fontSize: 15,
            height: 1.7,
          ),
        ),
        const SizedBox(height: 30),
        _buildFeatureChip(
          Icons.favorite_rounded,
          arabic ? 'Real-time Vital Signs' : 'Real-time Vital Signs',
        ),
        const SizedBox(height: 12),
        _buildFeatureChip(
          Icons.monitor_heart_rounded,
          arabic ? 'ECG & Patient Monitoring' : 'ECG & Patient Monitoring',
        ),
        const SizedBox(height: 12),
        _buildFeatureChip(
          Icons.water_drop_rounded,
          arabic ? 'Smart Bladder Monitoring' : 'Smart Bladder Monitoring',
        ),
      ],
    );
  }

  Widget _buildFeatureChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFF54A9FF).withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF38E08F), size: 20),
          const SizedBox(width: 11),
          Text(
            text,
            style:  TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalLogo({double size = 80}) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final glow = 0.18 + (_pulseController.value * 0.16);

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.card,
            border: Border.all(
              color: const Color(0xFF54A9FF).withValues(alpha: 0.38),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF54A9FF).withValues(alpha: glow),
                blurRadius: 28,
                spreadRadius: 2,
              ),
            ],
          ),
          // ARGUS: the all-seeing eye.
          child: Center(
            child: CustomPaint(
              size: Size(size * 0.58, size * 0.36),
              painter: ArgusEyePainter(pulse: _pulseController.value),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoginCard(bool arabic, TextDirection textDirection) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.91),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFF54A9FF).withValues(alpha: 0.16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF54A9FF).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.lock_open_rounded,
                    color: Color(0xFF54A9FF),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        arabic ? 'مرحباً بعودتك' : 'Welcome back',
                        style:  TextStyle(
                          color: AppColors.text,
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        arabic
                            ? 'سجّل الدخول للوصول إلى لوحة المراقبة'
                            : 'Sign in to access your monitoring dashboard',
                        style: TextStyle(
                          color: AppColors.text.withValues(alpha: 0.48),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            TextFormField(
              controller: _emailController,
              textDirection: textDirection,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.emailAddress,
              decoration: _fieldDecoration(
                label: arabic ? 'الإيميل' : 'Email',
                icon: Icons.email_outlined,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return arabic
                      ? 'من فضلك أدخل الإيميل'
                      : 'Please enter your email';
                }
                return null;
              },
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              textDirection: textDirection,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _login(),
              decoration: _fieldDecoration(
                label: arabic ? 'كلمة المرور' : 'Password',
                icon: Icons.lock_outline_rounded,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return arabic
                      ? 'من فضلك أدخل كلمة المرور'
                      : 'Please enter your password';
                }
                return null;
              },
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: _signingIn ? null : _forgotPassword,
                child: Text(
                  arabic ? 'نسيت كلمة المرور؟' : 'Forgot password?',
                  style: const TextStyle(color: Color(0xFF54A9FF)),
                ),
              ),
            ),
            if (_authError != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE65F72).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFE65F72).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFFE65F72),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorText(_authError!, arabic),
                        style: const TextStyle(
                          color: Color(0xFFE65F72),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            AnimatedActionButton(
              onPressed: _signingIn ? null : _login,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 17),
                backgroundColor: const Color(0xFF54A9FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _signingIn
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          arabic ? 'دخول إلى النظام' : 'Enter Monitor',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          arabic
                              ? Icons.arrow_back_rounded
                              : Icons.arrow_forward_rounded,
                          size: 20,
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _signingIn ? null : _google,
              icon: const Text(
                'G',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF54A9FF),
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                foregroundColor: AppColors.text,
                side: BorderSide(color: AppColors.text.withValues(alpha: 0.25)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              label: Text(
                arabic ? 'المتابعة بحساب جوجل' : 'Continue with Google',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: _signingIn
                  ? null
                  : () => Navigator.push(context, appRoute<void>(const SignupPage())),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                foregroundColor: const Color(0xFF38E08F),
                side: BorderSide(
                  color: const Color(0xFF38E08F).withValues(alpha: 0.5),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                arabic ? 'إنشاء حساب جديد' : 'Create new account',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF38E08F),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  arabic ? 'النظام جاهز للعمل' : 'System ready for operation',
                  style: TextStyle(
                    color: AppColors.text.withValues(alpha: 0.42),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageButton extends StatelessWidget {
  final bool arabic;
  final VoidCallback onTap;

  const _LanguageButton({required this.arabic, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.card.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: const Color(0xFF54A9FF).withValues(alpha: 0.20),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.language_rounded,
                color: Color(0xFF54A9FF),
                size: 20,
              ),
              const SizedBox(width: 7),
              Text(
                arabic ? 'EN' : 'ع',
                style:  TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginBackgroundPainter extends CustomPainter {
  final Animation<double> pulse;

  _LoginBackgroundPainter({required this.pulse}) : super(repaint: pulse);

  @override
  void paint(Canvas canvas, Size size) {
    final blue = const Color(0xFF54A9FF);
    final green = const Color(0xFF38E08F);

    final gradientPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [blue.withValues(alpha: 0.12), Colors.transparent],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.12, size.height * 0.20),
              radius: size.width * 0.55,
            ),
          );
    canvas.drawCircle(
      Offset(size.width * 0.12, size.height * 0.20),
      size.width * 0.55,
      gradientPaint,
    );

    final secondGradient = Paint()
      ..shader =
          RadialGradient(
            colors: [green.withValues(alpha: 0.055), Colors.transparent],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.92, size.height * 0.84),
              radius: size.width * 0.48,
            ),
          );
    canvas.drawCircle(
      Offset(size.width * 0.92, size.height * 0.84),
      size.width * 0.48,
      secondGradient,
    );

    final gridPaint = Paint()
      ..color = AppColors.text.withValues(alpha: 0.018)
      ..strokeWidth = 1;

    const grid = 42.0;
    for (double x = 0; x <= size.width; x += grid) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += grid) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final linePaint = Paint()
      ..color = blue.withValues(alpha: 0.11)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    final path = Path();
    final centerY = size.height * 0.74;
    final amplitude = 14 + pulse.value * 4;

    for (double x = 0; x <= size.width; x += 5) {
      final normalized = x / size.width;
      final y =
          centerY +
          sin(normalized * pi * 10) * amplitude * 0.10 +
          sin(normalized * pi * 2.4) * amplitude * 0.18;

      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _LoginBackgroundPainter oldDelegate) => true;
}
