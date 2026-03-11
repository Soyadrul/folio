/// book_detail_screen.dart
/// The Book Detail screen — a full profile page for a single book.
///
/// Layout (scrolls as one continuous surface):
///
///   ┌──────────────────────────────────────────┐
///   │  HERO                                    │
///   │  ┌─ Blurred atmospheric background ────┐ │
///   │  │  [Cover art floating in centre]     │ │
///   │  │  Title, Author overlaid on gradient │ │
///   │  └─────────────────────────────────────┘ │
///   ├──────────────────────────────────────────┤
///   │  ACTION BUTTONS  [Read] [Reset] [Share]  │
///   ├──────────────────────────────────────────┤
///   │  PROGRESS CARD   ████░░░░ 44%            │
///   ├──────────────────────────────────────────┤
///   │  READING DATES CARD                      │
///   │  Started: 12 Mar 2025  [edit] [🔒]       │
///   │  Finished: —           [edit]            │
///   │  Sessions: 7                             │
///   ├──────────────────────────────────────────┤
///   │  DESCRIPTION / SYNOPSIS                  │
///   ├──────────────────────────────────────────┤
///   │  DETAILS CARD                            │
///   │  Author · Publisher · Language           │
///   │  Format · File Size · Added to library   │
///   └──────────────────────────────────────────┘

import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/library_provider.dart';
import '../../services/database_service.dart';
import '../../widgets/book_cover_widget.dart';
import '../reader/reader_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// COLOUR PALETTE
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  _C._();
  static const bg      = Color(0xFF0D1421);
  static const surface = Color(0xFF121C2C);
  static const card    = Color(0xFF0F1928);
  static const border  = Color(0xFF1A2840);
  static const accent  = Color(0xFF5B7FA6);
  static const accentL = Color(0xFF7BA7D4);
  static const text    = Color(0xFFD8E0EC);
  static const sub     = Color(0xFF4A6A8A);
  static const dim     = Color(0xFF2A3A50);
  static const green   = Color(0xFF4CAF80);
  static const red     = Color(0xFFBF4A4A);
  static const gold    = Color(0xFFD4A847);
}

// ─────────────────────────────────────────────────────────────────────────────
// BOOK DETAIL SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class BookDetailScreen extends StatefulWidget {
  /// The book to display. If null, we load it by [bookId] from the database.
  final Book?   book;
  final String? bookId;

  const BookDetailScreen({super.key, this.book, this.bookId})
      : assert(book != null || bookId != null,
            'BookDetailScreen requires either book or bookId');

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen>
    with SingleTickerProviderStateMixin {

  // ── State ─────────────────────────────────────────────────────────────────
  Book?            _book;
  ReadingProgress? _progress;
  bool             _isLoading = true;

  // Whether the synopsis is fully expanded (truncated to 3 lines by default)
  bool _synopsisExpanded = false;

  // Entrance animation controller
  late final AnimationController _entranceCtrl;

  // Date formatter for the reading dates section
  static final _dateFmt = DateFormat('d MMM yyyy');

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 600),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DATA LOADING
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    // Use the book passed directly, or load from the database by ID
    Book? book = widget.book;
    if (book == null && widget.bookId != null) {
      book = await DatabaseService.instance.getBook(widget.bookId!);
    }

    ReadingProgress? progress;
    if (book != null) {
      progress = await DatabaseService.instance.getProgress(book.id);
    }

    if (mounted) {
      setState(() {
        _book     = book;
        _progress = progress;
        _isLoading = false;
      });
      _entranceCtrl.forward();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _C.bg,
        body: _isLoading
            ? _buildLoadingState()
            : _book == null
                ? _buildNotFoundState()
                : _buildContent(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MAIN CONTENT
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildContent() {
    final book = _book!;

    return FadeTransition(
      opacity: CurvedAnimation(
          parent: _entranceCtrl, curve: Curves.easeOut),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [

          // ── Hero section (SliverAppBar gives parallax on scroll) ─────
          SliverAppBar(
            expandedHeight: 420,
            pinned:         true,
            backgroundColor: _C.bg,
            leading: IconButton(
              icon:  const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            // Action buttons in app bar (only visible when collapsed)
            actions: [
              IconButton(
                icon:    const Icon(Icons.more_vert_rounded,
                    color: Colors.white70),
                onPressed: () => _showContextMenu(context),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              // collapseMode.pin keeps the blurred background fixed
              // while the content scrolls past
              collapseMode: CollapseMode.parallax,
              background:   _buildHero(book),
            ),
          ),

          // ── All cards below the hero ────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 60),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 20),
                _buildActionButtons(book),
                const SizedBox(height: 20),
                _buildProgressCard(book),
                const SizedBox(height: 16),
                _buildReadingDatesCard(book),
                if (book.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildDescriptionCard(book),
                ],
                const SizedBox(height: 16),
                _buildDetailsCard(book),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HERO SECTION
  // Full-bleed atmospheric background + floating cover art + title overlay
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHero(Book book) {
    return Stack(
      fit: StackFit.expand,
      children: [

        // ── Atmospheric blurred background ─────────────────────────────
        // When a real cover exists, we stretch and blur it to fill the hero
        // area, creating a beautiful colour-matched atmosphere.
        // When no cover exists, we use a radial gradient derived from the
        // same colour the generated cover placeholder uses.
        _buildHeroBackground(book),

        // ── Dark gradient overlay (top and bottom) ─────────────────────
        // Ensures the back button and title text stay readable
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin:  Alignment.topCenter,
              end:    Alignment.bottomCenter,
              colors: [
                Color(0xCC0D1421), // Dark at top (for back button)
                Colors.transparent,
                Colors.transparent,
                Color(0xEE0D1421), // Dark at bottom (for title)
              ],
              stops: [0.0, 0.25, 0.55, 1.0],
            ),
          ),
        ),

        // ── Floating cover art ─────────────────────────────────────────
        Center(
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.15),
              end:   Offset.zero,
            ).animate(CurvedAnimation(
                parent: _entranceCtrl, curve: Curves.easeOutCubic)),
            child: Container(
              // Shadow beneath the cover art lifts it off the background
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color:      Colors.black.withOpacity(0.55),
                    blurRadius: 32,
                    offset:     const Offset(0, 12),
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: BookCoverWidget(
                book:         book,
                borderRadius: 14,
                width:        140,
                height:       210,
              ),
            ),
          ),
        ),

        // ── Title + author overlaid at the bottom of the hero ──────────
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.3),
                end:   Offset.zero,
              ).animate(CurvedAnimation(
                  parent: _entranceCtrl,
                  curve:  const Interval(0.2, 1.0, curve: Curves.easeOutCubic))),
              child: FadeTransition(
                opacity: CurvedAnimation(
                    parent: _entranceCtrl,
                    curve:  const Interval(0.2, 1.0, curve: Curves.easeOut)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Title
                    Text(
                      book.title,
                      textAlign:   TextAlign.center,
                      maxLines:    3,
                      overflow:    TextOverflow.ellipsis,
                      style: const TextStyle(
                        color:         Colors.white,
                        fontSize:      22,
                        fontWeight:    FontWeight.w500,
                        height:        1.3,
                        letterSpacing: 0.2,
                        shadows: [
                          Shadow(color: Color(0x99000000), blurRadius: 8),
                        ],
                      ),
                    ),

                    if (book.author.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        book.author,
                        textAlign: TextAlign.center,
                        maxLines:  2,
                        overflow:  TextOverflow.ellipsis,
                        style: const TextStyle(
                          color:    Color(0xBBD8E0EC),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the blurred atmospheric background for the hero.
  Widget _buildHeroBackground(Book book) {
    if (book.coverBytes != null && book.coverBytes!.isNotEmpty) {
      // Real cover: stretch, blur, and desaturate slightly
      return Stack(
        fit: StackFit.expand,
        children: [
          // ColorFiltered applies the desaturation matrix to the image
          ColorFiltered(
            colorFilter: ColorFilter.matrix([
              0.8, 0.1, 0.1, 0, 0,
              0.1, 0.8, 0.1, 0, 0,
              0.1, 0.1, 0.8, 0, 0,
              0,   0,   0,   1, 0,
            ]),
            child: Image.memory(
              Uint8List.fromList(book.coverBytes!),
              fit: BoxFit.cover,
            ),
          ),
          // Blur overlay via BackdropFilter
          // This creates the frosted-glass atmospheric effect
          BackdropFilter(
            filter: ColorFilter.mode(
              Colors.black.withOpacity(0.3),
              BlendMode.darken,
            ),
            child: const SizedBox.expand(),
          ),
        ],
      );
    }

    // No cover: use a rich radial gradient derived from the book's palette
    final bgColor = _derivedBackgroundColor(book);
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0.0, -0.3),
          radius: 1.2,
          colors: [
            bgColor.withOpacity(0.8),
            _C.bg,
          ],
        ),
      ),
    );
  }

  /// Derives the atmospheric background colour from the book title hash.
  /// Uses the same palette logic as BookCoverWidget for visual consistency.
  Color _derivedBackgroundColor(Book book) {
    final hash = book.title.codeUnits
        .fold<int>(0, (p, c) => (p * 31 + c) & 0x7FFFFFFF);
    const colours = [
      Color(0xFF1B3A4B), Color(0xFF2D1B3D), Color(0xFF1B2D1B),
      Color(0xFF3D2416), Color(0xFF1A1A35), Color(0xFF2D1B1B),
      Color(0xFF1B2C3D), Color(0xFF2A1F0E),
    ];
    return colours[hash % colours.length];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACTION BUTTONS ROW
  // Primary: Read/Continue  |  Secondary: Reset progress  |  Tertiary: Share
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildActionButtons(Book book) {
    final hasProgress = _progress != null && _progress!.progressFraction > 0;
    final isFinished  = book.finishedReadingAt != null;

    return Row(
      children: [
        // ── Primary: Read / Continue ─────────────────────────────────
        Expanded(
          flex: 3,
          child: _PrimaryButton(
            icon:    isFinished
                ? Icons.replay_rounded
                : hasProgress
                    ? Icons.play_arrow_rounded
                    : Icons.menu_book_rounded,
            label:   isFinished
                ? 'Read Again'
                : hasProgress
                    ? 'Continue'
                    : 'Start Reading',
            onTap:   () => _openBook(context, book),
          ),
        ),

        const SizedBox(width: 10),

        // ── Secondary: Reset progress ─────────────────────────────────
        _IconActionButton(
          icon:    Icons.restart_alt_rounded,
          tooltip: 'Reset progress',
          onTap:   hasProgress
              ? () => _confirmResetProgress(context, book)
              : null,
          enabled: hasProgress,
        ),

        const SizedBox(width: 10),

        // ── Tertiary: Share ───────────────────────────────────────────
        _IconActionButton(
          icon:    Icons.share_outlined,
          tooltip: 'Share',
          onTap:   () => _shareBook(book),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PROGRESS CARD
  // A wide progress bar with percentage and pages-read stats
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildProgressCard(Book book) {
    final p        = _progress;
    final fraction = p?.progressFraction ?? 0.0;
    final pct      = '${(fraction * 100).round()}%';

    // Format the position label differently for EPUB vs PDF
    final positionLabel = p == null
        ? 'Not started'
        : book.format == BookFormat.epub
            ? 'Chapter ${p.spineIndex + 1} of ${p.totalPages}'
            : 'Page ${p.pageNumber} of ${p.totalPages}';

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: "Progress" label + percentage value
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _CardLabel('Progress'),
              Text(
                pct,
                style: const TextStyle(
                  color:      _C.accentL,
                  fontSize:   20,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Progress bar ────────────────────────────────────────────
          _AnimatedProgressBar(fraction: fraction),

          const SizedBox(height: 10),

          // Position text below the bar
          Text(
            positionLabel,
            style: const TextStyle(color: _C.sub, fontSize: 12),
          ),

          // Last read date
          if (p != null) ...[
            const SizedBox(height: 4),
            Text(
              'Last read ${_dateFmt.format(p.lastReadAt)}',
              style: const TextStyle(color: _C.dim, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // READING DATES CARD
  // The most unique part of this screen — shows start/finish dates with:
  //   - Inline editing via showDatePicker()
  //   - A lock button that freezes both dates so re-reading doesn't overwrite
  //   - A visual timeline connecting the two dates
  //   - Session count
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildReadingDatesCard(Book book) {
    final isLocked   = book.readingDatesLocked;
    final started    = book.startedReadingAt;
    final finished   = book.finishedReadingAt;
    final sessions   = book.openCount;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Header: label + lock button ──────────────────────────────
          Row(
            children: [
              const _CardLabel('Reading History'),
              const Spacer(),
              // Lock button
              GestureDetector(
                onTap: () => _toggleDateLock(book),
                child: Tooltip(
                  message: isLocked
                      ? 'Dates locked — tap to unlock'
                      : 'Tap to lock these dates',
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding:  const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color:        isLocked
                          ? _C.gold.withOpacity(0.12)
                          : _C.dim.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isLocked
                            ? _C.gold.withOpacity(0.4)
                            : _C.border,
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                          color: isLocked ? _C.gold : _C.dim,
                          size:  14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isLocked ? 'Locked' : 'Unlocked',
                          style: TextStyle(
                            color:      isLocked ? _C.gold : _C.dim,
                            fontSize:   11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Lock explanation text
          Text(
            isLocked
                ? 'These dates will not change even if you re-read this book.'
                : 'Dates update automatically as you read. Lock them to preserve them.',
            style: const TextStyle(
                color: _C.dim, fontSize: 11, height: 1.4),
          ),

          const SizedBox(height: 20),

          // ── Timeline ─────────────────────────────────────────────────
          _ReadingTimeline(
            startedAt:   started,
            finishedAt:  finished,
            isLocked:    isLocked,
            onEditStart: () => _editDate(book, isStartDate: true),
            onEditEnd:   () => _editDate(book, isStartDate: false),
            dateFmt:     _dateFmt,
          ),

          const SizedBox(height: 20),

          // ── Session count row ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color:        _C.accent.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _C.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_stories_outlined,
                    color: _C.sub, size: 16),
                const SizedBox(width: 10),
                Text(
                  '$sessions reading ${sessions == 1 ? 'session' : 'sessions'}',
                  style: const TextStyle(
                      color: _C.sub, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DESCRIPTION CARD
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildDescriptionCard(Book book) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardLabel('Description'),
          const SizedBox(height: 12),

          // Truncated text that expands on tap
          AnimatedCrossFade(
            duration:       const Duration(milliseconds: 300),
            crossFadeState: _synopsisExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            // Truncated (3 lines)
            firstChild: GestureDetector(
              onTap: () => setState(() => _synopsisExpanded = true),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.description,
                    maxLines:  4,
                    overflow:  TextOverflow.ellipsis,
                    style: const TextStyle(
                        color:  _C.sub,
                        fontSize: 14,
                        height: 1.65),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Read more',
                    style: TextStyle(
                        color: _C.accentL,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            // Full text
            secondChild: GestureDetector(
              onTap: () => setState(() => _synopsisExpanded = false),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.description,
                    style: const TextStyle(
                        color: _C.sub, fontSize: 14, height: 1.65),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Show less',
                    style: TextStyle(
                        color: _C.accentL,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DETAILS CARD
  // Structured metadata: author, publisher, language, format, file size, added
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildDetailsCard(Book book) {
    final rows = <(String, String, IconData)>[
      if (book.author.isNotEmpty)
        ('Author',    book.author,           Icons.person_outline_rounded),
      if (book.publisher.isNotEmpty)
        ('Publisher', book.publisher,        Icons.business_outlined),
      if (book.language.isNotEmpty)
        ('Language',  _languageDisplay(book.language),
                                             Icons.translate_rounded),
      ('Format',    book.formatDisplayName,  Icons.description_outlined),
      ('File Size', book.fileSizeDisplay,    Icons.storage_rounded),
      ('Added',     _dateFmt.format(book.addedAt),
                                             Icons.calendar_today_outlined),
    ];

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardLabel('Details'),
          const SizedBox(height: 12),
          ...rows.asMap().entries.map((entry) {
            final i = entry.key;
            final (label, value, icon) = entry.value;
            return Column(
              children: [
                _DetailRow(icon: icon, label: label, value: value),
                if (i < rows.length - 1)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    height: 0.6,
                    color:  _C.border,
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACTIONS
  // ─────────────────────────────────────────────────────────────────────────

  void _openBook(BuildContext context, Book book) {
    context.read<LibraryProvider>().onBookOpened(book.id);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReaderScreen(book: book)),
    );
  }

  Future<void> _confirmResetProgress(
      BuildContext context, Book book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF141E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset progress?',
            style: TextStyle(color: _C.text)),
        content: const Text(
          'Your reading position will be cleared.\n'
          'The book will open from the beginning next time.',
          style: TextStyle(color: _C.sub, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: _C.accent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset',
                style: TextStyle(
                    color: _C.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await DatabaseService.instance.deleteProgress(book.id);
      setState(() => _progress = null);
    }
  }

  /// Opens the native date picker and saves the result.
  Future<void> _editDate(Book book, {required bool isStartDate}) async {
    final initial = isStartDate
        ? (book.startedReadingAt  ?? DateTime.now())
        : (book.finishedReadingAt ?? DateTime.now());

    final picked = await showDatePicker(
      context:     context,
      initialDate: initial,
      firstDate:   DateTime(2000),
      lastDate:    DateTime.now().add(const Duration(days: 1)),
      builder: (_, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary:   _C.accent,
            onPrimary: Colors.white,
            surface:   Color(0xFF1A2A3A),
          ),
          dialogBackgroundColor: const Color(0xFF141E2E),
        ),
        child: child!,
      ),
    );

    if (picked == null || !mounted) return;

    final fields = isStartDate
        ? {'started_at': picked.toIso8601String()}
        : {'finished_at': picked.toIso8601String()};

    await DatabaseService.instance.updateBook(book.id, fields);

    // Reload the book to pick up the change
    final updated = await DatabaseService.instance.getBook(book.id);
    if (updated != null && mounted) {
      setState(() => _book = updated);
      context.read<LibraryProvider>().updateBookMetadata(updated);
    }
  }

  /// Toggles the reading dates lock on/off.
  Future<void> _toggleDateLock(Book book) async {
    HapticFeedback.mediumImpact();
    final newLocked = !book.readingDatesLocked;
    await DatabaseService.instance.updateBook(book.id, {
      'dates_locked': newLocked ? 1 : 0,
    });
    final updated = await DatabaseService.instance.getBook(book.id);
    if (updated != null && mounted) {
      setState(() => _book = updated);
      context.read<LibraryProvider>().updateBookMetadata(updated);
    }
  }

  void _shareBook(Book book) {
    // Share a text summary of the book — full share sheet in a future update
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${book.title} by ${book.author}'),
        backgroundColor: _C.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    if (_book == null) return;
    showModalBottomSheet(
      context:         context,
      backgroundColor: const Color(0xFF141E2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xFF3A4A60),
                  borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: const Icon(Icons.restart_alt_rounded,
                  color: _C.accent, size: 20),
              title: const Text('Reset progress',
                  style: TextStyle(color: _C.text)),
              onTap: () {
                Navigator.pop(context);
                _confirmResetProgress(context, _book!);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined,
                  color: _C.accent, size: 20),
              title: const Text('Share book info',
                  style: TextStyle(color: _C.text)),
              onTap: () {
                Navigator.pop(context);
                _shareBook(_book!);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SPECIAL STATES
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return const Center(
      child: SizedBox(
        width: 32, height: 32,
        child: CircularProgressIndicator(
            color: _C.accent, strokeWidth: 2),
      ),
    );
  }

  Widget _buildNotFoundState() {
    return const Center(
      child: Text('Book not found',
          style: TextStyle(color: _C.sub, fontSize: 16)),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Converts ISO language codes to friendly display names.
  /// Falls back to the raw code if not in our short lookup.
  String _languageDisplay(String code) {
    const names = {
      'en': 'English', 'it': 'Italian', 'fr': 'French',
      'de': 'German',  'es': 'Spanish', 'pt': 'Portuguese',
      'ja': 'Japanese','zh': 'Chinese', 'ru': 'Russian',
      'ar': 'Arabic',  'nl': 'Dutch',   'pl': 'Polish',
    };
    return names[code.toLowerCase()] ?? code.toUpperCase();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// READING TIMELINE WIDGET
// A vertical timeline showing start → finish with edit buttons on each node
// ─────────────────────────────────────────────────────────────────────────────

/// Renders a two-node vertical timeline for started/finished reading dates.
class _ReadingTimeline extends StatelessWidget {
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final bool      isLocked;
  final VoidCallback onEditStart;
  final VoidCallback onEditEnd;
  final DateFormat   dateFmt;

  const _ReadingTimeline({
    required this.startedAt,
    required this.finishedAt,
    required this.isLocked,
    required this.onEditStart,
    required this.onEditEnd,
    required this.dateFmt,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── Left column: dots and connecting line ─────────────────────
        SizedBox(
          width: 24,
          child: Column(
            children: [
              // Start dot
              _TimelineDot(
                  filled: startedAt != null, color: _C.accentL),
              // Connecting line
              Container(
                width:  1.5,
                height: 48,
                color:  startedAt != null && finishedAt != null
                    ? _C.accentL.withOpacity(0.4)
                    : _C.dim.withOpacity(0.3),
              ),
              // End dot
              _TimelineDot(
                  filled: finishedAt != null, color: _C.green),
            ],
          ),
        ),

        const SizedBox(width: 16),

        // ── Right column: date text + edit button ─────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Started row
              _DateRow(
                label:    'Started reading',
                date:     startedAt != null
                    ? dateFmt.format(startedAt!)
                    : 'Not started',
                hasDate:  startedAt != null,
                isLocked: isLocked,
                onEdit:   onEditStart,
              ),

              const SizedBox(height: 28),

              // Finished row
              _DateRow(
                label:    'Finished reading',
                date:     finishedAt != null
                    ? dateFmt.format(finishedAt!)
                    : 'Not yet finished',
                hasDate:  finishedAt != null,
                isLocked: isLocked,
                onEdit:   onEditEnd,
                accentColor: _C.green,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineDot extends StatelessWidget {
  final bool  filled;
  final Color color;
  const _TimelineDot({required this.filled, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12, height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color:  filled ? color : Colors.transparent,
        border: Border.all(
          color: filled ? color : _C.dim,
          width: 2,
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  final String     label;
  final String     date;
  final bool       hasDate;
  final bool       isLocked;
  final VoidCallback onEdit;
  final Color      accentColor;

  const _DateRow({
    required this.label,
    required this.date,
    required this.hasDate,
    required this.isLocked,
    required this.onEdit,
    this.accentColor = _C.accentL,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: _C.dim, fontSize: 11, letterSpacing: 0.3)),
              const SizedBox(height: 3),
              Text(
                date,
                style: TextStyle(
                  color:      hasDate ? _C.text : _C.dim,
                  fontSize:   14,
                  fontWeight: hasDate ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),

        // Edit button — hidden when locked
        if (!isLocked)
          GestureDetector(
            onTap: onEdit,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color:        accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: accentColor.withOpacity(0.25), width: 0.7),
              ),
              child: Text(
                hasDate ? 'Edit' : 'Set',
                style: TextStyle(
                  color:      accentColor,
                  fontSize:   11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ANIMATED PROGRESS BAR
// Animates from 0 to the target value when first shown
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedProgressBar extends StatefulWidget {
  final double fraction; // 0.0 → 1.0
  const _AnimatedProgressBar({required this.fraction});

  @override
  State<_AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<_AnimatedProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _anim = Tween<double>(begin: 0, end: widget.fraction)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    // Slight delay so the animation fires after the screen entrance
    Future.delayed(
        const Duration(milliseconds: 300), () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Stack(
        children: [
          // Track (background)
          Container(
            height:      8,
            decoration: BoxDecoration(
              color:        const Color(0xFF1A2840),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          // Fill
          FractionallySizedBox(
            widthFactor: _anim.value.clamp(0.0, 1.0),
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_C.accent, _C.accentL],
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REUSABLE SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

/// A card container with a consistent rounded, bordered style
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:        _C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border, width: 0.8),
      ),
      child: child,
    );
  }
}

/// The section label inside a card (e.g. "Progress", "Details")
class _CardLabel extends StatelessWidget {
  final String text;
  const _CardLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color:         _C.sub,
        fontSize:      11,
        fontWeight:    FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

/// One row in the Details card — icon · label · value
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _C.sub, size: 16),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(color: _C.sub, fontSize: 13)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines:  2,
            overflow:  TextOverflow.ellipsis,
            style: const TextStyle(
                color: _C.text, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

/// The main "Read / Continue / Read Again" button
class _PrimaryButton extends StatelessWidget {
  final IconData icon;
  final String   label;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4A6A9A), Color(0xFF5B7FA6)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color:      _C.accent.withOpacity(0.3),
              blurRadius: 12,
              offset:     const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color:      Colors.white,
                fontSize:   15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A square icon-only action button (secondary actions)
class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final String   tooltip;
  final VoidCallback? onTap;
  final bool     enabled;

  const _IconActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color:        _C.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _C.border, width: 0.8),
          ),
          child: Icon(
            icon,
            color: enabled ? _C.sub : _C.dim,
            size:  20,
          ),
        ),
      ),
    );
  }
}
