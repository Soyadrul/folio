/// reader_toolbar.dart
/// The top toolbar shown in the reader. It slides in from the top
/// when the user taps the screen, and auto-hides after 3 seconds.
///
/// Toolbar contents (left to right):
///   ← Back button  |  Book title (truncated)  |  Bookmark · TOC · Settings
///
/// In Scroll Mode, the toolbar also shows:
///   ▶/⏸ Auto-scroll toggle  |  Speed indicator

import 'package:flutter/material.dart';
import '../models/models.dart';
import '../providers/settings_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// READER TOOLBAR
// ─────────────────────────────────────────────────────────────────────────────

class ReaderToolbar extends StatelessWidget {
  final Book   book;

  /// Controls whether the toolbar is currently visible.
  /// The parent animates this via [AnimatedSlide] + [AnimatedOpacity].
  final bool   visible;

  final bool   isScrollMode;
  final bool   autoScrollActive;
  final bool   autoScrollPaused;

  // Callbacks for toolbar actions
  final VoidCallback onBack;
  final VoidCallback onBookmark;
  final VoidCallback onTocOpen;
  final VoidCallback onSettingsOpen;
  final VoidCallback onToggleAutoScroll;

  // Background colour matches the current reading theme
  final Color backgroundColor;
  final Color foregroundColor;

  const ReaderToolbar({
    super.key,
    required this.book,
    required this.visible,
    required this.onBack,
    required this.onBookmark,
    required this.onTocOpen,
    required this.onSettingsOpen,
    required this.onToggleAutoScroll,
    required this.backgroundColor,
    required this.foregroundColor,
    this.isScrollMode    = false,
    this.autoScrollActive = false,
    this.autoScrollPaused = false,
  });

  @override
  Widget build(BuildContext context) {
    // AnimatedSlide moves the toolbar up (out of view) when visible=false
    // and slides it back down to its natural position when visible=true.
    return AnimatedSlide(
      duration: const Duration(milliseconds: 280),
      curve:    Curves.easeInOutCubic,
      offset:   visible ? Offset.zero : const Offset(0, -1),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity:  visible ? 1.0 : 0.0,
        child: _buildBar(context),
      ),
    );
  }

  Widget _buildBar(BuildContext context) {
    return Container(
      // The toolbar sits directly below the status bar (SafeArea handles
      // the notch/status bar padding above it)
      color: backgroundColor,
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Row(
        children: [
          // ── Back button ──────────────────────────────────────────────
          _ToolbarButton(
            icon:     Icons.arrow_back_ios_new_rounded,
            color:    foregroundColor,
            tooltip:  'Back to library',
            onTap:    onBack,
            size:     20,
          ),

          const SizedBox(width: 4),

          // ── Book title (fills available space) ───────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize:       MainAxisSize.min,
              children: [
                Text(
                  book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:      foregroundColor.withValues(alpha: 0.85),
                    fontSize:   14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (book.author.isNotEmpty)
                  Text(
                    book.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:    foregroundColor.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),

          // ── Scroll mode controls ─────────────────────────────────────
          // Only shown when in scroll mode — auto-scroll toggle button
          if (isScrollMode) ...[
            _ToolbarButton(
              icon:    autoScrollActive && !autoScrollPaused
                  ? Icons.pause_circle_outline_rounded
                  : Icons.play_circle_outline_rounded,
              color:   foregroundColor,
              tooltip: autoScrollActive && !autoScrollPaused
                  ? 'Pause auto-scroll'
                  : 'Start auto-scroll',
              onTap:   onToggleAutoScroll,
              size:    22,
            ),
          ],

          // ── Bookmark button ──────────────────────────────────────────
          _ToolbarButton(
            icon:    Icons.bookmark_border_rounded,
            color:   foregroundColor,
            tooltip: 'Add bookmark',
            onTap:   onBookmark,
          ),

          // ── Table of Contents button ─────────────────────────────────
          _ToolbarButton(
            icon:    Icons.format_list_bulleted_rounded,
            color:   foregroundColor,
            tooltip: 'Table of contents',
            onTap:   onTocOpen,
          ),

          // ── Reader settings button ───────────────────────────────────
          _ToolbarButton(
            icon:    Icons.text_fields_rounded,
            color:   foregroundColor,
            tooltip: 'Reading settings',
            onTap:   onSettingsOpen,
          ),

          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOOLBAR BUTTON
// A single icon button inside the toolbar.
// ─────────────────────────────────────────────────────────────────────────────

class _ToolbarButton extends StatelessWidget {
  final IconData     icon;
  final Color        color;
  final String       tooltip;
  final VoidCallback onTap;
  final double       size;

  const _ToolbarButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
    this.size = 21,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap:         onTap,
          borderRadius:  BorderRadius.circular(20),
          splashColor:   color.withValues(alpha: 0.12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: color.withValues(alpha: 0.75), size: size),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// READING SETTINGS BOTTOM SHEET
// Shown when the user taps the Aₐ (text fields) button in the toolbar.
// Lets the user change font size, font family, line spacing, alignment,
// hyphenation, and switch reading mode — all without leaving the reader.
// ─────────────────────────────────────────────────────────────────────────────

class ReadingSettingsSheet extends StatelessWidget {
  final SettingsProvider settings;

  const ReadingSettingsSheet({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    // Background and text colours adapt to the current reading theme
    const bg   = Color(0xFF141E2E);
    const text = Color(0xFFD8E0EC);
    const sub  = Color(0xFF4A5A70);
    const acc  = Color(0xFF5B7FA6);

    return Container(
      decoration: const BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize:       MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color:        const Color(0xFF3A4A60),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            const Text('Reading Settings',
                style: TextStyle(
                    color: text, fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),

            // ── Font Size ────────────────────────────────────────────
            _SheetLabel('Font Size', '${settings.fontSize.round()}pt', acc),
            const SizedBox(height: 8),
            Row(
              children: [
                // Smaller text button
                _SizeButton(
                  label: 'A',
                  fontSize: 13,
                  onTap: () => settings.setFontSize(settings.fontSize - 1),
                  color: sub,
                ),
                Expanded(
                  child: Slider(
                    value:    settings.fontSize,
                    min:      10,
                    max:      40,
                    divisions: 30,
                    activeColor:   acc,
                    inactiveColor: const Color(0xFF1E2E42),
                    onChanged: settings.setFontSize,
                  ),
                ),
                // Larger text button
                _SizeButton(
                  label: 'A',
                  fontSize: 18,
                  onTap: () => settings.setFontSize(settings.fontSize + 1),
                  color: sub,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Font Family ──────────────────────────────────────────
            const _SectionLabel('Font'),
            const SizedBox(height: 10),
            _FontFamilyPicker(settings: settings),

            const SizedBox(height: 20),

            // ── Line Spacing ─────────────────────────────────────────
            const _SectionLabel('Line Spacing'),
            const SizedBox(height: 10),
            _ThreeWayToggle(
              options:  const ['Compact', 'Normal', 'Relaxed'],
              selected: settings.lineSpacing.index,
              onSelect: (i) =>
                  settings.setLineSpacing(LineSpacing.values[i]),
              accentColor: acc,
            ),

            const SizedBox(height: 20),

            // ── Text Alignment ───────────────────────────────────────
            const _SectionLabel('Alignment'),
            const SizedBox(height: 10),
            _ThreeWayToggle(
              options:  const ['Justified', 'Left'],
              selected: settings.textAlign.index,
              onSelect: (i) =>
                  settings.setTextAlign(TextAlignSetting.values[i]),
              accentColor: acc,
            ),

            const SizedBox(height: 20),

            // ── Hyphenation toggle ───────────────────────────────────
            _SettingsToggleRow(
              label:    'Hyphenation',
              subtitle: 'Splits long words at line breaks',
              value:    settings.hyphenation,
              onChanged: settings.setHyphenation,
              accentColor: acc,
            ),

            const SizedBox(height: 12),

            // ── Reading mode toggle ──────────────────────────────────
            _SettingsToggleRow(
              label:    'Scroll Mode',
              subtitle: settings.readingMode == ReadingMode.scroll
                  ? 'Continuous scroll — tap to pause'
                  : 'Page Mode — swipe or tap to turn',
              value:    settings.readingMode == ReadingMode.scroll,
              onChanged: (v) => settings.setReadingMode(
                  v ? ReadingMode.scroll : ReadingMode.page),
              accentColor: acc,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Small helper widgets for the settings sheet ─────────────────────────────

class _SheetLabel extends StatelessWidget {
  final String label, value;
  final Color  color;
  const _SheetLabel(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label,
          style: const TextStyle(color: Color(0xFF7A8BA3), fontSize: 13)),
      Text(value,
          style: TextStyle(
              color: color, fontSize: 13, fontWeight: FontWeight.w600)),
    ],
  );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(color: Color(0xFF7A8BA3), fontSize: 13),
  );
}

class _SizeButton extends StatelessWidget {
  final String label;
  final double fontSize;
  final VoidCallback onTap;
  final Color  color;
  const _SizeButton(
      {required this.label,
      required this.fontSize,
      required this.onTap,
      required this.color});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(label,
          style: TextStyle(
              color:      color,
              fontSize:   fontSize,
              fontWeight: FontWeight.w600)),
    ),
  );
}

class _FontFamilyPicker extends StatelessWidget {
  final SettingsProvider settings;
  const _FontFamilyPicker({required this.settings});

  static const _fonts = [
    (ReaderFontFamily.merriweather, 'Merriweather'),
    (ReaderFontFamily.lora,         'Lora'),
    (ReaderFontFamily.openSans,     'Open Sans'),
    (ReaderFontFamily.roboto,       'Roboto'),
    (ReaderFontFamily.openDyslexic, 'OpenDyslexic'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: _fonts.map((entry) {
        final (family, name) = entry;
        final isSelected = settings.fontFamily == family;
        return GestureDetector(
          onTap: () => settings.setFontFamily(family),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color:        isSelected
                  ? const Color(0xFF5B7FA6).withValues(alpha: 0.2)
                  : const Color(0xFFFFFFFF).withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF5B7FA6).withValues(alpha: 0.6)
                    : const Color(0xFFFFFFFF).withValues(alpha: 0.08),
              ),
            ),
            child: Text(
              name,
              style: TextStyle(
                color:      isSelected
                    ? const Color(0xFF7BA7D4)
                    : const Color(0xFF7A8BA3),
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

class _ThreeWayToggle extends StatelessWidget {
  final List<String> options;
  final int          selected;
  final void Function(int) onSelect;
  final Color        accentColor;
  const _ThreeWayToggle(
      {required this.options,
      required this.selected,
      required this.onSelect,
      required this.accentColor});

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
                    ? accentColor.withValues(alpha: 0.18)
                    : const Color(0xFFFFFFFF).withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isActive
                      ? accentColor.withValues(alpha: 0.5)
                      : const Color(0xFFFFFFFF).withValues(alpha: 0.07),
                ),
              ),
              child: Center(
                child: Text(
                  options[i],
                  style: TextStyle(
                    color:      isActive
                        ? const Color(0xFF7BA7D4)
                        : const Color(0xFF5A6A80),
                    fontSize:   13,
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

class _SettingsToggleRow extends StatelessWidget {
  final String   label;
  final String   subtitle;
  final bool     value;
  final void Function(bool) onChanged;
  final Color    accentColor;
  const _SettingsToggleRow(
      {required this.label,
      required this.subtitle,
      required this.value,
      required this.onChanged,
      required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Color(0xFFD8E0EC), fontSize: 14)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(
                      color: Color(0xFF4A5A70), fontSize: 12)),
            ],
          ),
        ),
        Switch(
          value:          value,
          onChanged:      onChanged,
          activeColor:    accentColor,
          trackColor:     WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? accentColor.withValues(alpha: 0.3)
                  : const Color(0xFF1E2E42)),
        ),
      ],
    );
  }
}
