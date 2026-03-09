/// app_theme.dart
/// Defines all three visual themes for the eBook Reader:
///   - Light  : classic white background, dark text
///   - Dark   : dark background, light text (easy on the eyes at night)
///   - Sepia  : warm yellowish background, reduced blue light (best for long reading)
///
/// Each theme is a complete Flutter [ThemeData] object, meaning every widget
/// in the app automatically picks up the correct colors without any extra work.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// COLOUR PALETTE CONSTANTS
// Defining colours as constants here makes it easy to tweak the look of the
// app in one place without hunting through the code.
// ─────────────────────────────────────────────────────────────────────────────

class AppColors {
  // Prevent instantiation — this class is only for holding constants
  AppColors._();

  // ── Light theme colours ──────────────────────────────────────────────────
  static const Color lightBackground   = Color(0xFFFFFFFF);
  static const Color lightSurface      = Color(0xFFF5F5F5);
  static const Color lightText         = Color(0xFF1A1A1A);
  static const Color lightTextSecond   = Color(0xFF555555);
  static const Color lightStatusBar    = Color(0xFFE8E8E8);

  // ── Dark theme colours ───────────────────────────────────────────────────
  static const Color darkBackground    = Color(0xFF121212);
  static const Color darkSurface       = Color(0xFF1E1E1E);
  static const Color darkText          = Color(0xFFE8E8E8);
  static const Color darkTextSecond    = Color(0xFFAAAAAA);
  static const Color darkStatusBar     = Color(0xFF2A2A2A);

  // ── Sepia theme colours ──────────────────────────────────────────────────
  // Sepia mimics the warm tone of aged paper — much easier on the eyes
  // during long reading sessions or in low-light environments
  static const Color sepiaBackground   = Color(0xFFF4ECD8);
  static const Color sepiaSurface      = Color(0xFFEDE0C4);
  static const Color sepiaText         = Color(0xFF3B2F1E);
  static const Color sepiaTextSecond   = Color(0xFF6B5744);
  static const Color sepiaStatusBar    = Color(0xFFE5D5B5);

  // ── Accent colour — used across all themes for buttons, highlights ───────
  static const Color accent            = Color(0xFF5B7FA6); // calm blue
  static const Color accentDark        = Color(0xFF7BA7D4); // slightly lighter for dark bg
}

// ─────────────────────────────────────────────────────────────────────────────
// THEME ENUM
// A simple enum to identify which theme is currently active.
// Stored in SharedPreferences so the choice survives app restarts.
// ─────────────────────────────────────────────────────────────────────────────

/// The three visual themes available in the app.
/// [system] means "follow the phone's light/dark setting automatically".
enum AppThemeMode { system, light, dark, sepia }

// ─────────────────────────────────────────────────────────────────────────────
// APPTHEME CLASS
// A helper class with static methods that return a complete ThemeData for each
// visual mode. We also expose reading-specific colours (background, text)
// separately because the EPUB/PDF renderer needs those individually.
// ─────────────────────────────────────────────────────────────────────────────

class AppTheme {
  AppTheme._();

  // ── Base text theme ───────────────────────────────────────────────────────
  // We start with Merriweather (a serif font designed for on-screen reading)
  // as the default. The user can change this in Settings.
  static TextTheme _buildTextTheme(Color primaryColor, Color secondaryColor) {
    return GoogleFonts.merriweatherTextTheme(
      TextTheme(
        // bodyLarge / bodyMedium are used for the actual book content
        bodyLarge:   TextStyle(color: primaryColor, fontSize: 18, height: 1.7),
        bodyMedium:  TextStyle(color: primaryColor, fontSize: 16, height: 1.6),
        // titleLarge is used for chapter titles and screen headings
        titleLarge:  TextStyle(color: primaryColor, fontSize: 22, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: primaryColor, fontSize: 18, fontWeight: FontWeight.w600),
        // labelSmall is used for the bottom status bar text (time, page, battery)
        labelSmall:  TextStyle(color: secondaryColor, fontSize: 12),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LIGHT THEME
  // ─────────────────────────────────────────────────────────────────────────
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary:    AppColors.accent,
      surface:    AppColors.lightSurface,
      onSurface:  AppColors.lightText,
    ),
    scaffoldBackgroundColor: AppColors.lightBackground,
    textTheme: _buildTextTheme(AppColors.lightText, AppColors.lightTextSecond),
    appBarTheme: const AppBarTheme(
      backgroundColor:  AppColors.lightBackground,
      foregroundColor:  AppColors.lightText,
      elevation: 0,
      centerTitle: true,
    ),
    iconTheme: const IconThemeData(color: AppColors.lightText),
    dividerColor: AppColors.lightStatusBar,
    extensions: const [
      // We attach our custom reading colours as a ThemeExtension so any widget
      // can access them via Theme.of(context).extension<ReadingTheme>()
      ReadingTheme(
        pageBackground: AppColors.lightBackground,
        pageText:       AppColors.lightText,
        statusBarBg:    AppColors.lightStatusBar,
        statusBarText:  AppColors.lightTextSecond,
      ),
    ],
  );

  // ─────────────────────────────────────────────────────────────────────────
  // DARK THEME
  // ─────────────────────────────────────────────────────────────────────────
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary:    AppColors.accentDark,
      surface:    AppColors.darkSurface,
      onSurface:  AppColors.darkText,
    ),
    scaffoldBackgroundColor: AppColors.darkBackground,
    textTheme: _buildTextTheme(AppColors.darkText, AppColors.darkTextSecond),
    appBarTheme: const AppBarTheme(
      backgroundColor:  AppColors.darkBackground,
      foregroundColor:  AppColors.darkText,
      elevation: 0,
      centerTitle: true,
    ),
    iconTheme: const IconThemeData(color: AppColors.darkText),
    dividerColor: AppColors.darkStatusBar,
    extensions: const [
      ReadingTheme(
        pageBackground: AppColors.darkBackground,
        pageText:       AppColors.darkText,
        statusBarBg:    AppColors.darkStatusBar,
        statusBarText:  AppColors.darkTextSecond,
      ),
    ],
  );

  // ─────────────────────────────────────────────────────────────────────────
  // SEPIA THEME
  // ─────────────────────────────────────────────────────────────────────────
  static ThemeData get sepia => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light, // sepia is technically a light theme
    colorScheme: ColorScheme.light(
      primary:    AppColors.accent,
      surface:    AppColors.sepiaSurface,
      onSurface:  AppColors.sepiaText,
    ),
    scaffoldBackgroundColor: AppColors.sepiaBackground,
    textTheme: _buildTextTheme(AppColors.sepiaText, AppColors.sepiaTextSecond),
    appBarTheme: const AppBarTheme(
      backgroundColor:  AppColors.sepiaBackground,
      foregroundColor:  AppColors.sepiaText,
      elevation: 0,
      centerTitle: true,
    ),
    iconTheme: const IconThemeData(color: AppColors.sepiaText),
    dividerColor: AppColors.sepiaStatusBar,
    extensions: const [
      ReadingTheme(
        pageBackground: AppColors.sepiaBackground,
        pageText:       AppColors.sepiaText,
        statusBarBg:    AppColors.sepiaStatusBar,
        statusBarText:  AppColors.sepiaTextSecond,
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// READING THEME EXTENSION
// Flutter's ThemeData doesn't have fields for "page background" or "status bar
// text" — those are reading-app specific. ThemeExtension lets us bolt on our
// own custom colour slots so the reader screen can look up the right colour
// without a big if/else chain.
// ─────────────────────────────────────────────────────────────────────────────

/// Custom colour slots specifically for the reading experience.
/// Access these with: Theme.of(context).extension<ReadingTheme>()!
class ReadingTheme extends ThemeExtension<ReadingTheme> {
  /// The background colour of the book page itself
  final Color pageBackground;

  /// The colour of the body text on the page
  final Color pageText;

  /// The background colour of the bottom status bar (time / page / battery)
  final Color statusBarBg;

  /// The text colour inside the bottom status bar
  final Color statusBarText;

  const ReadingTheme({
    required this.pageBackground,
    required this.pageText,
    required this.statusBarBg,
    required this.statusBarText,
  });

  /// copyWith allows Flutter to smoothly animate between themes by
  /// interpolating (blending) the colours during the transition animation
  @override
  ReadingTheme copyWith({
    Color? pageBackground,
    Color? pageText,
    Color? statusBarBg,
    Color? statusBarText,
  }) {
    return ReadingTheme(
      pageBackground: pageBackground ?? this.pageBackground,
      pageText:       pageText       ?? this.pageText,
      statusBarBg:    statusBarBg    ?? this.statusBarBg,
      statusBarText:  statusBarText  ?? this.statusBarText,
    );
  }

  /// lerp = "linear interpolation" — Flutter calls this during theme
  /// transition animations to calculate the in-between colour values
  @override
  ReadingTheme lerp(ReadingTheme? other, double t) {
    if (other == null) return this;
    return ReadingTheme(
      pageBackground: Color.lerp(pageBackground, other.pageBackground, t)!,
      pageText:       Color.lerp(pageText,       other.pageText,       t)!,
      statusBarBg:    Color.lerp(statusBarBg,    other.statusBarBg,    t)!,
      statusBarText:  Color.lerp(statusBarText,  other.statusBarText,  t)!,
    );
  }
}
