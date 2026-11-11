import 'package:flutter/material.dart';

class AnimatedActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final ButtonStyle? style;
  final Widget child;

  const AnimatedActionButton({
    super.key,
    required this.onPressed,
    this.style,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: 1.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: ElevatedButton(onPressed: onPressed, style: style, child: child),
    );
  }
}
