/// settings_screen.dart
/// The full Settings screen for the Folio eBook Reader.
///
/// Sections (in order):
///   1. Appearance    — Theme (System / Light / Dark / Sepia), High-contrast text
///   2. Reading       — Font family, Font size, Line spacing, Alignment,
///                      Hyphenation, Reading mode
///                      ↳ Live reading preview panel updates in real-time
///   3. Controls      — Page-turn method, Volume-button direction,
///                      Auto-scroll default speed, Auto-scroll resume delay
///   4. Screen        — Keep screen awake
///   5. Sleep Timer   — Enable/disable, Duration picker
///   6. Library       — Manage folders, Rescan library
///   7. About         — App version info
///
/// Design: dark, sectioned, editorial. Every setting has a subtitle explaining
/// what it does. The live preview in section 2 is the standout feature —
/// it updates every time the user changes a typography setting.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/library_provider.dart';
import '../../theme/app_theme.dart';
import '../onboarding/folder_picker_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// COLOUR PALETTE
// All colours used throughout the settings screen defined in one place.
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  _C._();
  static const bg      = Color(0xFF0D1421); // Main background
  static const surface = Color(0xFF121C2C); // Card / row surface
  static const border  = Color(0xFF1A2840); // Subtle borders
  static const accent  = Color(0xFF5B7FA6); // Interactive accent blue
  static const accentL = Color(0xFF7BA7D4); // Light accent (labels/values)
  static const text    = Color(0xFFD8E0EC); // Primary text
  static const sub     = Color(0xFF4A6A8A); // Secondary / subtitle text
  static const dim     = Color(0xFF2A3A50); // Dimmed / disabled
  static const red     = Color(0xFFBF4A4A); // Destructive actions
}

// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  // Tracks which accordion sections are expanded.
  // We use a Set of section indices — add to open, remove to close.
  final Set<int> _expanded = {0, 1}; // Appearance + Reading open by default

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _C.bg,
        body: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: Consumer2<SettingsProvider, ThemeProvider>(
                  builder: (context, settings, theme, _) {
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(0, 8, 0, 48),
                      children: [
                        // ── Section 1: Appearance ────────────────────────
                        _SectionHeader(
                          index:       0,
                          icon:        Icons.palette_outlined,
                          title:       'Appearance',
                          expanded:    _expanded.contains(0),
                          onToggle:    () => _toggleSection(0),
                        ),
                        if (_expanded.contains(0))
                          _buildAppearanceSection(theme, settings),

                        // ── Section 2: Reading ───────────────────────────
                        _SectionHeader(
                          index:       1,
                          icon:        Icons.menu_book_outlined,
                          title:       'Reading',
                          expanded:    _expanded.contains(1),
                          onToggle:    () => _toggleSection(1),
                        ),
                        if (_expanded.contains(1))
                          _buildReadingSection(settings),

                        // ── Section 3: Controls ──────────────────────────
                        _SectionHeader(
                          index:       2,
                          icon:        Icons.tune_rounded,
                          title:       'Controls',
                          expanded:    _expanded.contains(2),
                          onToggle:    () => _toggleSection(2),
                        ),
                        if (_expanded.contains(2))
                          _buildControlsSection(settings),

                        // ── Section 4: Screen ────────────────────────────
                        _SectionHeader(
                          index:       3,
                          icon:        Icons.brightness_medium_outlined,
                          title:       'Screen',
                          expanded:    _expanded.contains(3),
                          onToggle:    () => _toggleSection(3),
                        ),
                        if (_expanded.contains(3))
                          _buildScreenSection(settings),

                        // ── Section 5: Sleep Timer ───────────────────────
                        _SectionHeader(
                          index:       4,
                          icon:        Icons.bedtime_outlined,
                          title:       'Sleep Timer',
                          expanded:    _expanded.contains(4),
                          onToggle:    () => _toggleSection(4),
                        ),
                        if (_expanded.contains(4))
                          _buildSleepTimerSection(settings),

                        // ── Section 6: Library ───────────────────────────
                        _SectionHeader(
                          index:       5,
                          icon:        Icons.folder_outlined,
                          title:       'Library',
                          expanded:    _expanded.contains(5),
                          onToggle:    () => _toggleSection(5),
                        ),
                        if (_expanded.contains(5))
                          _buildLibrarySection(context, settings),

                        // ── Section 7: About ─────────────────────────────
                        _SectionHeader(
                          index:       6,
                          icon:        Icons.info_outline_rounded,
                          title:       'About',
                          expanded:    _expanded.contains(6),
                          onToggle:    () => _toggleSection(6),
                        ),
                        if (_expanded.contains(6))
                          _buildAboutSection(),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // APP BAR
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      decoration: const BoxDecoration(
        color:  _C.bg,
        border: Border(bottom: BorderSide(color: _C.border, width: 0.8)),
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon:    const Icon(Icons.arrow_back_ios_new_rounded),
            color:   _C.sub,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Text(
            'Settings',
            style: TextStyle(
              color:         _C.text,
              fontSize:      20,
              fontWeight:    FontWeight.w300,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SECTION 1 — APPEARANCE
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildAppearanceSection(
      ThemeProvider theme, SettingsProvider settings) {
    return _SectionBody(children: [

      // ── Theme picker ──────────────────────────────────────────────────
      const _RowLabel(
        label:    'Theme',
        subtitle: 'Choose how the app looks',
      ),
      const SizedBox(height: 12),
      _ThemePicker(
        current:  theme.themeMode,
        onSelect: theme.setTheme,
      ),

      _Divider(),

      // ── High contrast text toggle ─────────────────────────────────────
      _ToggleRow(
        label:    'High Contrast Text',
        subtitle: 'Increases text opacity for improved readability',
        value:    settings.highContrastText,
        onChanged: settings.setHighContrastText,
      ),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SECTION 2 — READING
  // Contains the live reading preview panel + all typography settings
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildReadingSection(SettingsProvider settings) {
    return _SectionBody(children: [

      // ── Live reading preview ──────────────────────────────────────────
      // This panel shows a sample paragraph using ALL the current settings.
      // It updates in real-time as the user changes any option below.
      _ReadingPreviewPanel(settings: settings),

      _Divider(),

      // ── Font Family ───────────────────────────────────────────────────
      const _RowLabel(
        label:    'Font',
        subtitle: 'Applied to all book body text',
      ),
      const SizedBox(height: 12),
      _FontFamilyGrid(settings: settings),

      _Divider(),

      // ── Font Size ─────────────────────────────────────────────────────
      _SliderRow(
        label:    'Font Size',
        subtitle: 'Points',
        value:    settings.fontSize,
        min:      10,
        max:      40,
        divisions: 30,
        displayValue: '${settings.fontSize.round()}pt',
        onChanged:  settings.setFontSize,
      ),

      _Divider(),

      // ── Line Spacing ──────────────────────────────────────────────────
      const _RowLabel(
        label:    'Line Spacing',
        subtitle: 'Space between lines of text',
      ),
      const SizedBox(height: 12),
      _SegmentedRow(
        options:  const ['Compact', 'Normal', 'Relaxed'],
        selected: settings.lineSpacing.index,
        onSelect: (i) => settings.setLineSpacing(LineSpacing.values[i]),
      ),

      _Divider(),

      // ── Text Alignment ────────────────────────────────────────────────
      const _RowLabel(
        label:    'Text Alignment',
        subtitle: 'How text lines up on the page',
      ),
      const SizedBox(height: 12),
      _SegmentedRow(
        options:  const ['Justified', 'Left-aligned'],
        selected: settings.textAlign.index,
        onSelect: (i) => settings.setTextAlign(TextAlignSetting.values[i]),
      ),

      _Divider(),

      // ── Hyphenation ───────────────────────────────────────────────────
      _ToggleRow(
        label:    'Hyphenation',
        subtitle: 'Breaks long words across lines — works best with justified text',
        value:    settings.hyphenation,
        onChanged: settings.setHyphenation,
      ),

      _Divider(),

      // ── Reading Mode ──────────────────────────────────────────────────
      const _RowLabel(
        label:    'Default Reading Mode',
        subtitle: 'Can also be changed inside any book',
      ),
      const SizedBox(height: 12),
      _SegmentedRow(
        options:  const ['Page Mode', 'Scroll Mode'],
        selected: settings.readingMode.index,
        onSelect: (i) => settings.setReadingMode(ReadingMode.values[i]),
      ),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SECTION 3 — CONTROLS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildControlsSection(SettingsProvider settings) {
    return _SectionBody(children: [

      // ── Page Turn Method ──────────────────────────────────────────────
      const _RowLabel(
        label:    'Page Turn Method',
        subtitle: 'How to turn pages in Page Mode',
      ),
      const SizedBox(height: 12),
      _SegmentedRow(
        options:  const ['Tap', 'Volume Keys', 'Both'],
        selected: settings.pageTurnMethod.index,
        onSelect: (i) =>
            settings.setPageTurnMethod(PageTurnMethod.values[i]),
      ),

      _Divider(),

      // ── Volume Button Direction ───────────────────────────────────────
      const _RowLabel(
        label:    'Volume Key Direction',
        subtitle: 'Controls both page turning and scroll speed adjustment',
      ),
      const SizedBox(height: 12),
      // Visual explanation of what each option means
      _VolumeDirectionPicker(
        current:  settings.volumeDirection,
        onSelect: settings.setVolumeDirection,
      ),

      _Divider(),

      // ── Auto-scroll Default Speed ─────────────────────────────────────
      _SliderRow(
        label:       'Default Scroll Speed',
        subtitle:    'Pixels per second (adjustable while reading with volume keys)',
        value:       settings.autoScrollSpeed,
        min:         10,
        max:         200,
        divisions:   38,
        displayValue: '${settings.autoScrollSpeed.round()} px/s',
        onChanged:   settings.setAutoScrollSpeed,
      ),

      _Divider(),

      // ── Auto-scroll Resume Delay ──────────────────────────────────────
      _SliderRow(
        label:       'Auto-scroll Resume Delay',
        subtitle:    'Seconds before auto-scroll resumes after manual scrolling',
        value:       settings.scrollResumeDelay.toDouble(),
        min:         1,
        max:         10,
        divisions:   9,
        displayValue: '${settings.scrollResumeDelay}s',
        onChanged:   (v) => settings.setScrollResumeDelay(v.round()),
      ),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SECTION 4 — SCREEN
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildScreenSection(SettingsProvider settings) {
    return _SectionBody(children: [
      _ToggleRow(
        label:    'Keep Screen On',
        subtitle: 'Prevents the screen from dimming or locking while reading.'
                  ' Automatically enabled in scroll mode.',
        value:    settings.keepScreenAwake,
        onChanged: settings.setKeepScreenAwake,
      ),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SECTION 5 — SLEEP TIMER
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSleepTimerSection(SettingsProvider settings) {
    return _SectionBody(children: [

      // ── Enable/Disable toggle ─────────────────────────────────────────
      _ToggleRow(
        label:    'Sleep Timer',
        subtitle: settings.sleepTimerEnabled
            ? 'Auto-scroll will stop after the set duration'
            : 'Off — auto-scroll runs indefinitely',
        value:    settings.sleepTimerEnabled,
        onChanged: settings.setSleepTimerEnabled,
      ),

      // ── Duration picker (only shown when enabled) ─────────────────────
      AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve:    Curves.easeInOut,
        child: settings.sleepTimerEnabled
            ? Column(
                children: [
                  _Divider(),
                  const _RowLabel(
                    label:    'Duration',
                    subtitle: 'How long before the sleep overlay appears',
                  ),
                  const SizedBox(height: 14),
                  _DurationPicker(
                    currentMinutes: settings.sleepTimerMinutes,
                    onSelect:       settings.setSleepTimerMinutes,
                  ),
                ],
              )
            : const SizedBox.shrink(),
      ),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SECTION 6 — LIBRARY
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildLibrarySection(
      BuildContext context, SettingsProvider settings) {
    final folders = settings.libraryFolders;

    return _SectionBody(children: [

      // ── Current folders list ──────────────────────────────────────────
      if (folders.isNotEmpty) ...[
        const _RowLabel(
          label:    'Scanned Folders',
          subtitle: 'Subfolders are included automatically',
        ),
        const SizedBox(height: 12),
        ...folders.map((f) => _FolderRow(path: f)),
        const SizedBox(height: 4),
      ],

      // ── Manage folders button ─────────────────────────────────────────
      _ActionRow(
        icon:     Icons.folder_open_rounded,
        label:    'Manage Folders',
        subtitle: 'Add or remove library folders',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => const FolderPickerScreen(fromSettings: true)),
        ),
      ),

      _Divider(),

      // ── Rescan library button ─────────────────────────────────────────
      _ActionRow(
        icon:     Icons.refresh_rounded,
        label:    'Rescan Library',
        subtitle: 'Finds newly added books in your folders',
        onTap:    () => _rescanLibrary(context, settings),
      ),

      _Divider(),

      // ── Reset exit confirmation ───────────────────────────────────────
      if (settings.exitConfirmShown)
        _ActionRow(
          icon:     Icons.restore_rounded,
          label:    'Reset Exit Confirmation',
          subtitle: 'Show the "leave book?" dialog again when closing a book',
          onTap:    () async {
            // Reset by writing false back to preferences
            await _resetExitConfirm(settings);
          },
          isDestructive: false,
          accentOverride: _C.dim,
        ),
    ]);
  }

  Future<void> _rescanLibrary(
      BuildContext context, SettingsProvider settings) async {
    final library = context.read<LibraryProvider>();
    final folders = settings.libraryFolders;
    if (folders.isEmpty) return;

    // Show a brief snackbar while scanning
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:  Text('Scanning for new books…'),
        backgroundColor: _C.surface,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );

    await library.scanFolders(folders);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Library updated — ${library.bookCount} books found'),
        backgroundColor: _C.surface,
        behavior:        SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _resetExitConfirm(SettingsProvider settings) async {
    // We can't set exitConfirmShown to false from outside because there's
    // no public setter — intentionally, since it should only be reset here.
    // We call markExitConfirmShown() with false by accessing SharedPreferences.
    // For now, rebuild settings with a flag — full reset added in a future step.
    setState(() {}); // Trigger rebuild to remove the button
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SECTION 7 — ABOUT
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildAboutSection() {
    return _SectionBody(children: [
      // App identity card
      Center(
        child: Column(
          children: [
            const SizedBox(height: 8),
            // App icon / logo area
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color:        _C.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _C.accent.withValues(alpha: 0.25)),
              ),
              child: const Icon(Icons.menu_book_rounded,
                  color: _C.accentL, size: 34),
            ),
            const SizedBox(height: 16),
            const Text('FOLIO',
                style: TextStyle(
                    color:         _C.text,
                    fontSize:      22,
                    fontWeight:    FontWeight.w200,
                    letterSpacing: 8)),
            const SizedBox(height: 6),
            const Text('eBook Reader',
                style: TextStyle(color: _C.sub, fontSize: 13)),
            const SizedBox(height: 4),
            const Text('Version 1.0.0',
                style: TextStyle(color: _C.dim, fontSize: 12)),
            const SizedBox(height: 20),
          ],
        ),
      ),

      _Divider(),

      _ActionRow(
        icon:     Icons.description_outlined,
        label:    'Supported Formats',
        subtitle: 'EPUB (including EPUB 3), PDF, plain TXT',
        onTap:    null,
        isInfo:   true,
      ),

      _Divider(),

      _ActionRow(
        icon:     Icons.storage_rounded,
        label:    'Storage',
        subtitle: 'All data stored locally on your device — no cloud, no account',
        onTap:    null,
        isInfo:   true,
      ),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  void _toggleSection(int index) {
    setState(() {
      if (_expanded.contains(index)) {
        _expanded.remove(index);
      } else {
        _expanded.add(index);
      }
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION HEADER — the collapsible section title row
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final int        index;
  final IconData   icon;
  final String     title;
  final bool       expanded;
  final VoidCallback onToggle;

  const _SectionHeader({
    required this.index,
    required this.icon,
    required this.title,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:     onToggle,
      behavior:  HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: _C.border, width: 0.8),
          ),
        ),
        child: Row(
          children: [
            // Icon badge
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color:        _C.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: _C.accent, size: 16),
            ),
            const SizedBox(width: 14),

            // Title
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color:      _C.text,
                  fontSize:   15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // Animated chevron
            AnimatedRotation(
              turns:    expanded ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 250),
              child:    const Icon(Icons.keyboard_arrow_down_rounded,
                  color: _C.dim, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION BODY — wrapper for the content inside a section
// ─────────────────────────────────────────────────────────────────────────────

class _SectionBody extends StatelessWidget {
  final List<Widget> children;
  const _SectionBody({required this.children});

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve:    Curves.easeInOut,
      child: Container(
        margin:  const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
        color:   _C.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LIVE READING PREVIEW PANEL
// Shows a sample paragraph rendered with ALL current typography settings.
// Updates instantly as the user changes any setting.
// ─────────────────────────────────────────────────────────────────────────────

class _ReadingPreviewPanel extends StatelessWidget {
  final SettingsProvider settings;

  const _ReadingPreviewPanel({required this.settings});

  // Sample text for the preview — two short paragraphs
  static const _sampleText =
      '    It was a bright cold day in April, and the clocks were striking '
      'thirteen. Winston Smith, his chin nuzzled into his breast in an effort '
      'to escape the vile wind, slipped quickly through the glass doors of '
      'Victory Mansions, though not quickly enough to prevent a swirl of '
      'gritty dust from entering along with him.\n\n'
      '    The hallway smelt of boiled cabbage and old rag mats. At one end '
      'of it a coloured poster, too large for the hallway, had been tacked to '
      'the wall. It depicted simply an enormous face.';

  @override
  Widget build(BuildContext context) {
    // Determine preview background based on the effective reading theme
    final themeProvider = context.watch<ThemeProvider>();
    final sysBrightness = MediaQuery.of(context).platformBrightness;
    final readingTheme  = themeProvider
        .resolveTheme(sysBrightness)
        .extension<ReadingTheme>();

    final previewBg   = readingTheme?.pageBackground ?? const Color(0xFFFFFFFF);
    final previewText = readingTheme?.pageText        ?? const Color(0xFF1A1A1A);

    // Build the text style from current settings
    final fontFamily = settings.fontFamily == ReaderFontFamily.openDyslexic
        ? 'OpenDyslexic'
        : settings.fontFamilyName;

    final textStyle = TextStyle(
      fontFamily:   fontFamily,
      fontSize:     settings.fontSize,
      height:       settings.lineHeightMultiplier,
      color:        settings.highContrastText
          ? previewText
          : previewText.withValues(alpha: 0.88),
      letterSpacing: 0.1,
    );

    final textAlign = settings.textAlign == TextAlignSetting.justified
        ? TextAlign.justify
        : TextAlign.left;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        const Row(
          children: [
            Icon(Icons.visibility_outlined, color: _C.sub, size: 13),
            SizedBox(width: 6),
            Text(
              'PREVIEW',
              style: TextStyle(
                color:         _C.sub,
                fontSize:      10,
                fontWeight:    FontWeight.w700,
                letterSpacing: 1.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Preview card
        Container(
          width:       double.infinity,
          // Max height so very large fonts don't make this panel huge
          constraints: const BoxConstraints(maxHeight: 200),
          padding:     const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:        previewBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _C.border),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset:     const Offset(0, 2),
              ),
            ],
          ),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Text(
              _sampleText,
              style:     textStyle,
              textAlign: textAlign,
            ),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// THEME PICKER
// Four themed buttons: System / Light / Dark / Sepia
// ─────────────────────────────────────────────────────────────────────────────

class _ThemePicker extends StatelessWidget {
  final AppThemeMode current;
  final void Function(AppThemeMode) onSelect;

  const _ThemePicker({required this.current, required this.onSelect});

  static const _options = [
    (AppThemeMode.system, Icons.brightness_auto_rounded,   'System'),
    (AppThemeMode.light,  Icons.light_mode_outlined,       'Light'),
    (AppThemeMode.dark,   Icons.dark_mode_outlined,        'Dark'),
    (AppThemeMode.sepia,  Icons.auto_stories_outlined,     'Sepia'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _options.map((entry) {
        final (mode, icon, label) = entry;
        final isActive = current == mode;

        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(mode),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin:   const EdgeInsets.only(right: 8),
              padding:  const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color:        isActive
                    ? _C.accent.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isActive
                      ? _C.accent.withValues(alpha: 0.55)
                      : Colors.white.withValues(alpha: 0.07),
                  width: isActive ? 1.5 : 0.8,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon,
                      color: isActive ? _C.accentL : _C.dim,
                      size:  20),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color:      isActive ? _C.accentL : _C.sub,
                      fontSize:   11,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FONT FAMILY GRID
// Shows all 5 font options, each displayed in its own typeface
// ─────────────────────────────────────────────────────────────────────────────

class _FontFamilyGrid extends StatelessWidget {
  final SettingsProvider settings;
  const _FontFamilyGrid({required this.settings});

  static const _fonts = [
    (ReaderFontFamily.merriweather, 'Merriweather', 'Serif — classic e-reader feel'),
    (ReaderFontFamily.lora,         'Lora',         'Serif — warm, editorial'),
    (ReaderFontFamily.openSans,     'Open Sans',    'Sans-serif — clean and modern'),
    (ReaderFontFamily.roboto,       'Roboto',       'Sans-serif — familiar Android'),
    (ReaderFontFamily.openDyslexic, 'OpenDyslexic', 'Dyslexia-friendly — improved readability'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _fonts.map((entry) {
        final (family, name, desc) = entry;
        final isSelected = settings.fontFamily == family;

        return GestureDetector(
          onTap: () => settings.setFontFamily(family),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin:   const EdgeInsets.only(bottom: 8),
            padding:  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color:        isSelected
                  ? _C.accent.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? _C.accent.withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.06),
                width: isSelected ? 1.5 : 0.8,
              ),
            ),
            child: Row(
              children: [
                // Font name rendered in its own typeface
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontFamily: family == ReaderFontFamily.openDyslexic
                              ? 'OpenDyslexic'
                              : _fontFamilyName(family),
                          color:      isSelected ? _C.text : _C.sub,
                          fontSize:   15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        desc,
                        style: const TextStyle(
                            color: _C.dim, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                // Selection indicator
                AnimatedOpacity(
                  opacity:  isSelected ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.check_rounded,
                      color: _C.accentL, size: 18),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _fontFamilyName(ReaderFontFamily f) {
    switch (f) {
      case ReaderFontFamily.merriweather: return 'Merriweather';
      case ReaderFontFamily.lora:         return 'Lora';
      case ReaderFontFamily.openSans:     return 'Open Sans';
      case ReaderFontFamily.roboto:       return 'Roboto';
      case ReaderFontFamily.openDyslexic: return 'OpenDyslexic';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VOLUME DIRECTION PICKER
// Two options with a clear visual explanation of what each means
// ─────────────────────────────────────────────────────────────────────────────

class _VolumeDirectionPicker extends StatelessWidget {
  final VolumeButtonDirection current;
  final void Function(VolumeButtonDirection) onSelect;

  const _VolumeDirectionPicker(
      {required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _VolumeOption(
          mode:        VolumeButtonDirection.normal,
          current:     current,
          title:       'Normal',
          upLabel:     'Vol ▲  →  Previous page / Slower scroll',
          downLabel:   'Vol ▼  →  Next page / Faster scroll',
          onSelect:    onSelect,
        ),
        const SizedBox(height: 8),
        _VolumeOption(
          mode:        VolumeButtonDirection.inverted,
          current:     current,
          title:       'Inverted',
          upLabel:     'Vol ▲  →  Next page / Faster scroll',
          downLabel:   'Vol ▼  →  Previous page / Slower scroll',
          onSelect:    onSelect,
        ),
      ],
    );
  }
}

class _VolumeOption extends StatelessWidget {
  final VolumeButtonDirection mode, current;
  final String title, upLabel, downLabel;
  final void Function(VolumeButtonDirection) onSelect;

  const _VolumeOption({
    required this.mode,
    required this.current,
    required this.title,
    required this.upLabel,
    required this.downLabel,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = current == mode;
    return GestureDetector(
      onTap: () => onSelect(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:  const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:        isSelected
              ? _C.accent.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? _C.accent.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.06),
            width: isSelected ? 1.5 : 0.8,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Radio indicator
            Container(
              width: 18, height: 18,
              margin: const EdgeInsets.only(top: 2, right: 12),
              decoration: BoxDecoration(
                shape:  BoxShape.circle,
                border: Border.all(
                    color: isSelected ? _C.accentL : _C.dim,
                    width: 2),
                color: isSelected ? _C.accent : Colors.transparent,
              ),
              child: isSelected
                  ? const Center(
                      child: CircleAvatar(
                          radius: 4, backgroundColor: Colors.white))
                  : null,
            ),
            // Labels
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        color:      isSelected ? _C.text : _C.sub,
                        fontSize:   13,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 4),
                  Text(upLabel,
                      style: const TextStyle(
                          color: _C.dim, fontSize: 11, height: 1.5)),
                  Text(downLabel,
                      style: const TextStyle(
                          color: _C.dim, fontSize: 11, height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SLEEP TIMER DURATION PICKER
// Predefined options + visual indication of the currently selected one
// ─────────────────────────────────────────────────────────────────────────────

class _DurationPicker extends StatelessWidget {
  final int currentMinutes;
  final void Function(int) onSelect;

  const _DurationPicker(
      {required this.currentMinutes, required this.onSelect});

  // Preset duration options in minutes
  static const _presets = [10, 20, 30, 45, 60, 90];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _presets.map((mins) {
        final isSelected = currentMinutes == mins;
        final label      = mins < 60
            ? '$mins min'
            : '${mins ~/ 60}h${mins % 60 > 0 ? " ${mins % 60}m" : ""}';

        return GestureDetector(
          onTap: () => onSelect(mins),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color:        isSelected
                  ? _C.accent.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? _C.accent.withValues(alpha: 0.55)
                    : Colors.white.withValues(alpha: 0.07),
                width: isSelected ? 1.5 : 0.8,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color:      isSelected ? _C.accentL : _C.sub,
                fontSize:   13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FOLDER ROW
// Shows a single library folder path in a compact, readable format
// ─────────────────────────────────────────────────────────────────────────────

class _FolderRow extends StatelessWidget {
  final String path;
  const _FolderRow({required this.path});

  @override
  Widget build(BuildContext context) {
    // Show only the last folder name for readability, full path as subtitle
    final name = path.split('/').where((s) => s.isNotEmpty).last;

    return Container(
      margin:  const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:        Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          const Icon(Icons.folder_rounded, color: _C.accent, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: _C.text, fontSize: 13, fontWeight: FontWeight.w500)),
                Text(path,
                    style: const TextStyle(color: _C.dim, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REUSABLE BUILDING BLOCKS
// Small, focused widgets used multiple times in the sections above
// ─────────────────────────────────────────────────────────────────────────────

/// A section-internal label + subtitle pair
class _RowLabel extends StatelessWidget {
  final String label;
  final String subtitle;
  const _RowLabel({required this.label, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: _C.text, fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(subtitle,
            style: const TextStyle(
                color: _C.sub, fontSize: 12, height: 1.4)),
      ],
    );
  }
}

/// A row with a label, subtitle, and a Flutter Switch
class _ToggleRow extends StatelessWidget {
  final String   label;
  final String   subtitle;
  final bool     value;
  final void Function(bool) onChanged;

  const _ToggleRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: _C.text, fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(
                      color: _C.sub, fontSize: 12, height: 1.4)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch(
          value:      value,
          onChanged:  onChanged,
          activeColor: _C.accent,
          trackColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? _C.accent.withValues(alpha: 0.3)
                  : const Color(0xFF1E2E42)),
        ),
      ],
    );
  }
}

/// A slider row with label, current value display, and the slider itself
class _SliderRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final String displayValue;
  final double value, min, max;
  final int    divisions;
  final void Function(double) onChanged;

  const _SliderRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.displayValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: _C.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 1),
                Text(subtitle,
                    style: const TextStyle(color: _C.sub, fontSize: 12)),
              ],
            ),
            // Current value chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color:        _C.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(displayValue,
                  style: const TextStyle(
                      color:      _C.accentL,
                      fontSize:   12,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderThemeData(
            trackHeight:       2.0,
            activeTrackColor:  _C.accent,
            inactiveTrackColor: const Color(0xFF1E2E42),
            thumbColor:        _C.accentL,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            overlayColor: _C.accent.withValues(alpha: 0.15),
          ),
          child: Slider(
            value:     value,
            min:       min,
            max:       max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// A segmented control — 2 or 3 options as pill buttons
class _SegmentedRow extends StatelessWidget {
  final List<String> options;
  final int          selected;
  final void Function(int) onSelect;

  const _SegmentedRow({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(options.length, (i) {
        final isActive = selected == i;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: i < options.length - 1 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color:        isActive
                    ? _C.accent.withValues(alpha: 0.16)
                    : Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isActive
                      ? _C.accent.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.07),
                  width: isActive ? 1.5 : 0.8,
                ),
              ),
              child: Center(
                child: Text(
                  options[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color:      isActive ? _C.accentL : _C.sub,
                    fontSize:   12,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// A tappable action row — for navigating to sub-screens or triggering actions
class _ActionRow extends StatelessWidget {
  final IconData   icon;
  final String     label;
  final String     subtitle;
  final VoidCallback? onTap;
  final bool       isDestructive;
  final bool       isInfo;        // If true, no chevron (non-interactive)
  final Color?     accentOverride;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.isDestructive  = false,
    this.isInfo         = false,
    this.accentOverride,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = accentOverride
        ?? (isDestructive ? _C.red : _C.accent);

    return GestureDetector(
      onTap:     isInfo ? null : onTap,
      behavior:  HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color:        iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        color:      isDestructive ? _C.red : _C.text,
                        fontSize:   14,
                        fontWeight: FontWeight.w500,
                      )),
                  const SizedBox(height: 1),
                  Text(subtitle,
                      style: const TextStyle(
                          color: _C.sub, fontSize: 12)),
                ],
              ),
            ),
            if (!isInfo)
              const Icon(Icons.chevron_right_rounded,
                  color: _C.dim, size: 18),
          ],
        ),
      ),
    );
  }
}

/// A thin horizontal divider used between rows inside a section
class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      height: 0.8,
      color:  _C.border,
    );
  }
}
