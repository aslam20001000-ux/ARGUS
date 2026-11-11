import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/page_route.dart';
import '../../core/widgets/argus_eye.dart';
import '../home/feature_selection_page.dart';
import 'login_page.dart';
import 'session.dart';

/// Opening screen: the ARGUS eye and name. When someone is already signed in
/// it loads their data in the meantime, then opens Home (or the login page).
class SplashPage extends StatefulWidget {
  final bool signedIn;
  const SplashPage({super.key, required this.signedIn});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _go();
  }

  Future<void> _go() async {
    await Future.wait<void>([
      Future<void>.delayed(const Duration(milliseconds: 2000)),
      if (widget.signedIn) startSession(),
    ]);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      appRoute<void>(
        widget.signedIn ? const FeatureSelectionPage() : const LoginPage(),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.card,
                      border: Border.all(
                        color: const Color(0xFF54A9FF).withValues(alpha: 0.4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF54A9FF,
                          ).withValues(alpha: 0.12 + 0.2 * _controller.value),
                          blurRadius: 36,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: Center(
                      child: CustomPaint(
                        size: const Size(70, 44),
                        painter: ArgusEyePainter(pulse: _controller.value),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  'ARGUS',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Smart patient monitoring',
                  style: TextStyle(
                    color: AppColors.text.withValues(alpha: 0.5),
                    fontSize: 13,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
