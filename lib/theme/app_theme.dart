import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';
import 'text_styles.dart';

class AppTheme {
  static ThemeData light() {
    final base = ThemeData.light();
    final textTheme = GoogleFonts.dmSansTextTheme(base.textTheme).copyWith(
      titleLarge: AppTextStyles.title,
      titleMedium: AppTextStyles.section,
      bodyLarge: AppTextStyles.primary,
      bodyMedium: AppTextStyles.primary,
      bodySmall: AppTextStyles.secondary,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      cardColor: AppColors.bgCard,
      dividerColor: AppColors.border,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.flame,
        secondary: AppColors.red,
        surface: AppColors.bgCard,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: AppTextStyles.title,
      ),
    );
  }
}
