/// theme_provider.dart
/// Manages which visual theme is currently active and persists the
/// user's choice across app restarts using SharedPreferences.
///
/// This is a [ChangeNotifier] — any widget that "listens" to this provider
/// will automatically rebuild whenever the theme changes.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

/// The key used to store the theme choice in SharedPreferences.
/// SharedPreferences is like a tiny key-value dictionary saved on the device.
const String _kThemePrefKey = 'app_theme_mode';

class ThemeProvider extends ChangeNotifier {
  // ── Internal state ────────────────────────────────────────────────────────
  // Starts with "system" (follow phone setting) until we load the saved choice
  AppThemeMode _themeMode = AppThemeMode.system;

  // ── Public getter ─────────────────────────────────────────────────────────
  /// The currently active theme mode (system / light / dark / sepia)
  AppThemeMode get themeMode => _themeMode;

  // ─────────────────────────────────────────────────────────────────────────
  // INITIALISATION
  // Called once at app startup to load the previously saved theme preference
  // ─────────────────────────────────────────────────────────────────────────

  /// Loads the saved theme from local storage.
  /// Call this in main() before the app renders its first frame.
  Future<void> loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    // Read the saved integer index; default to 0 (system) if nothing is saved
    final savedIndex = prefs.getInt(_kThemePrefKey) ?? 0;

    // Convert the saved integer back to the enum value
    // AppThemeMode.values is the list [system, light, dark, sepia]
    _themeMode = AppThemeMode.values[savedIndex];

    // Notify all listening widgets to rebuild with the loaded theme
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CHANGING THE THEME
  // ─────────────────────────────────────────────────────────────────────────

  /// Changes the active theme and saves the choice for next launch.
  /// [mode] — one of: AppThemeMode.system / light / dark / sepia
  Future<void> setTheme(AppThemeMode mode) async {
    // Do nothing if the user picked the same theme that's already active
    if (_themeMode == mode) return;

    _themeMode = mode;

    // Save the integer index of the enum value to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kThemePrefKey, mode.index);

    // Tell all listening widgets to rebuild with the new theme
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RESOLVING THE THEME DATA
  // MaterialApp needs a ThemeData object. This method returns the correct one
  // based on the current mode and the phone's system brightness.
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns the correct [ThemeData] for light mode based on current setting.
  /// MaterialApp's [theme] parameter uses this.
  ThemeData get lightTheme => AppTheme.light;

  /// Returns the correct [ThemeData] for dark mode based on current setting.
  /// MaterialApp's [darkTheme] parameter uses this.
  ThemeData get darkTheme => AppTheme.dark;

  /// Tells MaterialApp which mode to use:
  ///   - ThemeMode.system  → follow phone setting
  ///   - ThemeMode.light   → always light
  ///   - ThemeMode.dark    → always dark
  ///   - For sepia we force light mode here and handle the sepia colours
  ///     via the ReadingTheme extension inside the reader screen
  ThemeMode get materialThemeMode {
    switch (_themeMode) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.sepia:
        // Sepia is a custom variation of light mode
        return ThemeMode.light;
    }
  }

  /// Returns the complete ThemeData for the current mode, taking into account
  /// the system brightness when the mode is set to "system".
  /// [systemBrightness] is read from MediaQuery inside the widget tree.
  ThemeData resolveTheme(Brightness systemBrightness) {
    switch (_themeMode) {
      case AppThemeMode.system:
        // Follow the phone: if the phone is in dark mode, use our dark theme
        return systemBrightness == Brightness.dark
            ? AppTheme.dark
            : AppTheme.light;
      case AppThemeMode.light:
        return AppTheme.light;
      case AppThemeMode.dark:
        return AppTheme.dark;
      case AppThemeMode.sepia:
        return AppTheme.sepia;
    }
  }

  /// Convenient helper: returns true if the current effective theme is dark.
  /// Useful for deciding icon colours and overlay opacities.
  bool isDark(Brightness systemBrightness) {
    if (_themeMode == AppThemeMode.dark) return true;
    if (_themeMode == AppThemeMode.system) {
      return systemBrightness == Brightness.dark;
    }
    return false;
  }
}
