import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/colors.dart';
import '../utils/haptics.dart';

class SparkIconButton extends ConsumerWidget {
  const SparkIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 24,
    this.iconColor,
    this.backgroundColor,
    this.borderColor,
    this.padding = 12,
    this.isCircular = false,
    this.child,
    this.haptic = HapticLevel.light,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final Color? iconColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final double padding;
  final bool isCircular;
  final Widget? child;
  final HapticLevel haptic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.sparkColors;
    final radius = BorderRadius.circular(isCircular ? 999 : 14);
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.transparent,
        borderRadius: isCircular ? null : radius,
        shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: isCircular
              ? const CircleBorder()
              : RoundedRectangleBorder(borderRadius: radius),
          onTap: () {
            triggerHaptic(ref, haptic);
            onPressed();
          },
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: child ??
                Icon(
                  icon,
                  size: size,
                  color: iconColor ?? colors.textPrimary,
                ),
          ),
        ),
      ),
    );
  }
}
