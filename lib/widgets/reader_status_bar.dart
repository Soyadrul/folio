/// reader_status_bar.dart
/// The bottom status bar shown at all times during reading.
///
/// Layout matches the screenshot exactly:
///   ┌─────────────────────────────────────────────┐
///   │ 16:45        33 – 1 / 48              44%   │
///   └─────────────────────────────────────────────┘
///
/// Left   : current system time, updated every minute
/// Center : chapter/page position indicator
///          - EPUB: "Chapter N · Page X / Total"
///          - PDF:  "Page X / Total"
///          - Scroll mode: "XX%" progress
/// Right  : battery level percentage + a tiny icon
///
/// Design intent: ghost-like, low-contrast — it provides useful info
/// without drawing the eye away from the text.

import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// READER STATUS BAR
// ─────────────────────────────────────────────────────────────────────────────

class ReaderStatusBar extends StatefulWidget {
  /// Current reading progress — used to build the centre text.
  final ReadingProgress? progress;

  /// The book being read — needed to know EPUB vs PDF.
  final Book book;

  /// The background colour of the bar (matches the current reading theme).
  final Color backgroundColor;

  /// The text colour (should be low-contrast vs the background).
  final Color textColor;

  /// If true, show scroll % instead of chapter/page info.
  final bool isScrollMode;

  const ReaderStatusBar({
    super.key,
    required this.book,
    required this.backgroundColor,
    required this.textColor,
    this.progress,
    this.isScrollMode = false,
  });

  @override
  State<ReaderStatusBar> createState() => _ReaderStatusBarState();
}

class _ReaderStatusBarState extends State<ReaderStatusBar> {
  // ── Time ──────────────────────────────────────────────────────────────────
  late String _timeString;
  Timer?      _timeTimer;

  // ── Battery ───────────────────────────────────────────────────────────────
  final Battery _battery = Battery();
  int    _batteryLevel   = -1;   // -1 = not yet loaded
  BatteryState _batteryState = BatteryState.unknown;
  StreamSubscription? _batteryStateSub;

  // Formatter for the time display: "16:45" (24h) or "4:45 PM" (12h)
  // We use 24h format by default — matches the screenshot
  static final _timeFmt = DateFormat('HH:mm');

  @override
  void initState() {
    super.initState();

    // ── Clock ──────────────────────────────────────────────────────────
    _timeString = _timeFmt.format(DateTime.now());

    // Update the clock every 30 seconds.
    // We use 30s instead of 60s so the display is never more than 30s off.
    _timeTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() => _timeString = _timeFmt.format(DateTime.now()));
      }
    });

    // ── Battery ────────────────────────────────────────────────────────
    _loadBattery();

    // Subscribe to charging state changes so the icon updates immediately
    // if the user plugs in / unplugs the charger while reading
    _batteryStateSub = _battery.onBatteryStateChanged.listen((state) {
      if (mounted) setState(() => _batteryState = state);
    });
  }

  /// Reads the current battery level from the device.
  /// This is an async operation so we do it outside initState.
  Future<void> _loadBattery() async {
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      if (mounted) {
        setState(() {
          _batteryLevel = level;
          _batteryState = state;
        });
      }
    } catch (_) {
      // Battery plugin not available on this platform (e.g. desktop testing)
    }
  }

  @override
  void dispose() {
    _timeTimer?.cancel();
    _batteryStateSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width:  double.infinity,
      // Slightly taller to match the screenshot — 28px gives it breathing room
      height: 28,
      color:  widget.backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ── LEFT: Time ───────────────────────────────────────────────
          _StatusText(_timeString, widget.textColor),

          // ── CENTRE: Position ──────────────────────────────────────────
          _StatusText(_buildPositionText(), widget.textColor),

          // ── RIGHT: Battery ────────────────────────────────────────────
          _buildBatteryWidget(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // POSITION TEXT BUILDER
  // Produces the centre label based on reading mode and format
  // ─────────────────────────────────────────────────────────────────────────

  String _buildPositionText() {
    final p = widget.progress;
    if (p == null) return '–';

    // In scroll mode, show a percentage
    if (widget.isScrollMode) {
      return '${(p.progressFraction * 100).round()}%';
    }

    // For PDF: "Page X / Total"
    if (widget.book.format == BookFormat.pdf) {
      return '${p.pageNumber} / ${p.totalPages}';
    }

    // For EPUB: "Ch. N · P / Total" — matches the screenshot style "33 – 1 / 48"
    // spineIndex is 0-based, so we add 1 for display
    final chapterNum = p.spineIndex + 1;
    final pageNum    = p.pageNumber;
    final total      = p.totalPages;

    if (total <= 1) return 'Ch. $chapterNum';
    return '$chapterNum – $pageNum / $total';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BATTERY WIDGET
  // Shows percentage and a small icon that changes with charging state
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBatteryWidget() {
    if (_batteryLevel < 0) {
      // Not loaded yet — show placeholder to avoid layout shift
      return _StatusText('–', widget.textColor);
    }

    // Choose icon based on charging state
    IconData batteryIcon;
    if (_batteryState == BatteryState.charging ||
        _batteryState == BatteryState.full) {
      batteryIcon = Icons.battery_charging_full_rounded;
    } else if (_batteryLevel > 75) {
      batteryIcon = Icons.battery_full_rounded;
    } else if (_batteryLevel > 40) {
      batteryIcon = Icons.battery_3_bar_rounded;
    } else if (_batteryLevel > 15) {
      batteryIcon = Icons.battery_2_bar_rounded;
    } else {
      batteryIcon = Icons.battery_1_bar_rounded;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(batteryIcon,
            color: widget.textColor.withOpacity(0.5),
            size:  11),
        const SizedBox(width: 3),
        _StatusText('$_batteryLevel%', widget.textColor),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATUS TEXT
// A small, low-contrast text widget used for all three status bar items.
// ─────────────────────────────────────────────────────────────────────────────

class _StatusText extends StatelessWidget {
  final String text;
  final Color  color;

  const _StatusText(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color:         color.withOpacity(0.55),
        fontSize:      11,
        letterSpacing: 0.3,
        fontWeight:    FontWeight.w400,
        // Use a monospaced-feeling font for numbers so the layout
        // doesn't shift as the time/page numbers change
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
