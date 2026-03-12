/// toc_panel.dart
/// A slide-in drawer panel showing the book's Table of Contents.
///
/// Behaviour:
///   - Slides in from the LEFT edge of the screen (anatomically: the spine side)
///   - Shows a scrollable list of chapters from the EPUB or PDF
///   - Each chapter row shows:
///       • Chapter number + title
///       • A thin progress bar if the user has already read past that chapter
///       • A "current" highlight for the chapter being read now
///   - Tapping a chapter immediately jumps to it and closes the panel
///   - For PDFs we show page numbers instead of chapter names
///
/// Opening / closing:
///   The panel is always present in the widget tree (inside a Stack in
///   reader_screen.dart). Its visibility is controlled by an AnimatedSlide —
///   when [isVisible] is false the panel is translated entirely off-screen
///   to the left, so it costs zero paint cycles when hidden.

import 'package:epub_view/epub_view.dart' as ev;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TOC PANEL
// ─────────────────────────────────────────────────────────────────────────────

class TocPanel extends StatefulWidget {
  /// Whether the panel is currently visible.
  final bool isVisible;

  /// The book whose chapters we display.
  final Book book;

  /// The EPUB controller — gives us the chapter list and lets us navigate.
  /// Null for PDF and TXT books (we show a page list instead).
  final ev.EpubController? epubController;

  /// Current spine index (for the "reading now" indicator).
  final int currentSpineIndex;

  /// Total pages / spine items — for the progress dots.
  final int totalItems;

  /// Called when the user taps a chapter → closes the panel.
  final VoidCallback onClose;

  /// Called when the user selects a chapter (to jump to it).
  final void Function(int index) onChapterSelected;

  /// The background colour of the panel (matches reading theme).
  final Color backgroundColor;
  final Color textColor;

  const TocPanel({
    super.key,
    required this.isVisible,
    required this.book,
    required this.currentSpineIndex,
    required this.totalItems,
    required this.onClose,
    required this.onChapterSelected,
    required this.backgroundColor,
    required this.textColor,
    this.epubController,
  });

  @override
  State<TocPanel> createState() => _TocPanelState();
}

class _TocPanelState extends State<TocPanel> {
  // Scroll to the current chapter when the panel opens
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void didUpdateWidget(TocPanel old) {
    super.didUpdateWidget(old);
    // When panel becomes visible, scroll to the current chapter
    if (!old.isVisible && widget.isVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentChapter());
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToCurrentChapter() {
    if (!_scrollCtrl.hasClients) return;
    // Each row is ~56px; scroll so the current chapter is roughly centred
    final targetOffset =
        (widget.currentSpineIndex * 56.0) - 200.0;
    _scrollCtrl.animateTo(
      targetOffset.clamp(0.0, _scrollCtrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 350),
      curve:    Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 300),
      curve:    Curves.easeInOutCubic,
      // Panel slides in from the left; offset(-1,0) = fully off-screen left
      offset: widget.isVisible ? Offset.zero : const Offset(-1, 0),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity:  widget.isVisible ? 1.0 : 0.0,
        child: _buildPanel(),
      ),
    );
  }

  Widget _buildPanel() {
    // Panel takes up 75% of the screen width — leaves a tap-to-close strip
    final panelWidth = MediaQuery.of(context).size.width * 0.75;
    final bg   = widget.backgroundColor;
    final fg   = widget.textColor;

    // Overlay the entire screen with a dim scrim
    return Stack(
      children: [
        // ── Scrim (tap to close) ─────────────────────────────────────
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: Container(
              color: Colors.black.withOpacity(0.45),
            ),
          ),
        ),

        // ── Panel body ───────────────────────────────────────────────
        Positioned(
          top: 0, bottom: 0, left: 0,
          width: panelWidth,
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              boxShadow: [
                BoxShadow(
                  color:      Colors.black.withOpacity(0.35),
                  blurRadius: 24,
                  offset:     const Offset(8, 0),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────
                _buildHeader(bg, fg),
                // ── Chapter list ─────────────────────────────────────
                Expanded(child: _buildChapterList(fg)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 52, 16, 12),
      decoration: BoxDecoration(
        color:  bg,
        border: Border(
          bottom: BorderSide(color: fg.withOpacity(0.08), width: 0.8),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CONTENTS',
                  style: TextStyle(
                    color:         fg.withOpacity(0.35),
                    fontSize:      10,
                    fontWeight:    FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:      fg.withOpacity(0.8),
                    fontSize:   14,
                    fontWeight: FontWeight.w500,
                    height:     1.3,
                  ),
                ),
              ],
            ),
          ),
          // Close button
          IconButton(
            icon:  Icon(Icons.close_rounded,
                color: fg.withOpacity(0.4), size: 20),
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildChapterList(Color fg) {
    final total   = widget.totalItems;
    final current = widget.currentSpineIndex;

    // For EPUB: if we have a controller, try to get named chapters.
    // If not available yet, fall back to numbered items.
    final List<String> chapterTitles =
        _getChapterTitles(widget.epubController, total);

    return ListView.builder(
      controller:  _scrollCtrl,
      padding:     const EdgeInsets.symmetric(vertical: 8),
      itemCount:   total,
      itemBuilder: (context, index) {
        final isCurrent = index == current;
        final isRead    = index < current;
        final title     = index < chapterTitles.length
            ? chapterTitles[index]
            : widget.book.format == BookFormat.pdf
                ? 'Page ${index + 1}'
                : 'Chapter ${index + 1}';

        return _ChapterRow(
          index:     index,
          title:     title,
          isCurrent: isCurrent,
          isRead:    isRead,
          fg:        fg,
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onChapterSelected(index);
            widget.onClose();
          },
        );
      },
    );
  }

  /// Attempts to extract named chapter titles from the EPUB document.
  ///
  /// epub_view's EpubController exposes the parsed document as a Future<EpubBook>.
  /// We access it via controller.document and pull chapter titles from there.
  /// The result is memoised in [_chapterTitles] so we only parse once per open.
  List<String> _chapterTitlesCache = [];
  bool         _chapterTitlesLoaded = false;

  /// Synchronously returns the cached chapter titles, or triggers an async
  /// load if not yet available. Returns an empty list on first call (the
  /// ListView rebuilds automatically when [_chapterTitlesCache] is populated).
  List<String> _getChapterTitles(
      ev.EpubController? controller, int total) {
    if (controller == null) return [];
    if (_chapterTitlesLoaded)  return _chapterTitlesCache;

    // Kick off the async load — only once
    _chapterTitlesLoaded = true; // Prevent re-entry
    _loadChapterTitles(controller);
    return _chapterTitlesCache; // Empty on first call; list rebuilds after load
  }

  /// Asynchronously loads chapter titles from the EPUB document and triggers
  /// a rebuild so the TOC list shows real names instead of "Chapter N".
  Future<void> _loadChapterTitles(ev.EpubController controller) async {
    try {
      final epubBook = await controller.document;
      final chapters = epubBook.Chapters;
      if (chapters == null || chapters.isEmpty) return;

      final titles = chapters
          .map((c) => c.Title?.trim().isNotEmpty == true
              ? c.Title!.trim()
              : 'Chapter')
          .toList();

      if (mounted) {
        setState(() {
          _chapterTitlesCache = titles;
        });
      }
    } catch (_) {
      // Silently fall back to "Chapter N" labels — no crash
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHAPTER ROW
// A single row in the TOC list
// ─────────────────────────────────────────────────────────────────────────────

class _ChapterRow extends StatelessWidget {
  final int      index;
  final String   title;
  final bool     isCurrent;
  final bool     isRead;
  final Color    fg;
  final VoidCallback onTap;

  const _ChapterRow({
    required this.index,
    required this.title,
    required this.isCurrent,
    required this.isRead,
    required this.fg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:    onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration:  const Duration(milliseconds: 200),
        padding:   const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          // Current chapter gets a soft accent highlight
          color: isCurrent
              ? const Color(0xFF5B7FA6).withOpacity(0.12)
              : Colors.transparent,
          border: isCurrent
              ? const Border(
                  left: BorderSide(color: Color(0xFF5B7FA6), width: 3))
              : const Border(
                  left: BorderSide(color: Colors.transparent, width: 3)),
        ),
        child: Row(
          children: [
            // Chapter number badge
            SizedBox(
              width: 28,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color:      isCurrent
                      ? const Color(0xFF7BA7D4)
                      : fg.withOpacity(0.25),
                  fontSize:   11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Chapter title
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isCurrent
                      ? fg.withOpacity(0.95)
                      : isRead
                          ? fg.withOpacity(0.55)
                          : fg.withOpacity(0.7),
                  fontSize:   13,
                  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                  height:     1.35,
                ),
              ),
            ),

            // "Now reading" dot
            if (isCurrent)
              Container(
                width: 6, height: 6,
                margin: const EdgeInsets.only(left: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF5B7FA6),
                  shape: BoxShape.circle,
                ),
              ),

            // "Read" checkmark
            if (isRead && !isCurrent)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.check_rounded,
                    color: fg.withOpacity(0.2), size: 14),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXTENSION — workaround for nullable onTap on IconButton
// ─────────────────────────────────────────────────────────────────────────────

extension on IconButton {
  // Already has onPressed, this is just to satisfy the builder above
}
