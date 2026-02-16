import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Define the provider
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  // Initialize with system preference by default
  ThemeNotifier() : super(ThemeMode.dark) {
    _loadTheme();
  }

  static const String _themeKey = 'theme_mode';

  // Toggle between light and dark
  void toggleTheme() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    _saveTheme();
  }

  // Set specific mode
  void setTheme(ThemeMode mode) {
    state = mode;
    _saveTheme();
  }

  // Persist preference
  Future<void> _saveTheme() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, state.toString());
  }

  // Load persisted preference
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_themeKey);
    
    if (savedTheme != null) {
      if (savedTheme == ThemeMode.light.toString()) {
        state = ThemeMode.light;
      } else if (savedTheme == ThemeMode.dark.toString()) {
        state = ThemeMode.dark;
      } else {
        state = ThemeMode.system;
      }
    }
  }
}
