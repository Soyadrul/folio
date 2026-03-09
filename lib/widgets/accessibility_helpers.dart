/// accessibility_helpers.dart
/// Semantic wrappers and accessibility utilities used throughout the app.
///
/// Flutter's accessibility system (TalkBack on Android) works by reading
/// out the "semantic label" of whatever the user's finger is on. Without
/// explicit Semantics widgets, TalkBack may read raw text strings or skip
/// interactive elements entirely.
///
/// This file provides:
///   1. [SemanticButton]     — a tappable widget with a TalkBack label
///   2. [SemanticImage]      — a book cover image with a descriptive label
///   3. [MinTapTarget]       — enforces the 48×48dp minimum tap target
///   4. [ReaderTapZoneSemantic] — labels the invisible page-turn zones
///   5. [announceToTalkBack] — imperatively announces a message
///
/// Usage principle:
///   - Use Semantics when a widget has no visible text (icon buttons, images)
///   - Use ExcludeSemantics when a widget is purely decorative
///   - Use MergeSemantics when several widgets represent one logical control

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SEMANTIC BUTTON
// Wraps any widget in proper button semantics for TalkBack
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps [child] in Semantics that tell TalkBack:
///   - This is a button
///   - Its label is [label]
///   - Tapping it does something (hint [hint])
class SemanticButton extends StatelessWidget {
  final String       label;
  final String?      hint;
  final VoidCallback? onTap;
  final Widget       child;

  const SemanticButton({
    super.key,
    required this.label,
    required this.child,
    this.hint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:     label,
      hint:      hint,
      button:    true,
      enabled:   onTap != null,
      onTap:     onTap,
      // excludeSemantics: true means child widgets won't also be announced —
      // we want TalkBack to say "Bookmark button" not "bookmark icon, button"
      excludeSemantics: true,
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEMANTIC IMAGE
// Gives book cover images a meaningful TalkBack description
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps a book cover image with a semantic label.
/// TalkBack will read "Cover of [bookTitle]" instead of "image".
class SemanticImage extends StatelessWidget {
  final String bookTitle;
  final Widget child;

  const SemanticImage({
    super.key,
    required this.bookTitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:            'Cover of $bookTitle',
      image:            true,
      excludeSemantics: true,
      child:            child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MINIMUM TAP TARGET
// Ensures interactive elements meet the 48×48dp accessibility guideline
// ─────────────────────────────────────────────────────────────────────────────

/// Ensures the tappable area is at least 48×48dp, even if the visual widget
/// is smaller (e.g. a 20px icon). The extra space is transparent and
/// invisible to sighted users.
class MinTapTarget extends StatelessWidget {
  final Widget       child;
  final VoidCallback? onTap;
  final double       minWidth;
  final double       minHeight;

  const MinTapTarget({
    super.key,
    required this.child,
    this.onTap,
    this.minWidth  = 48.0,
    this.minHeight = 48.0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:    onTap,
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth:  minWidth,
          minHeight: minHeight,
        ),
        child: Center(child: child),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// READER TAP ZONE SEMANTIC
// Labels the invisible left/right page-turn zones for TalkBack users
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps a transparent tap zone in semantics so TalkBack users know
/// what tapping that region of the screen does.
///
/// Without this, TalkBack users encounter a large unlabelled touchable area.
class ReaderTapZoneSemantic extends StatelessWidget {
  /// e.g. 'Previous page', 'Next page', 'Show toolbar'
  final String       label;
  final String?      hint;
  final VoidCallback? onTap;
  final Widget       child;

  const ReaderTapZoneSemantic({
    super.key,
    required this.label,
    required this.child,
    this.hint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:            label,
      hint:             hint,
      button:           true,
      onTap:            onTap,
      excludeSemantics: true,
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOOK CARD SEMANTICS
// A complete semantic description for a book card in the library
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps a book grid/list card with a full semantic description including
/// reading progress, so TalkBack reads something useful like:
/// "The Hobbit by J.R.R. Tolkien, 44% read. Double tap to open."
class BookCardSemantic extends StatelessWidget {
  final String   title;
  final String   author;
  final double?  progressFraction; // 0.0–1.0, null = not started
  final bool     isFinished;
  final String   format;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget   child;

  const BookCardSemantic({
    super.key,
    required this.title,
    required this.author,
    required this.format,
    required this.child,
    this.progressFraction,
    this.isFinished = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    // Build a meaningful description for TalkBack
    final authorPart   = author.isNotEmpty ? ' by $author' : '';
    final progressPart = isFinished
        ? ', finished'
        : progressFraction != null && progressFraction! > 0
            ? ', ${(progressFraction! * 100).round()}% read'
            : ', not yet started';
    final label = '$title$authorPart$progressPart';

    return Semantics(
      label:  label,
      hint:   'Double tap to open',
      button: true,
      onTap:  onTap,
      // We merge the child semantics into one announcement
      child: MergeSemantics(child: child),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ANNOUNCE TO TALKBACK
// Imperatively announces a message (e.g. "Bookmark saved")
// ─────────────────────────────────────────────────────────────────────────────

/// Announces [message] to TalkBack immediately.
/// Use this for transient feedback that doesn't have a corresponding widget
/// (e.g. "Auto-scroll speed: 60 px/s").
void announceToTalkBack(BuildContext context, String message) {
  SemanticsService.announce(message, TextDirection.ltr);
}

// ─────────────────────────────────────────────────────────────────────────────
// HIGH CONTRAST DECORATION
// Returns a BoxDecoration with borders suitable for high-contrast mode
// ─────────────────────────────────────────────────────────────────────────────

/// Returns a [BoxDecoration] that adds a visible border when the device
/// is in high-contrast mode or when [highContrast] is true.
BoxDecoration highContrastDecoration({
  required bool   highContrast,
  required Color  borderColor,
  required double borderRadius,
  Color?          backgroundColor,
}) {
  return BoxDecoration(
    color:        backgroundColor,
    borderRadius: BorderRadius.circular(borderRadius),
    border: highContrast
        ? Border.all(color: borderColor, width: 1.5)
        : null,
  );
}
