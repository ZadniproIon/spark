import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ThemePreference {
  system,
  light,
  dark,
}

extension ThemePreferenceX on ThemePreference {
  ThemeMode get themeMode {
    switch (this) {
      case ThemePreference.light:
        return ThemeMode.light;
      case ThemePreference.dark:
        return ThemeMode.dark;
      case ThemePreference.system:
        return ThemeMode.system;
    }
  }

  String get label {
    switch (this) {
      case ThemePreference.light:
        return 'Light';
      case ThemePreference.dark:
        return 'Dark';
      case ThemePreference.system:
        return 'Device default';
    }
  }
}

class ThemeController extends StateNotifier<ThemePreference> {
  ThemeController() : super(ThemePreference.system);

  void setTheme(ThemePreference preference) {
    state = preference;
  }
}

final themeProvider = StateNotifierProvider<ThemeController, ThemePreference>(
  (ref) => ThemeController(),
);
