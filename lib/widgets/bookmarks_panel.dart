/// bookmarks_panel.dart
/// A slide-in drawer panel showing the current book's bookmarks and highlights.
///
/// Layout: a right-side drawer with two tabs at the top:
///   [Bookmarks]  [Highlights]
///
/// ── BOOKMARKS TAB ──────────────────────────────────────────────────────────
///   Each bookmark row shows:
///     • Position label (e.g. "Chapter 3 · p. 12" or "Page 47")
///     • The label the user gave it (or auto-label if blank)
///     • The text snippet captured when the bookmark was added
///     • Date added
///   Actions:
///     • Tap  → jump to that position (calls onJumpTo) and closes panel
///     • Swipe left → delete (with undo snackbar)
///
/// ── HIGHLIGHTS TAB ─────────────────────────────────────────────────────────
///   Each highlight row shows:
///     • A left border in the highlight colour (yellow/green/blue/pink)
///     • The highlighted text (truncated to 3 lines)
///     • Any note attached to it
///     • Date added + position label
///   Actions:
///     • Tap  → opens an edit sheet (change colour + add/edit note)
///     • Long-press → jump to position
///     • Swipe left → delete
///
/// ── ADD BOOKMARK ───────────────────────────────────────────────────────────
///   A floating "+" button at the bottom opens a quick sheet where the user
///   can type a label and save the bookmark at the current position.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/reader_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BOOKMARKS PANEL
// ─────────────────────────────────────────────────────────────────────────────

class BookmarksPanel extends StatefulWidget {
  /// Whether the panel is currently visible.
  final bool isVisible;

  /// The book being read.
  final Book book;

  /// Called when the user taps a bookmark/highlight to jump to it.
  final void Function(int spineIndex, double scrollOffset, int pageNumber)
      onJumpTo;

  /// Called to close the panel.
  final VoidCallback onClose;

  /// Background and text colours to match the current reading theme.
  final Color backgroundColor;
  final Color textColor;

  const BookmarksPanel({
    super.key,
    required this.isVisible,
    required this.book,
    required this.onJumpTo,
    required this.onClose,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  State<BookmarksPanel> createState() => _BookmarksPanelState();
}

class _BookmarksPanelState extends State<BookmarksPanel>
    with SingleTickerProviderStateMixin {

  late final TabController _tabCtrl;
  static final _dateFmt = DateFormat('d MMM yyyy');

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 300),
      curve:    Curves.easeInOutCubic,
      // Slides in from the right
      offset: widget.isVisible ? Offset.zero : const Offset(1, 0),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity:  widget.isVisible ? 1.0 : 0.0,
        child: _buildPanel(),
      ),
    );
  }

  Widget _buildPanel() {
    final panelWidth = MediaQuery.of(context).size.width * 0.82;
    final bg  = widget.backgroundColor;
    final fg  = widget.textColor;

    return Stack(
      children: [
        // ── Tap-to-close scrim ───────────────────────────────────────
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: Container(color: Colors.black.withOpacity(0.45)),
          ),
        ),

        // ── Panel ────────────────────────────────────────────────────
        Positioned(
          top: 0, bottom: 0, right: 0,
          width: panelWidth,
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              boxShadow: [
                BoxShadow(
                  color:      Colors.black.withOpacity(0.4),
                  blurRadius: 24,
                  offset:     const Offset(-8, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildHeader(bg, fg),
                _buildTabBar(bg, fg),
                Expanded(child: _buildTabContent(bg, fg)),
                _buildAddBookmarkButton(bg, fg),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeader(Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 52, 12, 0),
      color:   bg,
      child: Row(
        children: [
          Expanded(
            child: Text(
              'ANNOTATIONS',
              style: TextStyle(
                color:         fg.withOpacity(0.35),
                fontSize:      10,
                fontWeight:    FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ),
          IconButton(
            icon:      Icon(Icons.close_rounded,
                color: fg.withOpacity(0.4), size: 20),
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB BAR
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTabBar(Color bg, Color fg) {
    return Consumer<ReaderProvider>(
      builder: (context, reader, _) {
        final bCount = reader.bookmarks.length;
        final hCount = reader.highlights.length;

        return Container(
          color: bg,
          child: TabBar(
            controller:        _tabCtrl,
            indicatorColor:    const Color(0xFF5B7FA6),
            indicatorWeight:   2,
            labelColor:        fg.withOpacity(0.9),
            unselectedLabelColor: fg.withOpacity(0.35),
            labelStyle: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            dividerColor:      fg.withOpacity(0.08),
            tabs: [
              Tab(text: bCount > 0 ? 'Bookmarks ($bCount)' : 'Bookmarks'),
              Tab(text: hCount > 0 ? 'Highlights ($hCount)' : 'Highlights'),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB CONTENT
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTabContent(Color bg, Color fg) {
    return TabBarView(
      controller: _tabCtrl,
      children:   [
        _buildBookmarksTab(bg, fg),
        _buildHighlightsTab(bg, fg),
      ],
    );
  }

  // ── BOOKMARKS tab ─────────────────────────────────────────────────────────

  Widget _buildBookmarksTab(Color bg, Color fg) {
    return Consumer<ReaderProvider>(
      builder: (context, reader, _) {
        final bookmarks = reader.bookmarks.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (bookmarks.isEmpty) {
          return _buildEmptyState(
            icon:    Icons.bookmark_border_rounded,
            title:   'No bookmarks yet',
            subtitle: 'Tap the bookmark icon in the toolbar\nto save your current position.',
            fg:      fg,
          );
        }

        return ListView.builder(
          padding:    const EdgeInsets.symmetric(vertical: 8),
          itemCount:  bookmarks.length,
          itemBuilder: (context, i) {
            final bm = bookmarks[i];
            return _BookmarkRow(
              bookmark:   bm,
              book:       widget.book,
              fg:         fg,
              dateFmt:    _dateFmt,
              onTap: () {
                widget.onJumpTo(bm.spineIndex, bm.scrollOffset, bm.pageNumber);
                widget.onClose();
              },
              onDelete: () => _deleteBookmark(context, bm),
            );
          },
        );
      },
    );
  }

  // ── HIGHLIGHTS tab ────────────────────────────────────────────────────────

  Widget _buildHighlightsTab(Color bg, Color fg) {
    return Consumer<ReaderProvider>(
      builder: (context, reader, _) {
        final highlights = reader.highlights.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (highlights.isEmpty) {
          return _buildEmptyState(
            icon:    Icons.highlight_rounded,
            title:   'No highlights yet',
            subtitle: 'Long-press any text while reading\nto highlight it.',
            fg:      fg,
          );
        }

        return ListView.builder(
          padding:    const EdgeInsets.symmetric(vertical: 8),
          itemCount:  highlights.length,
          itemBuilder: (context, i) {
            final hl = highlights[i];
            return _HighlightRow(
              highlight: hl,
              book:      widget.book,
              fg:        fg,
              dateFmt:   _dateFmt,
              onTap: () => _openHighlightEditor(context, hl, fg),
              onJump: () {
                widget.onJumpTo(hl.spineIndex, 0, hl.pageNumber);
                widget.onClose();
              },
              onDelete: () => _deleteHighlight(context, hl),
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ADD BOOKMARK BUTTON
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildAddBookmarkButton(Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: BoxDecoration(
        color:  bg,
        border: Border(top: BorderSide(
            color: fg.withOpacity(0.08), width: 0.8)),
      ),
      child: GestureDetector(
        onTap: () => _showAddBookmarkSheet(context, fg),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color:        const Color(0xFF5B7FA6).withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFF5B7FA6).withOpacity(0.35)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bookmark_add_rounded,
                  color: Color(0xFF7BA7D4), size: 18),
              SizedBox(width: 8),
              Text(
                'Add Bookmark Here',
                style: TextStyle(
                  color:      Color(0xFF7BA7D4),
                  fontSize:   14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EMPTY STATE
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildEmptyState({
    required IconData icon,
    required String   title,
    required String   subtitle,
    required Color    fg,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: fg.withOpacity(0.15), size: 48),
            const SizedBox(height: 20),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: fg.withOpacity(0.5),
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: fg.withOpacity(0.3),
                    fontSize: 12,
                    height: 1.5)),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACTIONS
  // ─────────────────────────────────────────────────────────────────────────

  void _showAddBookmarkSheet(BuildContext context, Color fg) {
    final labelCtrl = TextEditingController();

    showModalBottomSheet(
      context:             context,
      backgroundColor:     Colors.transparent,
      isScrollControlled:  true,
      useSafeArea:         true,
      builder: (sheetCtx) => _AddBookmarkSheet(
        textColor: fg,
        labelCtrl: labelCtrl,
        onSave: (label) async {
          final reader = context.read<ReaderProvider>();
          await reader.addBookmark(
            label:       label.isNotEmpty ? label : 'Bookmark',
            textSnippet: 'Position saved',
          );
          Navigator.pop(sheetCtx);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:    Text('Bookmark added'),
                backgroundColor: Color(0xFF1A2235),
                behavior:   SnackBarBehavior.floating,
                duration:   Duration(seconds: 2),
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _deleteBookmark(BuildContext context, Bookmark bm) async {
    final reader = context.read<ReaderProvider>();
    await reader.removeBookmark(bm.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Bookmark removed'),
        backgroundColor: const Color(0xFF1A2235),
        behavior:   SnackBarBehavior.floating,
        duration:   const Duration(seconds: 3),
        action: SnackBarAction(
          label:     'Undo',
          textColor: const Color(0xFF7BA7D4),
          onPressed: () async {
            // Re-add the bookmark that was removed
            await context.read<ReaderProvider>().addBookmark(
              label:       bm.label,
              textSnippet: bm.textSnippet,
            );
          },
        ),
      ),
    );
  }

  Future<void> _deleteHighlight(BuildContext context, Highlight hl) async {
    final reader = context.read<ReaderProvider>();
    await reader.removeHighlight(hl.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Highlight removed'),
        backgroundColor: const Color(0xFF1A2235),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label:     'Undo',
          textColor: const Color(0xFF7BA7D4),
          onPressed: () async {
            await context.read<ReaderProvider>().addHighlight(
              selectedText: hl.selectedText,
              color:        hl.color,
              startOffset:  hl.startOffset,
              endOffset:    hl.endOffset,
              note:         hl.note,
            );
          },
        ),
      ),
    );
  }

  void _openHighlightEditor(
      BuildContext context, Highlight hl, Color fg) {
    showModalBottomSheet(
      context:            context,
      backgroundColor:    Colors.transparent,
      isScrollControlled: true,
      useSafeArea:        true,
      builder: (sheetCtx) => _HighlightEditorSheet(
        highlight: hl,
        textColor: fg,
        onSave: (color, note) async {
          await context
              .read<ReaderProvider>()
              .updateHighlight(hl.id, color: color, note: note);
          Navigator.pop(sheetCtx);
        },
        onDelete: () async {
          Navigator.pop(sheetCtx);
          await _deleteHighlight(context, hl);
        },
        onJump: () {
          Navigator.pop(sheetCtx);
          widget.onJumpTo(hl.spineIndex, 0, hl.pageNumber);
          widget.onClose();
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOOKMARK ROW
// ─────────────────────────────────────────────────────────────────────────────

/// A single swipeable bookmark row.
class _BookmarkRow extends StatelessWidget {
  final Bookmark     bookmark;
  final Book         book;
  final Color        fg;
  final DateFormat   dateFmt;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _BookmarkRow({
    required this.bookmark,
    required this.book,
    required this.fg,
    required this.dateFmt,
    required this.onTap,
    required this.onDelete,
  });

  String get _positionLabel {
    if (book.format == BookFormat.pdf) {
      return 'Page ${bookmark.pageNumber}';
    }
    return 'Ch. ${bookmark.spineIndex + 1} · p. ${bookmark.pageNumber}';
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      // Each dismissible needs a unique key
      key:         ValueKey(bookmark.id),
      direction:   DismissDirection.endToStart,
      background:  _DeleteBackground(),
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap:    onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: fg.withOpacity(0.06), width: 0.8),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bookmark icon
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.bookmark_rounded,
                    color: const Color(0xFF5B7FA6), size: 16),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Label
                    Text(
                      bookmark.label,
                      style: TextStyle(
                        color:      fg.withOpacity(0.85),
                        fontSize:   13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    // Position + date
                    const SizedBox(height: 3),
                    Text(
                      '$_positionLabel  ·  ${dateFmt.format(bookmark.createdAt)}',
                      style: TextStyle(
                        color:    fg.withOpacity(0.35),
                        fontSize: 11,
                      ),
                    ),

                    // Text snippet (if any)
                    if (bookmark.textSnippet.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        bookmark.textSnippet,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color:  fg.withOpacity(0.45),
                          fontSize: 12,
                          height: 1.4,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded,
                  color: fg.withOpacity(0.2), size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HIGHLIGHT ROW
// ─────────────────────────────────────────────────────────────────────────────

/// A single swipeable highlight row with a coloured left border.
class _HighlightRow extends StatelessWidget {
  final Highlight    highlight;
  final Book         book;
  final Color        fg;
  final DateFormat   dateFmt;
  final VoidCallback onTap;
  final VoidCallback onJump;
  final VoidCallback onDelete;

  const _HighlightRow({
    required this.highlight,
    required this.book,
    required this.fg,
    required this.dateFmt,
    required this.onTap,
    required this.onJump,
    required this.onDelete,
  });

  String get _positionLabel {
    if (book.format == BookFormat.pdf) return 'Page ${highlight.pageNumber}';
    return 'Ch. ${highlight.spineIndex + 1}';
  }

  @override
  Widget build(BuildContext context) {
    final hlColor = highlight.color.color;

    return Dismissible(
      key:         ValueKey(highlight.id),
      direction:   DismissDirection.endToStart,
      background:  _DeleteBackground(),
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap:      onTap,
        onLongPress: () {
          HapticFeedback.mediumImpact();
          onJump();
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color:        hlColor.withOpacity(0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border(
              left: BorderSide(color: hlColor.withOpacity(0.8), width: 3),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Highlighted text
                Text(
                  highlight.selectedText,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:      fg.withOpacity(0.8),
                    fontSize:   13,
                    height:     1.5,
                    fontStyle:  FontStyle.italic,
                  ),
                ),

                // Note (if present)
                if (highlight.note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.notes_rounded,
                          color: fg.withOpacity(0.3), size: 12),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          highlight.note,
                          maxLines:  2,
                          overflow:  TextOverflow.ellipsis,
                          style: TextStyle(
                            color:    fg.withOpacity(0.5),
                            fontSize: 11,
                            height:   1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 6),

                // Footer: colour swatch + position + date
                Row(
                  children: [
                    // Colour swatch
                    Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                        color:  hlColor,
                        shape:  BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$_positionLabel  ·  ${dateFmt.format(highlight.createdAt)}',
                      style: TextStyle(
                        color:    fg.withOpacity(0.3),
                        fontSize: 10,
                      ),
                    ),
                    const Spacer(),
                    // "Tap to edit" hint
                    Text(
                      'Edit',
                      style: TextStyle(
                        color:      const Color(0xFF5B7FA6).withOpacity(0.6),
                        fontSize:   10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DELETE BACKGROUND
// The red "Delete" background revealed when swiping left
// ─────────────────────────────────────────────────────────────────────────────

class _DeleteBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment:  Alignment.centerRight,
      padding:    const EdgeInsets.only(right: 20),
      color:      const Color(0xFFBF4A4A).withOpacity(0.15),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(Icons.delete_outline_rounded,
              color: Color(0xFFBF4A4A), size: 22),
          SizedBox(width: 6),
          Text('Delete',
              style: TextStyle(
                  color:      Color(0xFFBF4A4A),
                  fontSize:   13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD BOOKMARK SHEET
// A minimal bottom sheet for saving the current position
// ─────────────────────────────────────────────────────────────────────────────

class _AddBookmarkSheet extends StatelessWidget {
  final Color                    textColor;
  final TextEditingController    labelCtrl;
  final void Function(String)    onSave;

  const _AddBookmarkSheet({
    required this.textColor,
    required this.labelCtrl,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF141E2E);
    final fg = textColor;

    return Padding(
      // Shift the sheet up when the keyboard appears
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color:        bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFF3A4A60),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),

            Text('Add Bookmark',
                style: TextStyle(
                    color: fg.withOpacity(0.9),
                    fontSize: 17,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              'Saves your current position so you can jump back later.',
              style: TextStyle(color: fg.withOpacity(0.4), fontSize: 12),
            ),

            const SizedBox(height: 20),

            // Label text field
            TextField(
              controller:  labelCtrl,
              autofocus:   true,
              style: const TextStyle(color: Color(0xFFD8E0EC), fontSize: 15),
              decoration: InputDecoration(
                hintText:       'Label (optional)',
                hintStyle: const TextStyle(color: Color(0xFF3A4A60)),
                filled:         true,
                fillColor:      const Color(0xFF0F1928),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:   const BorderSide(
                      color: Color(0xFF1A2840), width: 0.8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:   const BorderSide(
                      color: Color(0xFF1A2840), width: 0.8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:   const BorderSide(
                      color: Color(0xFF5B7FA6), width: 1.5),
                ),
              ),
              onSubmitted: (v) => onSave(v.trim()),
            ),

            const SizedBox(height: 16),

            // Save button
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () => onSave(labelCtrl.text.trim()),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color:        const Color(0xFF5B7FA6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('Save Bookmark',
                        style: TextStyle(
                          color:      Colors.white,
                          fontSize:   15,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HIGHLIGHT EDITOR SHEET
// Lets the user change the highlight colour, add/edit a note, jump to it,
// or delete it.
// ─────────────────────────────────────────────────────────────────────────────

class _HighlightEditorSheet extends StatefulWidget {
  final Highlight               highlight;
  final Color                   textColor;
  final void Function(HighlightColor, String) onSave;
  final VoidCallback            onDelete;
  final VoidCallback            onJump;

  const _HighlightEditorSheet({
    required this.highlight,
    required this.textColor,
    required this.onSave,
    required this.onDelete,
    required this.onJump,
  });

  @override
  State<_HighlightEditorSheet> createState() => _HighlightEditorSheetState();
}

class _HighlightEditorSheetState extends State<_HighlightEditorSheet> {
  late HighlightColor    _selectedColor;
  late TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.highlight.color;
    _noteCtrl = TextEditingController(text: widget.highlight.note);
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF141E2E);
    final fg = widget.textColor;

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color:        bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize:       MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                      color: const Color(0xFF3A4A60),
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),

              // Highlighted text preview
              Container(
                width:   double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color:        _selectedColor.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border(
                    left: BorderSide(
                        color: _selectedColor.color.withOpacity(0.7),
                        width: 3),
                  ),
                ),
                child: Text(
                  widget.highlight.selectedText,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:     fg.withOpacity(0.75),
                    fontSize:  13,
                    height:    1.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Colour picker ──────────────────────────────────────
              Text('Colour',
                  style: TextStyle(
                      color: fg.withOpacity(0.45),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
              const SizedBox(height: 12),
              Row(
                children: HighlightColor.values.map((c) {
                  final isSelected = _selectedColor == c;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin:   const EdgeInsets.only(right: 12),
                      width:    36, height: 36,
                      decoration: BoxDecoration(
                        color:  c.color.withOpacity(0.85),
                        shape:  BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? Colors.white.withOpacity(0.8)
                              : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: isSelected
                            ? [BoxShadow(
                                color:      c.color.withOpacity(0.4),
                                blurRadius: 8)]
                            : [],
                      ),
                      child: isSelected
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 16)
                          : null,
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // ── Note field ─────────────────────────────────────────
              Text('Note',
                  style: TextStyle(
                      color: fg.withOpacity(0.45),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
              const SizedBox(height: 10),
              TextField(
                controller: _noteCtrl,
                maxLines:   3,
                style: const TextStyle(
                    color: Color(0xFFD8E0EC), fontSize: 14),
                decoration: InputDecoration(
                  hintText:  'Add a note…',
                  hintStyle: const TextStyle(color: Color(0xFF3A4A60)),
                  filled:    true,
                  fillColor: const Color(0xFF0F1928),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:   const BorderSide(
                        color: Color(0xFF1A2840), width: 0.8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:   const BorderSide(
                        color: Color(0xFF1A2840), width: 0.8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:   const BorderSide(
                        color: Color(0xFF5B7FA6), width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Action buttons ─────────────────────────────────────
              Row(
                children: [
                  // Jump to position
                  _SheetButton(
                    icon:    Icons.my_location_rounded,
                    label:   'Jump to',
                    onTap:   widget.onJump,
                    color:   const Color(0xFF5B7FA6),
                  ),
                  const SizedBox(width: 10),
                  // Delete
                  _SheetButton(
                    icon:   Icons.delete_outline_rounded,
                    label:  'Delete',
                    onTap:  widget.onDelete,
                    color:  const Color(0xFFBF4A4A),
                  ),
                  const Spacer(),
                  // Save (primary)
                  GestureDetector(
                    onTap: () => widget.onSave(
                        _selectedColor, _noteCtrl.text.trim()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5B7FA6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('Save',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final VoidCallback onTap;
  final Color        color;
  const _SheetButton(
      {required this.icon,
      required this.label,
      required this.onTap,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color:        color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color:      color,
                    fontSize:   12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
