/// settings_provider.dart
/// Central store for ALL user preferences in the app.
/// Every setting is persisted to SharedPreferences so it survives app restarts.
///
/// Settings covered:
///   - Typography  : font family, font size, line spacing, text alignment
///   - Reading     : hyphenation, reading mode, page turn method, volume button direction
///   - Auto-scroll : default speed, resume delay after manual scroll
///   - Sleep timer : enabled flag, duration in minutes
///   - Screen      : keep screen awake toggle
///   - Library     : list of scanned folder paths

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENUMS FOR STRONGLY-TYPED SETTINGS
// Using enums instead of raw strings/ints means the compiler catches typos.
// ─────────────────────────────────────────────────────────────────────────────

/// The font family used for book body text.
enum ReaderFontFamily {
  merriweather,   // Elegant serif — great for long reading
  lora,           // Warm serif — popular in e-readers
  openSans,       // Clean sans-serif — modern feel
  roboto,         // Android's default sans-serif
  openDyslexic,   // Designed to help readers with dyslexia
}

/// How text is aligned on the page.
enum TextAlignSetting { justified, left }

/// Line spacing between consecutive lines of text.
enum LineSpacing { compact, normal, relaxed }

/// How the user turns pages in Page Mode.
enum PageTurnMethod {
  tapOnly,          // Tap left/right areas of the screen
  volumeOnly,       // Use physical volume buttons
  both,             // Either method works
}

/// Direction mapping for volume buttons.
/// Normal  : Volume Up = previous page (or slower scroll)
/// Inverted: Volume Up = next page (or faster scroll)
enum VolumeButtonDirection { normal, inverted }

/// The two reading modes.
enum ReadingMode { page, scroll }

// ─────────────────────────────────────────────────────────────────────────────
// SHARED PREFERENCES KEYS
// All keys in one place — avoids typos when reading/writing settings.
// ─────────────────────────────────────────────────────────────────────────────
class _Keys {
  _Keys._();
  static const fontFamily           = 'font_family';
  static const fontSize             = 'font_size';
  static const lineSpacing          = 'line_spacing';
  static const textAlign            = 'text_align';
  static const hyphenation          = 'hyphenation';
  static const readingMode          = 'reading_mode';
  static const pageTurnMethod       = 'page_turn_method';
  static const volumeDirection      = 'volume_direction';
  static const autoScrollSpeed      = 'auto_scroll_speed';
  static const scrollResumeDelay    = 'scroll_resume_delay';
  static const sleepTimerEnabled    = 'sleep_timer_enabled';
  static const sleepTimerMinutes    = 'sleep_timer_minutes';
  static const keepScreenAwake      = 'keep_screen_awake';
  static const libraryFolders       = 'library_folders';
  static const exitConfirmShown     = 'exit_confirm_shown';
  static const highContrastText     = 'high_contrast_text';
}

// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS PROVIDER
// ─────────────────────────────────────────────────────────────────────────────

class SettingsProvider extends ChangeNotifier {

  // ── Typography defaults ───────────────────────────────────────────────────
  ReaderFontFamily _fontFamily    = ReaderFontFamily.merriweather;
  double           _fontSize      = 18.0;   // points
  LineSpacing      _lineSpacing   = LineSpacing.normal;
  TextAlignSetting _textAlign     = TextAlignSetting.justified;
  bool             _hyphenation   = true;

  // ── Reading behaviour defaults ────────────────────────────────────────────
  ReadingMode          _readingMode      = ReadingMode.page;
  PageTurnMethod       _pageTurnMethod   = PageTurnMethod.both;
  VolumeButtonDirection _volumeDirection = VolumeButtonDirection.normal;

  // ── Auto-scroll defaults ──────────────────────────────────────────────────
  // Speed is measured in pixels-per-second. 40 is a comfortable default.
  double _autoScrollSpeed    = 40.0;
  // After the user manually scrolls, auto-scroll resumes after this many seconds
  int    _scrollResumeDelay  = 3;

  // ── Sleep timer defaults ──────────────────────────────────────────────────
  bool _sleepTimerEnabled = false; // OFF by default — user must activate it
  int  _sleepTimerMinutes = 30;    // Default duration when the user enables it

  // ── Screen defaults ───────────────────────────────────────────────────────
  bool _keepScreenAwake = true;    // ON by default — no one wants the screen to lock while reading

  // ── Library ───────────────────────────────────────────────────────────────
  // List of folder paths the user has selected for scanning
  List<String> _libraryFolders = [];

  // ── Misc ──────────────────────────────────────────────────────────────────
  // Whether we've already shown the "first exit confirmation" dialog
  bool _exitConfirmShown = false;
  // High contrast text for accessibility
  bool _highContrastText = false;

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC GETTERS — read-only access for widgets
  // ─────────────────────────────────────────────────────────────────────────
  ReaderFontFamily      get fontFamily         => _fontFamily;
  double                get fontSize           => _fontSize;
  LineSpacing           get lineSpacing        => _lineSpacing;
  TextAlignSetting      get textAlign          => _textAlign;
  bool                  get hyphenation        => _hyphenation;
  ReadingMode           get readingMode        => _readingMode;
  PageTurnMethod        get pageTurnMethod     => _pageTurnMethod;
  VolumeButtonDirection get volumeDirection    => _volumeDirection;
  double                get autoScrollSpeed    => _autoScrollSpeed;
  int                   get scrollResumeDelay  => _scrollResumeDelay;
  bool                  get sleepTimerEnabled  => _sleepTimerEnabled;
  int                   get sleepTimerMinutes  => _sleepTimerMinutes;
  bool                  get keepScreenAwake    => _keepScreenAwake;
  List<String>          get libraryFolders     => List.unmodifiable(_libraryFolders);
  bool                  get exitConfirmShown   => _exitConfirmShown;
  bool                  get highContrastText   => _highContrastText;

  // ─────────────────────────────────────────────────────────────────────────
  // LOAD — called once at app startup
  // ─────────────────────────────────────────────────────────────────────────

  /// Reads all saved settings from SharedPreferences and updates the state.
  /// Call this in main() before the first frame is rendered.
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    _fontFamily   = ReaderFontFamily.values[prefs.getInt(_Keys.fontFamily)   ?? 0];
    _fontSize     = prefs.getDouble(_Keys.fontSize)     ?? 18.0;
    _lineSpacing  = LineSpacing.values[prefs.getInt(_Keys.lineSpacing)        ?? 1];
    _textAlign    = TextAlignSetting.values[prefs.getInt(_Keys.textAlign)     ?? 0];
    _hyphenation  = prefs.getBool(_Keys.hyphenation)    ?? true;

    _readingMode     = ReadingMode.values[prefs.getInt(_Keys.readingMode)     ?? 0];
    _pageTurnMethod  = PageTurnMethod.values[prefs.getInt(_Keys.pageTurnMethod) ?? 2];
    _volumeDirection = VolumeButtonDirection.values[prefs.getInt(_Keys.volumeDirection) ?? 0];

    _autoScrollSpeed   = prefs.getDouble(_Keys.autoScrollSpeed)  ?? 40.0;
    _scrollResumeDelay = prefs.getInt(_Keys.scrollResumeDelay)   ?? 3;

    _sleepTimerEnabled = prefs.getBool(_Keys.sleepTimerEnabled)   ?? false;
    _sleepTimerMinutes = prefs.getInt(_Keys.sleepTimerMinutes)    ?? 30;

    _keepScreenAwake   = prefs.getBool(_Keys.keepScreenAwake)     ?? true;

    // Folders are stored as a comma-separated string (SharedPreferences
    // does not natively support List<String> with special characters)
    final foldersRaw = prefs.getString(_Keys.libraryFolders) ?? '';
    _libraryFolders  = foldersRaw.isEmpty
        ? []
        : foldersRaw.split('||'); // '||' is our delimiter (unlikely to appear in paths)

    _exitConfirmShown = prefs.getBool(_Keys.exitConfirmShown) ?? false;
    _highContrastText = prefs.getBool(_Keys.highContrastText) ?? false;

    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SETTERS — each one saves to disk and notifies listening widgets
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> setFontFamily(ReaderFontFamily v) async {
    _fontFamily = v;
    await _save((p) => p.setInt(_Keys.fontFamily, v.index));
  }

  Future<void> setFontSize(double v) async {
    // Clamp to a sensible range to prevent unusable extremes
    _fontSize = v.clamp(10.0, 40.0);
    await _save((p) => p.setDouble(_Keys.fontSize, _fontSize));
  }

  Future<void> setLineSpacing(LineSpacing v) async {
    _lineSpacing = v;
    await _save((p) => p.setInt(_Keys.lineSpacing, v.index));
  }

  Future<void> setTextAlign(TextAlignSetting v) async {
    _textAlign = v;
    await _save((p) => p.setInt(_Keys.textAlign, v.index));
  }

  Future<void> setHyphenation(bool v) async {
    _hyphenation = v;
    await _save((p) => p.setBool(_Keys.hyphenation, v));
  }

  Future<void> setReadingMode(ReadingMode v) async {
    _readingMode = v;
    await _save((p) => p.setInt(_Keys.readingMode, v.index));
  }

  Future<void> setPageTurnMethod(PageTurnMethod v) async {
    _pageTurnMethod = v;
    await _save((p) => p.setInt(_Keys.pageTurnMethod, v.index));
  }

  Future<void> setVolumeDirection(VolumeButtonDirection v) async {
    _volumeDirection = v;
    await _save((p) => p.setInt(_Keys.volumeDirection, v.index));
  }

  Future<void> setAutoScrollSpeed(double v) async {
    // Speed range: 10 (very slow) → 200 (very fast), in pixels/second
    _autoScrollSpeed = v.clamp(10.0, 200.0);
    await _save((p) => p.setDouble(_Keys.autoScrollSpeed, _autoScrollSpeed));
  }

  Future<void> setScrollResumeDelay(int seconds) async {
    _scrollResumeDelay = seconds.clamp(1, 10);
    await _save((p) => p.setInt(_Keys.scrollResumeDelay, _scrollResumeDelay));
  }

  Future<void> setSleepTimerEnabled(bool v) async {
    _sleepTimerEnabled = v;
    await _save((p) => p.setBool(_Keys.sleepTimerEnabled, v));
  }

  Future<void> setSleepTimerMinutes(int v) async {
    _sleepTimerMinutes = v.clamp(1, 180);
    await _save((p) => p.setInt(_Keys.sleepTimerMinutes, _sleepTimerMinutes));
  }

  Future<void> setKeepScreenAwake(bool v) async {
    _keepScreenAwake = v;
    await _save((p) => p.setBool(_Keys.keepScreenAwake, v));
  }

  /// Adds a new folder path to the library if it's not already present.
  Future<void> addLibraryFolder(String path) async {
    if (_libraryFolders.contains(path)) return;
    _libraryFolders.add(path);
    await _saveLibraryFolders();
  }

  /// Removes a folder from the library scan list.
  Future<void> removeLibraryFolder(String path) async {
    _libraryFolders.remove(path);
    await _saveLibraryFolders();
  }

  Future<void> _saveLibraryFolders() async {
    await _save((p) => p.setString(_Keys.libraryFolders, _libraryFolders.join('||')));
  }

  /// Records that we've shown the first-exit confirmation dialog.
  /// After this, the dialog won't appear again (unless the user resets settings).
  Future<void> markExitConfirmShown() async {
    _exitConfirmShown = true;
    await _save((p) => p.setBool(_Keys.exitConfirmShown, true));
  }

  Future<void> setHighContrastText(bool v) async {
    _highContrastText = v;
    await _save((p) => p.setBool(_Keys.highContrastText, v));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // INTERNAL HELPER
  // ─────────────────────────────────────────────────────────────────────────

  /// Opens SharedPreferences, runs the provided write operation, then
  /// calls notifyListeners() so all listening widgets rebuild.
  Future<void> _save(Future<bool> Function(SharedPreferences) write) async {
    final prefs = await SharedPreferences.getInstance();
    await write(prefs);
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CONVENIENCE HELPERS used by the reader screen
  // ─────────────────────────────────────────────────────────────────────────

  /// Converts the font family enum to the string name used by GoogleFonts
  String get fontFamilyName {
    switch (_fontFamily) {
      case ReaderFontFamily.merriweather:  return 'Merriweather';
      case ReaderFontFamily.lora:          return 'Lora';
      case ReaderFontFamily.openSans:      return 'Open Sans';
      case ReaderFontFamily.roboto:        return 'Roboto';
      case ReaderFontFamily.openDyslexic:  return 'OpenDyslexic';
    }
  }

  /// Converts the LineSpacing enum to an actual line-height multiplier
  double get lineHeightMultiplier {
    switch (_lineSpacing) {
      case LineSpacing.compact:  return 1.3;
      case LineSpacing.normal:   return 1.6;
      case LineSpacing.relaxed:  return 2.0;
    }
  }

  /// Converts the TextAlignSetting enum to Flutter's TextAlign
  TextAlign get flutterTextAlign {
    switch (_textAlign) {
      case TextAlignSetting.justified: return TextAlign.justify;
      case TextAlignSetting.left:      return TextAlign.left;
    }
  }
}
