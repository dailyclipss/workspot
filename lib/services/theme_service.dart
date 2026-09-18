import 'package:flutter/material.dart';

class ThemeService extends ValueNotifier<ThemeMode> {
  ThemeService() : super(ThemeMode.light);

  bool get isDarkMode => value == ThemeMode.dark;

  void toggleTheme() {
    value = isDarkMode ? ThemeMode.light : ThemeMode.dark;
  }
}

final themeService = ThemeService();