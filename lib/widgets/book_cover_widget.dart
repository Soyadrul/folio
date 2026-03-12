/// book_cover_widget.dart
/// Renders a book's cover image in two scenarios:
///
///   1. The book HAS an embedded cover (bytes loaded from EPUB/PDF metadata)
///      → Shows the real image, filling the available space
///
///   2. The book has NO cover image
///      → Generates a beautiful placeholder using:
///         - A background colour derived from the book title (always consistent)
///         - The book's initials rendered in large, stylised typography
///         - A subtle geometric pattern for visual texture
///
/// The placeholder approach ensures every book looks intentional and polished,
/// never like a broken image icon.

import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BOOK COVER WIDGET
// ─────────────────────────────────────────────────────────────────────────────

/// Displays a book cover at any size.
/// Pass the [book] and a [borderRadius] to match the card's corners.
class BookCoverWidget extends StatelessWidget {
  final Book   book;
  final double borderRadius;
  final double? width;
  final double? height;

  const BookCoverWidget({
    super.key,
    required this.book,
    this.borderRadius = 8,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width:  width,
        height: height,
        // If the book has cover bytes, show the real image.
        // Otherwise, show the generated placeholder.
        child: book.coverBytes != null && book.coverBytes!.isNotEmpty
            ? _RealCover(bytes: Uint8List.fromList(book.coverBytes!))
            : _GeneratedCover(book: book),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REAL COVER — shows the actual image extracted from the book file
// ─────────────────────────────────────────────────────────────────────────────

class _RealCover extends StatelessWidget {
  final Uint8List bytes;
  const _RealCover({required this.bytes});

  @override
  Widget build(BuildContext context) {
    return Image.memory(
      bytes,
      fit: BoxFit.cover, // Fill the space, cropping if necessary
      // If the image fails to decode, fall back to a grey box
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFF1A2235),
        child: const Icon(Icons.broken_image_outlined,
            color: Color(0xFF3A4A60), size: 32),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GENERATED COVER — a stylised placeholder when no real cover exists
// ─────────────────────────────────────────────────────────────────────────────

/// Generates a visually rich placeholder cover using the book's title hash
/// to produce a consistent, unique colour for each book.
class _GeneratedCover extends StatelessWidget {
  final Book book;
  const _GeneratedCover({required this.book});

  /// Derives a background colour from the book title.
  /// Using a hash means the same title always produces the same colour —
  /// the book won't "change colour" every time the list rebuilds.
  Color _derivedColor() {
    // Sum the character codes of the title to get a stable number
    final hash = book.title.codeUnits
        .fold<int>(0, (prev, c) => (prev * 31 + c) & 0x7FFFFFFF);

    // Map the hash to one of several hand-picked, reading-app-appropriate palettes
    // Each palette is [background, accent] — both chosen to look good in dark UI
    const palettes = [
      [Color(0xFF1B3A4B), Color(0xFF4A9EBF)], // Deep teal
      [Color(0xFF2D1B3D), Color(0xFF8B5CF6)], // Deep violet
      [Color(0xFF1B2D1B), Color(0xFF4A8C4A)], // Forest green
      [Color(0xFF3D2416), Color(0xFFBF7A40)], // Warm amber
      [Color(0xFF1A1A35), Color(0xFF4A5ABF)], // Midnight blue
      [Color(0xFF2D1B1B), Color(0xFFBF4A4A)], // Deep crimson
      [Color(0xFF1B2C3D), Color(0xFF3A8CBF)], // Ocean blue
      [Color(0xFF2A1F0E), Color(0xFFB8963C)], // Antique gold
    ];

    return palettes[hash % palettes.length][0]; // Background colour
  }

  Color _accentColor() {
    final hash = book.title.codeUnits
        .fold<int>(0, (prev, c) => (prev * 31 + c) & 0x7FFFFFFF);
    const palettes = [
      [Color(0xFF1B3A4B), Color(0xFF4A9EBF)],
      [Color(0xFF2D1B3D), Color(0xFF8B5CF6)],
      [Color(0xFF1B2D1B), Color(0xFF4A8C4A)],
      [Color(0xFF3D2416), Color(0xFFBF7A40)],
      [Color(0xFF1A1A35), Color(0xFF4A5ABF)],
      [Color(0xFF2D1B1B), Color(0xFFBF4A4A)],
      [Color(0xFF1B2C3D), Color(0xFF3A8CBF)],
      [Color(0xFF2A1F0E), Color(0xFFB8963C)],
    ];
    return palettes[hash % palettes.length][1]; // Accent colour
  }

  /// Extracts up to 2 characters for the initials display.
  /// "The Great Gatsby" → "TG"
  /// "Dune" → "D"
  String _initials() {
    final words = book.title
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words[0][0].toUpperCase();
    // Skip articles for cleaner initials
    final skip = {'the', 'a', 'an', 'il', 'la', 'le', 'lo', 'i', 'gli'};
    final meaningful = words.where((w) => !skip.contains(w.toLowerCase())).toList();
    if (meaningful.length >= 2) {
      return '${meaningful[0][0]}${meaningful[1][0]}'.toUpperCase();
    }
    return words[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bg     = _derivedColor();
    final accent = _accentColor();
    final init   = _initials();

    return Container(
      color: bg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Geometric background pattern ─────────────────────────────
          CustomPaint(
            painter: _CoverPatternPainter(
              accentColor: accent,
              seed: book.title.length,
            ),
          ),

          // ── Format badge (top-right corner) ──────────────────────────
          Positioned(
            top: 8, right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color:        accent.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: accent.withValues(alpha: 0.4), width: 0.8),
              ),
              child: Text(
                book.formatDisplayName,
                style: TextStyle(
                  color:         accent.withValues(alpha: 0.9),
                  fontSize:      8,
                  fontWeight:    FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),

          // ── Initials in the centre ────────────────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  init,
                  style: TextStyle(
                    color:         accent.withValues(alpha: 0.85),
                    fontSize:      32,
                    fontWeight:    FontWeight.w200,
                    letterSpacing: init.length == 2 ? 4 : 0,
                    height:        1,
                  ),
                ),
                const SizedBox(height: 8),
                // Thin decorative line under the initials
                Container(
                  width: 28,
                  height: 0.8,
                  color: accent.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),

          // ── Author name at bottom ─────────────────────────────────────
          if (book.author.isNotEmpty)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin:  Alignment.topCenter,
                    end:    Alignment.bottomCenter,
                    colors: [Colors.transparent, bg.withValues(alpha: 0.9)],
                  ),
                ),
                child: Text(
                  book.author,
                  textAlign:   TextAlign.center,
                  maxLines:    1,
                  overflow:    TextOverflow.ellipsis,
                  style: TextStyle(
                    color:         accent.withValues(alpha: 0.65),
                    fontSize:      9,
                    letterSpacing: 0.5,
                    fontWeight:    FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COVER PATTERN PAINTER
// Draws a subtle geometric pattern on the generated cover background.
// Adds visual texture so the placeholder doesn't look flat.
// ─────────────────────────────────────────────────────────────────────────────

class _CoverPatternPainter extends CustomPainter {
  final Color accentColor;
  final int   seed;

  const _CoverPatternPainter({required this.accentColor, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final rng   = math.Random(seed);
    final paint = Paint()
      ..color       = accentColor.withValues(alpha: 0.06)
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // Draw 6–8 random diagonal lines for a subtle cross-hatch texture
    for (int i = 0; i < 7; i++) {
      final x1 = rng.nextDouble() * size.width;
      final y1 = rng.nextDouble() * size.height;
      final x2 = rng.nextDouble() * size.width;
      final y2 = rng.nextDouble() * size.height;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    }

    // Draw 2–3 partial circles for a more refined feel
    final circlePaint = Paint()
      ..color       = accentColor.withValues(alpha: 0.05)
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 0; i < 3; i++) {
      final cx = rng.nextDouble() * size.width;
      final cy = rng.nextDouble() * size.height;
      final r  = 20.0 + rng.nextDouble() * 40.0;
      canvas.drawCircle(Offset(cx, cy), r, circlePaint);
    }

    // Vertical rule line on the spine side (left edge)
    canvas.drawLine(
      Offset(size.width * 0.08, size.height * 0.1),
      Offset(size.width * 0.08, size.height * 0.9),
      Paint()
        ..color       = accentColor.withValues(alpha: 0.15)
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_CoverPatternPainter old) =>
      old.seed != seed || old.accentColor != accentColor;
}
