import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';
import 'text_styles.dart';

class AppTheme {
  static ThemeData light() {
    return _buildTheme(ThemeData.light(), SparkColors.light);
  }

  static ThemeData dark() {
    return _buildTheme(ThemeData.dark(), SparkColors.dark);
  }

  static ThemeData _buildTheme(ThemeData base, SparkColors colors) {
    final textTheme = GoogleFonts.dmSansTextTheme(base.textTheme).copyWith(
      titleLarge: AppTextStyles.title.copyWith(color: colors.textPrimary),
      titleMedium: AppTextStyles.section.copyWith(color: colors.textPrimary),
      bodyLarge: AppTextStyles.primary.copyWith(color: colors.textPrimary),
      bodyMedium: AppTextStyles.primary.copyWith(color: colors.textPrimary),
      bodySmall: AppTextStyles.secondary.copyWith(color: colors.textSecondary),
    );

    return base.copyWith(
      scaffoldBackgroundColor: colors.bg,
      cardColor: colors.bgCard,
      dividerColor: colors.border,
      colorScheme: base.colorScheme.copyWith(
        primary: colors.flame,
        secondary: colors.red,
        surface: colors.bgCard,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: colors.textPrimary,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
        titleTextStyle: AppTextStyles.title.copyWith(color: colors.textPrimary),
      ),
      extensions: [colors],
    );
  }
}
