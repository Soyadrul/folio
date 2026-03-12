/// library_screen.dart
/// The main home screen of the app — the user's personal book collection.
///
/// Layout (top to bottom):
///   ┌─────────────────────────────────────────┐
///   │  Header: "FOLIO" + action buttons        │
///   │  Search bar (expands on tap)             │
///   ├─────────────────────────────────────────┤
///   │  "Continue Reading" horizontal strip     │
///   │  (only shown if there are in-progress books) │
///   ├─────────────────────────────────────────┤
///   │  Sort/view toggle bar                   │
///   │                                         │
///   │  Book grid (or list)                    │
///   │  with staggered entrance animations     │
///   └─────────────────────────────────────────┘
///
/// Special states:
///   - Scanning: shows a progress indicator with scan status text
///   - Empty library: friendly empty state with a "Scan again" button
///   - No search results: inline message within the list

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/library_provider.dart';
import '../../services/database_service.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/book_card.dart';
import '../onboarding/folder_picker_screen.dart';
import '../reader/reader_screen.dart';
import '../settings/settings_screen.dart';
import '../book_detail/book_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LIBRARY SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with TickerProviderStateMixin {

  // ── Search ────────────────────────────────────────────────────────────────
  bool _searchActive = false;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode             _searchFocus = FocusNode();

  // ── Staggered entrance animation ─────────────────────────────────────────
  // Each section of the screen slides up and fades in with a small delay
  late final AnimationController _entranceCtrl;

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 700),
    );

    // Load books from the database and start the entrance animation
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<LibraryProvider>().loadBooks();
      _entranceCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // AnnotatedRegion controls the colour of the Android status bar icons
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1421),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top section: header + search ─────────────────────────
              _buildHeader(),

              // ── Main scrollable content ───────────────────────────────
              Expanded(
                child: Consumer<LibraryProvider>(
                  builder: (context, library, _) {
                    // Show scanning progress while the folder scan is running
                    if (library.isScanning) return _buildScanningState(library);
                    // Empty library — no books found yet
                    if (library.bookCount == 0) return _buildEmptyState();
                    // Normal state — show books
                    return _buildBookContent(library);
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
  // HEADER
  // App name, search icon, settings icon, view/sort icons
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _entranceCtrl,
      builder: (_, child) => FadeTransition(
        opacity: CurvedAnimation(
          parent: _entranceCtrl,
          curve:  const Interval(0.0, 0.6, curve: Curves.easeOut),
        ),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.3),
            end:   Offset.zero,
          ).animate(CurvedAnimation(
            parent: _entranceCtrl,
            curve:  const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
          )),
          child: child,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Main header row ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
            child: Row(
              children: [
                // App name — double-tap to rescan library
                GestureDetector(
                  onDoubleTap: _rescanLibrary,
                  child: const Text(
                    'FOLIO',
                    style: TextStyle(
                      color:         Color(0xFFF0E8D8),
                      fontSize:      28,
                      fontWeight:    FontWeight.w200,
                      letterSpacing: 10,
                    ),
                  ),
                ),

                const Spacer(),

                // Search button
                _HeaderIconButton(
                  icon:    _searchActive ? Icons.close_rounded : Icons.search_rounded,
                  tooltip: 'Search',
                  onTap:   _toggleSearch,
                ),

                // Sort button
                _HeaderIconButton(
                  icon:    Icons.sort_rounded,
                  tooltip: 'Sort',
                  onTap:   _showSortSheet,
                ),

                // Grid / List toggle
                Consumer<LibraryProvider>(
                  builder: (_, lib, __) => _HeaderIconButton(
                    icon: lib.viewMode == LibraryViewMode.grid
                        ? Icons.view_list_rounded
                        : Icons.grid_view_rounded,
                    tooltip: 'Toggle view',
                    onTap: () => lib.setViewMode(
                      lib.viewMode == LibraryViewMode.grid
                          ? LibraryViewMode.list
                          : LibraryViewMode.grid,
                    ),
                  ),
                ),

                // Settings button
                _HeaderIconButton(
                  icon:    Icons.tune_rounded,
                  tooltip: 'Settings',
                  onTap:   _openSettings,
                ),
              ],
            ),
          ),

          // ── Animated search bar ──────────────────────────────────────
          AnimatedCrossFade(
            duration:        const Duration(milliseconds: 300),
            crossFadeState:  _searchActive
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild:  const SizedBox(height: 8),
            secondChild: _buildSearchBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color:        const Color(0xFFFFFFFF).withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFF5B7FA6).withOpacity(0.3), width: 0.8),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            const Icon(Icons.search_rounded,
                color: Color(0xFF4A5A70), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller:  _searchCtrl,
                focusNode:   _searchFocus,
                autofocus:   true,
                style: const TextStyle(
                    color: Color(0xFFD8E0EC), fontSize: 14),
                decoration: const InputDecoration(
                  border:      InputBorder.none,
                  hintText:    'Search by title or author…',
                  hintStyle:   TextStyle(color: Color(0xFF3A4A60)),
                  isDense:     true,
                ),
                onChanged: (q) =>
                    context.read<LibraryProvider>().setSearchQuery(q),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BOOK CONTENT
  // The main scrollable area: "Continue Reading" strip + book grid/list
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBookContent(LibraryProvider library) {
    final continueBooks = library.continueReadingBooks;
    final displayedBooks = library.displayedBooks;

    return CustomScrollView(
      // CustomScrollView lets us mix different scroll widgets (sliver + normal)
      // smoothly in one scrollable area
      physics: const BouncingScrollPhysics(),
      slivers: [

        // ── "Continue Reading" strip ─────────────────────────────────
        if (continueBooks.isNotEmpty && !_searchActive)
          SliverToBoxAdapter(
            child: _buildContinueReadingStrip(continueBooks),
          ),

        // ── Section header with book count ────────────────────────────
        SliverToBoxAdapter(
          child: _buildSectionHeader(library),
        ),

        // ── Empty search results message ──────────────────────────────
        if (displayedBooks.isEmpty && _searchActive)
          SliverFillRemaining(
            child: _buildNoResultsState(),
          )

        // ── Grid view ─────────────────────────────────────────────────
        else if (library.viewMode == LibraryViewMode.grid)
          _buildGridSliver(displayedBooks)

        // ── List view ─────────────────────────────────────────────────
        else
          _buildListSliver(displayedBooks),

        // Bottom padding so the last card isn't flush with the screen edge
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  // ── Continue Reading horizontal strip ────────────────────────────────────

  Widget _buildContinueReadingStrip(List<Book> books) {
    return AnimatedBuilder(
      animation: _entranceCtrl,
      builder: (_, child) => FadeTransition(
        opacity: CurvedAnimation(
            parent: _entranceCtrl,
            curve:  const Interval(0.2, 0.8, curve: Curves.easeOut)),
        child: SlideTransition(
          position: Tween<Offset>(
              begin: const Offset(0, 0.15), end: Offset.zero)
              .animate(CurvedAnimation(
                  parent: _entranceCtrl,
                  curve: const Interval(0.2, 0.9, curve: Curves.easeOutCubic))),
          child: child,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section label
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 14),
            child: Text(
              'CONTINUE READING',
              style: TextStyle(
                color:         Color(0xFF4A6A8A),
                fontSize:      11,
                fontWeight:    FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ),

          // Horizontal scrolling cards
          SizedBox(
            height: 258, // Cover height (200) + text below (58)
            child: ListView.builder(
              scrollDirection:  Axis.horizontal,
              padding:          const EdgeInsets.symmetric(horizontal: 20),
              itemCount:        books.length,
              itemBuilder: (context, index) {
                final book = books[index];
                final progress = context.read<LibraryProvider>().getProgress(book.id);
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: BookFeaturedCard(
                    book:     book,
                    progress: progress?.progressFraction,
                    onTap:    () => _openBook(book),
                  ),
                );
              },
            ),
          ),

          // Divider between strip and main grid
          Container(
            margin: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            height: 0.5,
            color:  const Color(0xFFFFFFFF).withOpacity(0.07),
          ),
        ],
      ),
    );
  }

  // ── Section header (book count + sort label) ──────────────────────────────

  Widget _buildSectionHeader(LibraryProvider library) {
    // Human-readable sort label shown next to the book count
    final sortLabels = {
      LibrarySortOrder.titleAZ:       'A → Z',
      LibrarySortOrder.titleZA:       'Z → A',
      LibrarySortOrder.authorAZ:      'Author',
      LibrarySortOrder.lastRead:      'Last read',
      LibrarySortOrder.recentlyAdded: 'Recent',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Row(
        children: [
          Text(
            _searchActive
                ? '${library.displayedBooks.length} result${library.displayedBooks.length == 1 ? "" : "s"}'
                : '${library.bookCount} book${library.bookCount == 1 ? "" : "s"}',
            style: const TextStyle(
              color:         Color(0xFF4A6A8A),
              fontSize:      11,
              fontWeight:    FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const Spacer(),
          if (!_searchActive)
            GestureDetector(
              onTap: _showSortSheet,
              child: Row(
                children: [
                  Text(
                    sortLabels[library.sortOrder] ?? '',
                    style: const TextStyle(
                      color:    Color(0xFF3A5070),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF3A5070), size: 16),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Grid sliver ───────────────────────────────────────────────────────────

  Widget _buildGridSliver(List<Book> books) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildAnimatedGridItem(books[index], index),
          childCount: books.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:    3,
          crossAxisSpacing:  12,
          mainAxisSpacing:   20,
          // Aspect ratio: cover (height) + text below.
          // A value of 0.58 gives roughly 3:5 covers with room for 2 lines of title.
          childAspectRatio:  0.58,
        ),
      ),
    );
  }

  /// Wraps a grid item in a staggered entrance animation.
  /// Each card fades and slides up with a small incremental delay
  /// based on its position — creating a cascading "waterfall" reveal effect.
  Widget _buildAnimatedGridItem(Book book, int index) {
    // Cap the delay at 12 items so the last cards don't wait forever
    final delayFraction = (index % 12) / 12.0;
    final start = 0.15 + delayFraction * 0.4;
    final end   = (start + 0.35).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _entranceCtrl,
      builder: (_, child) => FadeTransition(
        opacity: CurvedAnimation(
            parent: _entranceCtrl,
            curve:  Interval(start, end, curve: Curves.easeOut)),
        child: SlideTransition(
          position: Tween<Offset>(
                  begin: const Offset(0, 0.25), end: Offset.zero)
              .animate(CurvedAnimation(
                  parent: _entranceCtrl,
                  curve: Interval(start, end, curve: Curves.easeOutCubic))),
          child: child,
        ),
      ),
      child: BookGridCard(
        book:        book,
        progress:    context.read<LibraryProvider>().getProgress(book.id)?.progressFraction,
        onTap:       () => _openBook(book),
        onLongPress: () => _showBookContextMenu(book),
      ),
    );
  }

  // ── List sliver ───────────────────────────────────────────────────────────

  Widget _buildListSliver(List<Book> books) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final delayFraction = (index % 15) / 15.0;
          final start = 0.1 + delayFraction * 0.4;
          final end   = (start + 0.4).clamp(0.0, 1.0);

          return AnimatedBuilder(
            animation: _entranceCtrl,
            builder: (_, child) => FadeTransition(
              opacity: CurvedAnimation(
                  parent: _entranceCtrl,
                  curve:  Interval(start, end, curve: Curves.easeOut)),
              child: child,
            ),
            child: BookListCard(
              book:        books[index],
              progress:    null,
              onTap:       () => _openBook(books[index]),
              onLongPress: () => _showBookContextMenu(books[index]),
            ),
          );
        },
        childCount: books.length,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SPECIAL STATES
  // ─────────────────────────────────────────────────────────────────────────

  /// Shown while the library folder scan is running.
  Widget _buildScanningState(LibraryProvider library) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 48, height: 48,
              child: CircularProgressIndicator(
                color:       Color(0xFF5B7FA6),
                strokeWidth: 2,
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Building your library…',
              style: TextStyle(
                color:    Color(0xFFD8E0EC),
                fontSize: 18,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              library.scanStatus,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color:    Color(0xFF4A5A70),
                fontSize: 13,
                height:   1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shown when no books have been found in the scanned folders.
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Large subtle icon
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color:        const Color(0xFF5B7FA6).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.menu_book_outlined,
                  color: Color(0xFF3A5070), size: 38),
            ),

            const SizedBox(height: 28),

            const Text(
              'No books found',
              style: TextStyle(
                color:      Color(0xFFD8E0EC),
                fontSize:   22,
                fontWeight: FontWeight.w300,
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'Make sure your EPUB and PDF files are in the\n'
              'folder you selected, then scan again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color:    Color(0xFF4A5A70),
                fontSize: 14,
                height:   1.6,
              ),
            ),

            const SizedBox(height: 36),

            // Rescan button
            GestureDetector(
              onTap: _rescanLibrary,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  color:        const Color(0xFF5B7FA6).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF5B7FA6).withOpacity(0.4)),
                ),
                child: const Text(
                  'Scan again',
                  style: TextStyle(
                    color:      Color(0xFF7BA7D4),
                    fontSize:   14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Change folder button
            GestureDetector(
              onTap: _openFolderPicker,
              child: const Text(
                'Change folder',
                style: TextStyle(
                  color:    Color(0xFF3A5070),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shown inside the scroll view when a search has no matching results.
  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded,
              color: Color(0xFF2A3A50), size: 48),
          const SizedBox(height: 16),
          Text(
            'No results for "${_searchCtrl.text}"',
            style: const TextStyle(
              color:    Color(0xFF4A5A70),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SORT BOTTOM SHEET
  // ─────────────────────────────────────────────────────────────────────────

  void _showSortSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context:           context,
      backgroundColor:   const Color(0xFF141E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Consumer<LibraryProvider>(
        builder: (context, library, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color:        const Color(0xFF3A4A60),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Sort by',
                  style: TextStyle(
                    color:      Color(0xFF7A9ABF),
                    fontSize:   13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            // Sort options
            ...[
              (LibrarySortOrder.titleAZ,       Icons.sort_by_alpha_rounded, 'Title A → Z'),
              (LibrarySortOrder.titleZA,       Icons.sort_by_alpha_rounded, 'Title Z → A'),
              (LibrarySortOrder.authorAZ,      Icons.person_outline_rounded,'By Author'),
              (LibrarySortOrder.lastRead,      Icons.history_rounded,       'Last Read'),
              (LibrarySortOrder.recentlyAdded, Icons.fiber_new_rounded,     'Recently Added'),
            ].map((item) {
              final (order, icon, label) = item;
              final isSelected = library.sortOrder == order;
              return ListTile(
                leading: Icon(icon,
                    color: isSelected
                        ? const Color(0xFF5B7FA6)
                        : const Color(0xFF3A4A60),
                    size: 20),
                title: Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFFD8E0EC)
                        : const Color(0xFF7A8BA3),
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_rounded,
                        color: Color(0xFF5B7FA6), size: 18)
                    : null,
                onTap: () {
                  library.setSortOrder(order);
                  Navigator.pop(context);
                },
              );
            }),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BOOK CONTEXT MENU (long press)
  // ─────────────────────────────────────────────────────────────────────────

  void _showBookContextMenu(Book book) {
    showModalBottomSheet(
      context:         context,
      backgroundColor: const Color(0xFF141E2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xFF3A4A60),
                  borderRadius: BorderRadius.circular(2)),
            ),

            // Book title at top of sheet
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Text(
                book.title,
                style: const TextStyle(
                  color:      Color(0xFFD8E0EC),
                  fontSize:   16,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const Divider(color: Color(0xFF1E2E42), height: 1),

            _ContextMenuItem(
              icon:  Icons.open_in_new_rounded,
              label: 'Open book',
              onTap: () { Navigator.pop(context); _openBook(book); },
            ),
            _ContextMenuItem(
              icon:  Icons.info_outline_rounded,
              label: 'Book details',
              onTap: () { Navigator.pop(context); _openBookDetail(book); },
            ),
            _ContextMenuItem(
              icon:  Icons.restart_alt_rounded,
              label: 'Reset progress',
              onTap: () { Navigator.pop(context); _confirmResetProgress(book); },
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NAVIGATION & ACTIONS
  // ─────────────────────────────────────────────────────────────────────────

  void _toggleSearch() {
    setState(() {
      _searchActive = !_searchActive;
      if (!_searchActive) {
        _searchCtrl.clear();
        context.read<LibraryProvider>().setSearchQuery('');
        _searchFocus.unfocus();
      }
    });
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  void _openFolderPicker() {
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => const FolderPickerScreen(fromSettings: true)),
    );
  }

  Future<void> _rescanLibrary() async {
    final folders = context.read<SettingsProvider>().libraryFolders;
    if (folders.isEmpty) {
      _openFolderPicker();
      return;
    }
    await context.read<LibraryProvider>().scanFolders(folders);
  }

  void _openBook(Book book) {
    // Notify the library that this book is being opened
    // (updates open count and startedReadingAt if not set)
    context.read<LibraryProvider>().onBookOpened(book.id);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderScreen(book: book),
      ),
    );
  }

  void _openBookDetail(Book book) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookDetailScreen(book: book),
      ),
    );
  }

  Future<void> _confirmResetProgress(Book book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF141E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset progress?',
            style: TextStyle(color: Color(0xFFD8E0EC))),
        content: Text(
          'This will erase your reading position for "${book.title}". '
          'The book will open from the beginning.',
          style: const TextStyle(color: Color(0xFF7A8BA3), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF5B7FA6))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset',
                style: TextStyle(color: Color(0xFFBF4A4A))),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Delete progress from the database and refresh the library view
      await DatabaseService.instance.deleteProgress(book.id);
      context.read<LibraryProvider>().clearProgressCache(book.id);
      if (mounted) setState(() {});
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL REUSABLE WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

/// A circular icon button for the library header bar.
class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String   tooltip;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width:  44,
          height: 44,
          alignment: Alignment.center,
          child: Icon(icon, color: const Color(0xFF7A9ABF), size: 22),
        ),
      ),
    );
  }
}

/// A menu item row inside the book context menu bottom sheet.
class _ContextMenuItem extends StatelessWidget {
  final IconData icon;
  final String   label;
  final VoidCallback onTap;

  const _ContextMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading:  Icon(icon, color: const Color(0xFF5B7FA6), size: 20),
      title:    Text(label,
          style: const TextStyle(color: Color(0xFFD8E0EC), fontSize: 15)),
      onTap:    onTap,
    );
  }
}
