import 'package:flutter/material.dart';

import '../theme/colors.dart';

class SparkIconButton extends StatelessWidget {
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
  });

  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final Color? iconColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final double padding;
  final bool isCircular;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(isCircular ? 999 : 14);
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.transparent,
        borderRadius: isCircular ? null : radius,
        shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
        border: borderColor == null
            ? null
            : Border.all(color: borderColor ?? AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: isCircular
              ? const CircleBorder()
              : RoundedRectangleBorder(borderRadius: radius),
          onTap: onPressed,
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Icon(
              icon,
              size: size,
              color: iconColor ?? AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
