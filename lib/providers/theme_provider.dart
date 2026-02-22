import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

enum ThemePreference { system, light, dark }

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
  ThemeController()
    : _settingsBox = Hive.box<dynamic>(_settingsBoxName),
      super(_readInitialPreference(Hive.box<dynamic>(_settingsBoxName)));

  static const String _settingsBoxName = 'app_settings';
  static const String _themeKey = 'theme_preference';

  final Box<dynamic> _settingsBox;

  static ThemePreference _readInitialPreference(Box<dynamic> box) {
    final raw = box.get(_themeKey);
    if (raw is! String) {
      return ThemePreference.system;
    }
    return ThemePreference.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => ThemePreference.system,
    );
  }

  void setTheme(ThemePreference preference) {
    state = preference;
    _settingsBox.put(_themeKey, preference.name);
  }
}

final themeProvider = StateNotifierProvider<ThemeController, ThemePreference>(
  (ref) => ThemeController(),
);
