/// book_card.dart
/// The book card widget used in the Library screen, in two layouts:
///
///   GridCard  — portrait card with cover art, title, author, progress bar
///               Used in the main library grid view
///
///   ListCard  — horizontal card with small thumbnail on the left
///               Used in the library list view
///
///   FeaturedCard — wider, taller card used in the "Continue Reading" strip
///
/// All three share the same tap behaviour and press animation.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import 'book_cover_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GRID CARD
// Used in the main library grid — portrait orientation, cover-forward
// ─────────────────────────────────────────────────────────────────────────────

/// A card showing a book's cover, title, author, format badge, and progress bar.
/// [progress] is a value from 0.0 to 1.0 (null means never opened).
class BookGridCard extends StatefulWidget {
  final Book    book;
  final double? progress;   // 0.0–1.0, null = not started
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const BookGridCard({
    super.key,
    required this.book,
    required this.onTap,
    this.progress,
    this.onLongPress,
  });

  @override
  State<BookGridCard> createState() => _BookGridCardState();
}

class _BookGridCardState extends State<BookGridCard>
    with SingleTickerProviderStateMixin {

  // Press animation: scale down slightly on tap, spring back on release
  late final AnimationController _pressCtrl;
  late final Animation<double>   _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => _pressCtrl.forward(),
      onTapUp:     (_) { _pressCtrl.reverse(); widget.onTap(); },
      onTapCancel: ()  => _pressCtrl.reverse(),
      onLongPress: () {
        // Haptic feedback for long press (feels more physical)
        HapticFeedback.mediumImpact();
        widget.onLongPress?.call();
      },
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) =>
            Transform.scale(scale: _scaleAnim.value, child: child),
        child: _buildCard(context),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    final hasProgress = widget.progress != null && widget.progress! > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Cover art (takes up most of the card height) ─────────────────
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The cover image or generated placeholder
              BookCoverWidget(
                book:         widget.book,
                borderRadius: 10,
              ),

              // ── Progress overlay at bottom of cover ───────────────────
              if (hasProgress)
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: _ProgressBar(progress: widget.progress!),
                ),

              // ── "Finished" badge ──────────────────────────────────────
              if (widget.book.finishedReadingAt != null)
                Positioned(
                  top: 8, left: 8,
                  child: _FinishedBadge(),
                ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // ── Title ─────────────────────────────────────────────────────────
        Text(
          widget.book.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color:      Color(0xFFD8E0EC),
            fontSize:   12,
            fontWeight: FontWeight.w500,
            height:     1.35,
          ),
        ),

        const SizedBox(height: 2),

        // ── Author ────────────────────────────────────────────────────────
        if (widget.book.author.isNotEmpty)
          Text(
            widget.book.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color:    Color(0xFF4A5A70),
              fontSize: 11,
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LIST CARD
// Used in list view — horizontal layout with thumbnail + metadata
// ─────────────────────────────────────────────────────────────────────────────

class BookListCard extends StatefulWidget {
  final Book    book;
  final double? progress;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const BookListCard({
    super.key,
    required this.book,
    required this.onTap,
    this.progress,
    this.onLongPress,
  });

  @override
  State<BookListCard> createState() => _BookListCardState();
}

class _BookListCardState extends State<BookListCard>
    with SingleTickerProviderStateMixin {

  late final AnimationController _pressCtrl;
  late final Animation<double>   _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => _pressCtrl.forward(),
      onTapUp:     (_) { _pressCtrl.reverse(); widget.onTap(); },
      onTapCancel: ()  => _pressCtrl.reverse(),
      onLongPress: () {
        HapticFeedback.mediumImpact();
        widget.onLongPress?.call();
      },
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) =>
            Transform.scale(scale: _scaleAnim.value, child: child),
        child: _buildRow(context),
      ),
    );
  }

  Widget _buildRow(BuildContext context) {
    final hasProgress = widget.progress != null && widget.progress! > 0;
    final pct = widget.progress != null
        ? '${(widget.progress! * 100).round()}%'
        : null;

    return Container(
      margin:  const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF).withValues(alpha: 0.03),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFFFFFFF).withValues(alpha: 0.05),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          // ── Thumbnail (small portrait cover) ─────────────────────────
          SizedBox(
            width: 52, height: 72,
            child: BookCoverWidget(
              book: widget.book,
              borderRadius: 6,
            ),
          ),

          const SizedBox(width: 16),

          // ── Metadata ──────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  widget.book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color:      Color(0xFFD8E0EC),
                    fontSize:   14,
                    fontWeight: FontWeight.w500,
                    height:     1.35,
                  ),
                ),

                const SizedBox(height: 4),

                // Author + Format badge in a row
                Row(
                  children: [
                    if (widget.book.author.isNotEmpty)
                      Expanded(
                        child: Text(
                          widget.book.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color:    Color(0xFF4A5A70),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    _FormatBadge(format: widget.book.formatDisplayName),
                  ],
                ),

                const SizedBox(height: 8),

                // Progress bar + percentage
                if (hasProgress) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value:           widget.progress,
                            backgroundColor: const Color(0xFF1A2235),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF5B7FA6)),
                            minHeight: 3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        pct!,
                        style: const TextStyle(
                          color:    Color(0xFF5B7FA6),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // "Not started" label
                  const Text(
                    'Not started',
                    style: TextStyle(
                      color:    Color(0xFF2A3A50),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Finished checkmark ────────────────────────────────────────
          if (widget.book.finishedReadingAt != null)
            const Padding(
              padding: EdgeInsets.only(left: 12),
              child: Icon(Icons.check_circle_outline_rounded,
                  color: Color(0xFF4CAF80), size: 18),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FEATURED CARD
// Used in the "Continue Reading" horizontal strip at the top of the library.
// Wider than a grid card, with more prominent metadata.
// ─────────────────────────────────────────────────────────────────────────────

class BookFeaturedCard extends StatefulWidget {
  final Book    book;
  final double? progress;
  final VoidCallback onTap;

  const BookFeaturedCard({
    super.key,
    required this.book,
    required this.onTap,
    this.progress,
  });

  @override
  State<BookFeaturedCard> createState() => _BookFeaturedCardState();
}

class _BookFeaturedCardState extends State<BookFeaturedCard>
    with SingleTickerProviderStateMixin {

  late final AnimationController _pressCtrl;
  late final Animation<double>   _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 110));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95)
        .animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => _pressCtrl.forward(),
      onTapUp:     (_) { _pressCtrl.reverse(); widget.onTap(); },
      onTapCancel: ()  => _pressCtrl.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) =>
            Transform.scale(scale: _scaleAnim.value, child: child),
        child: _buildFeatured(),
      ),
    );
  }

  Widget _buildFeatured() {
    final pct = widget.progress != null
        ? '${(widget.progress! * 100).round()}% read'
        : null;

    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover art — taller than grid cards for a featured feel
          SizedBox(
            height: 200,
            child: Stack(
              fit: StackFit.expand,
              children: [
                BookCoverWidget(
                  book:         widget.book,
                  borderRadius: 12,
                ),
                // Gradient overlay for the progress info at bottom
                if (pct != null)
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: _ProgressBar(
                      progress: widget.progress!,
                      height:   4,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          Text(
            widget.book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color:      Color(0xFFD8E0EC),
              fontSize:   13,
              fontWeight: FontWeight.w500,
              height:     1.3,
            ),
          ),

          if (pct != null) ...[
            const SizedBox(height: 4),
            Text(
              pct,
              style: const TextStyle(
                color:    Color(0xFF5B7FA6),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED SMALL WIDGETS
// Reusable pieces used across the three card types above
// ─────────────────────────────────────────────────────────────────────────────

/// A thin coloured progress bar shown at the bottom of a cover image.
class _ProgressBar extends StatelessWidget {
  final double progress; // 0.0 → 1.0
  final double height;

  const _ProgressBar({required this.progress, this.height = 3});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
      child: LinearProgressIndicator(
        value:           progress,
        backgroundColor: const Color(0xFF0F1623).withValues(alpha: 0.6),
        valueColor:      const AlwaysStoppedAnimation<Color>(Color(0xFF5B7FA6)),
        minHeight:       height,
      ),
    );
  }
}

/// Small "✓ Done" badge shown on completed books
class _FinishedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color:        const Color(0xFF1E3A2F).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF4CAF80).withValues(alpha: 0.5)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, color: Color(0xFF4CAF80), size: 9),
          SizedBox(width: 3),
          Text('Done',
              style: TextStyle(
                color:         Color(0xFF4CAF80),
                fontSize:      8,
                fontWeight:    FontWeight.w700,
                letterSpacing: 0.3,
              )),
        ],
      ),
    );
  }
}

/// A small pill badge showing "EPUB", "PDF", or "TXT"
class _FormatBadge extends StatelessWidget {
  final String format;
  const _FormatBadge({required this.format});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color:        const Color(0xFF5B7FA6).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
            color: const Color(0xFF5B7FA6).withValues(alpha: 0.25), width: 0.7),
      ),
      child: Text(
        format,
        style: const TextStyle(
          color:         Color(0xFF5B7FA6),
          fontSize:      9,
          fontWeight:    FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
