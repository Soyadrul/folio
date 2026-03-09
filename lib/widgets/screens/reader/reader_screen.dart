/// reader_screen.dart
/// The main reading screen — the heart of the app.
///
/// Supports:
///   - EPUB rendering via epub_view (reflowable, chapter-based)
///   - PDF rendering via pdfx (fixed-layout, page-based)
///   - Page Mode: tap left/right zones or volume buttons to turn pages
///   - Scroll Mode: continuous scroll with auto-scroll engine;
///                  volume buttons change speed; single tap pauses
///   - Persistent bottom status bar (time · chapter/page · battery)
///   - Auto-hiding top toolbar (appears on tap, vanishes after 3s)
///   - Reading settings bottom sheet (font, size, spacing, alignment)
///   - Exit confirmation dialog (shown once, then remembered)
///   - Auto-save progress every 5 seconds
///   - Screen kept awake via wakelock_plus (if setting enabled)
///   - Sleep timer overlay (if configured in settings)
///
/// Screen structure (Stack layers, bottom to top):
///   0. Book content (EPUB or PDF body, fills entire screen)
///   1. Left/right tap zones for page turning (Page Mode only)
///   2. Top toolbar (AnimatedSlide — slides in/out)
///   3. Bottom status bar (always visible)
///   4. Scroll speed indicator (brief overlay, Scroll Mode only)
///   5. Pause indicator ⏸ (brief, Scroll Mode only)
///   6. Sleep timer expired overlay

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:epub_view/epub_view.dart' as ev;
import 'package:pdfx/pdfx.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../models/models.dart';
import '../../providers/reader_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/epub_service.dart';
import '../../services/pdf_service.dart';
import '../../providers/library_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/reader_status_bar.dart';
import '../../widgets/reader_toolbar.dart';
import '../../widgets/toc_panel.dart';
import '../../widgets/bookmarks_panel.dart';

// ─────────────────────────────────────────────────────────────────────────────
// READER SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class ReaderScreen extends StatefulWidget {
  final Book book;
  const ReaderScreen({super.key, required this.book});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with WidgetsBindingObserver {

  // ── EPUB-specific controller ─────────────────────────────────────────────
  // EpubController manages which chapter is shown and handles navigation.
  ev.EpubController? _epubController;

  // ── PDF-specific controller ──────────────────────────────────────────────
  PdfController? _pdfController;

  // ── Scroll controller for Scroll Mode ───────────────────────────────────
  // Used both by SingleChildScrollView (scroll mode) and by the auto-scroll engine.
  final ScrollController _scrollController = ScrollController();

  // ── Loading state ────────────────────────────────────────────────────────
  // True while we're loading the book file and extracting metadata
  bool   _isLoading        = true;
  String _loadingMessage   = 'Opening book…';
  String? _loadError;       // Non-null if loading failed

  // ── Toolbar visibility ───────────────────────────────────────────────────
  bool   _toolbarVisible   = false;
  Timer? _toolbarHideTimer;

  // ── Scroll-mode speed overlay ─────────────────────────────────────────────
  // A brief "speed changed" indicator that fades out automatically
  bool   _speedIndicatorVisible = false;
  Timer? _speedHideTimer;

  // ── Pause indicator ──────────────────────────────────────────────────────
  bool   _pauseIndicatorVisible = false;
  Timer? _pauseHideTimer;

  // ── Progress tracking ────────────────────────────────────────────────────
  // Our local copy of the reading progress, updated as the user reads
  ReadingProgress? _progress;

  // Total pages/spine items — set after book loads
  int _totalPages = 1;

  // ── Exit confirmation ─────────────────────────────────────────────────────
  // Whether we've shown the "first exit" dialog for this session
  bool _exitConfirmPending = false;

  // ── Panel visibility ──────────────────────────────────────────────────────
  // Slide-in drawer panels — only one is open at a time
  bool _tocVisible         = false; // Table of Contents (left panel)
  bool _annotationsVisible = false; // Bookmarks & Highlights (right panel)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Load the book after the first frame is drawn
    WidgetsBinding.instance.addPostFrameCallback((_) => _initBook());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _toolbarHideTimer?.cancel();
    _speedHideTimer?.cancel();
    _pauseHideTimer?.cancel();
    _scrollController.dispose();
    _epubController?.dispose();
    _pdfController?.dispose();
    // Re-enable auto-brightness if we were keeping the screen awake
    WakelockPlus.disable();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BOOK INITIALISATION
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _initBook() async {
    final settings = context.read<SettingsProvider>();
    final reader   = context.read<ReaderProvider>();
    final library  = context.read<LibraryProvider>();

    // ── Keep screen awake ────────────────────────────────────────────────
    if (settings.keepScreenAwake) {
      WakelockPlus.enable();
    }

    // ── Extract metadata if this is the first open ─────────────────────
    // We detect "first open" by checking if the title is still the raw filename
    // (no spaces, looks like a filename) or if there's no author yet.
    // A proper implementation would flag this in the database.
    setState(() => _loadingMessage = 'Loading…');

    try {
      // Extract metadata on first open (updates title, author, cover)
      Book updatedBook = widget.book;
      if (widget.book.author.isEmpty || widget.book.coverBytes == null) {
        setState(() => _loadingMessage = 'Reading metadata…');
        if (widget.book.format == BookFormat.epub) {
          updatedBook = await EpubService.extractMetadata(widget.book);
        } else if (widget.book.format == BookFormat.pdf) {
          updatedBook = await PdfService.extractMetadata(widget.book);
        }
        // Push the updated metadata to the library/database
        await library.updateBookMetadata(updatedBook);
      }

      // ── Load saved progress ──────────────────────────────────────────
      setState(() => _loadingMessage = 'Restoring position…');
      await reader.openBook(updatedBook);
      _progress = reader.progress;

      // ── Initialise the correct renderer ─────────────────────────────
      if (updatedBook.format == BookFormat.epub) {
        await _initEpub(updatedBook);
      } else if (updatedBook.format == BookFormat.pdf) {
        await _initPdf(updatedBook);
      } else {
        // TXT files: handled as a plain text scroll view
        _totalPages = 1;
      }

      // ── Start sleep timer if configured ─────────────────────────────
      if (settings.sleepTimerEnabled) {
        reader.startSleepTimer(settings.sleepTimerMinutes);
      }

      // ── Attach scroll controller to reader provider ──────────────────
      reader.attachScrollController(_scrollController);

      if (mounted) {
        setState(() => _isLoading = false);
        // Show the toolbar briefly on first open so the user knows it exists
        _showToolbarTemporarily();
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading   = false;
          _loadError   = 'Could not open this book.\n$e';
        });
      }
    }
  }

  /// Initialises the EPUB controller and restores the last position.
  Future<void> _initEpub(Book book) async {
    setState(() => _loadingMessage = 'Opening chapters…');

    // EpubController takes the file path and sets up the renderer
    _epubController = ev.EpubController(
      document: ev.EpubDocument.openFile(book.filePath),
    );

    // Count total chapters for the status bar denominator
    _totalPages = await EpubService.countSpineItems(book.filePath);

    // Restore last chapter position
    if (_progress != null && _progress!.spineIndex > 0) {
      // We restore the chapter after the widget builds via a post-frame callback
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // EpubController.scrollTo() navigates to a specific chapter
        // Note: exact within-chapter scroll offset restoration
        // will be added in Step 8 (bookmarks & highlights refinement)
      });
    }
  }

  /// Initialises the PDF controller and restores the last page.
  Future<void> _initPdf(Book book) async {
    setState(() => _loadingMessage = 'Loading pages…');

    _pdfController = PdfController(
      document: PdfDocument.openFile(book.filePath),
      // Restore the last-read page immediately
      initialPage: _progress?.pageNumber ?? 1,
    );

    _totalPages = await PdfService.getPageCount(book.filePath);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settings    = context.watch<SettingsProvider>();
    final reader      = context.watch<ReaderProvider>();
    final readingTheme = Theme.of(context).extension<ReadingTheme>();

    // Resolve page and text colours from the current app theme
    final pageBg    = readingTheme?.pageBackground ?? Colors.white;
    final pageText  = readingTheme?.pageText        ?? Colors.black;
    final statusBg  = readingTheme?.statusBarBg     ?? const Color(0xFFE8E8E8);
    final statusTxt = readingTheme?.statusBarText   ?? const Color(0xFF555555);

    final isScrollMode = settings.readingMode == ReadingMode.scroll;

    // Intercept the Android back gesture to show exit confirmation
    return PopScope(
      canPop:   false,
      onPopInvokedWithResult: (didPop, _) => _handleBackPress(),
      child: Scaffold(
        backgroundColor: pageBg,
        body: _isLoading
            ? _buildLoadingState(pageBg, pageText)
            : _loadError != null
                ? _buildErrorState(pageBg, pageText)
                : _buildReaderBody(
                    context, settings, reader,
                    pageBg, pageText, statusBg, statusTxt, isScrollMode,
                  ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // READER BODY — the main reading interface
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildReaderBody(
    BuildContext context,
    SettingsProvider settings,
    ReaderProvider reader,
    Color pageBg,
    Color pageText,
    Color statusBg,
    Color statusTxt,
    bool isScrollMode,
  ) {
    final book = reader.currentBook ?? widget.book;

    return KeyboardListener(
      // KeyboardListener intercepts hardware key events (including volume keys)
      focusNode: FocusNode()..requestFocus(),
      autofocus: true,
      onKeyEvent: (event) => _handleKeyEvent(event, settings, reader, isScrollMode),
      child: SafeArea(
        // bottom: false so the status bar can sit flush with the screen bottom
        bottom: false,
        child: Stack(
          children: [

            // ── Layer 0: Book content ──────────────────────────────────
            Positioned.fill(
              child: _buildBookContent(
                  settings, reader, pageBg, pageText, isScrollMode),
            ),

            // ── Layer 1: Tap zones (Page Mode) ─────────────────────────
            if (!isScrollMode) _buildPageTapZones(settings, reader),

            // ── Layer 2: Tap-to-toggle (Scroll Mode) ───────────────────
            if (isScrollMode) _buildScrollModeTapOverlay(reader),

            // ── Layer 3: Top toolbar ────────────────────────────────────
            Positioned(
              top: 0, left: 0, right: 0,
              child: ReaderToolbar(
                book:               book,
                visible:            _toolbarVisible,
                isScrollMode:       isScrollMode,
                autoScrollActive:   reader.autoScrollActive,
                autoScrollPaused:   reader.autoScrollPaused,
                backgroundColor:    pageBg,
                foregroundColor:    pageText,
                onBack:             _handleBackPress,
                onBookmark:         _addBookmark,
                onTocOpen:          _openToc,
                onSettingsOpen:     _openReadingSettings,
                onToggleAutoScroll: () => _toggleAutoScroll(reader),
              ),
            ),

            // ── Layer 4: Bottom status bar ──────────────────────────────
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: ReaderStatusBar(
                book:            book,
                progress:        _progress,
                backgroundColor: statusBg,
                textColor:       statusTxt,
                isScrollMode:    isScrollMode,
              ),
            ),

            // ── Layer 5: Speed change indicator (Scroll Mode) ───────────
            if (isScrollMode && _speedIndicatorVisible)
              _buildSpeedIndicator(reader, pageBg, pageText),

            // ── Layer 6: Pause indicator (Scroll Mode) ──────────────────
            if (isScrollMode && _pauseIndicatorVisible &&
                reader.autoScrollPaused)
              _buildPauseIndicator(pageBg),

            // ── Layer 7: Sleep timer expired overlay ─────────────────────
            if (reader.sleepTimerExpired)
              _buildSleepTimerOverlay(pageBg, pageText, reader),

            // ── Layer 8: Table of Contents panel (slides from left) ────
            if (_tocVisible || _epubController != null || book.format == BookFormat.pdf)
              Positioned.fill(
                child: TocPanel(
                  isVisible:          _tocVisible,
                  book:               book,
                  epubController:     _epubController,
                  currentSpineIndex:  _progress?.spineIndex ?? 0,
                  totalItems:         _totalPages,
                  backgroundColor:    pageBg,
                  textColor:          pageText,
                  onClose: () => setState(() => _tocVisible = false),
                  onChapterSelected:  _jumpToChapter,
                ),
              ),

            // ── Layer 9: Bookmarks & Highlights panel (slides from right)
            Positioned.fill(
              child: BookmarksPanel(
                isVisible:       _annotationsVisible,
                book:            book,
                backgroundColor: pageBg,
                textColor:       pageText,
                onClose: () => setState(() => _annotationsVisible = false),
                onJumpTo:        _jumpToAnnotation,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BOOK CONTENT — renders EPUB, PDF, or TXT
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBookContent(
    SettingsProvider settings,
    ReaderProvider   reader,
    Color pageBg,
    Color pageText,
    bool  isScrollMode,
  ) {
    final book = reader.currentBook ?? widget.book;

    // Add consistent horizontal padding and top/bottom space
    // so text doesn't butt up against the toolbar or status bar
    const topPad    = 56.0;   // Height of toolbar
    const bottomPad = 36.0;   // Height of status bar + breathing room

    switch (book.format) {

      // ── EPUB ──────────────────────────────────────────────────────────
      case BookFormat.epub:
        if (_epubController == null) return _buildLoadingState(pageBg, pageText);
        return Padding(
          padding: EdgeInsets.only(top: topPad, bottom: bottomPad),
          child: _buildEpubView(settings, pageBg, pageText, isScrollMode),
        );

      // ── PDF ───────────────────────────────────────────────────────────
      case BookFormat.pdf:
        if (_pdfController == null) return _buildLoadingState(pageBg, pageText);
        return Padding(
          padding: EdgeInsets.only(top: topPad, bottom: bottomPad),
          child: _buildPdfView(settings, isScrollMode),
        );

      // ── TXT ───────────────────────────────────────────────────────────
      case BookFormat.txt:
        return Padding(
          padding: EdgeInsets.only(top: topPad, bottom: bottomPad),
          child: _buildTxtView(settings, pageBg, pageText, isScrollMode),
        );
    }
  }

  // ── EPUB view ─────────────────────────────────────────────────────────────

  Widget _buildEpubView(
    SettingsProvider settings,
    Color pageBg,
    Color pageText,
    bool  isScrollMode,
  ) {
    return ev.EpubView(
      controller: _epubController!,
      builders: ev.EpubViewBuilders<ev.DefaultBuilderOptions>(
        options: ev.DefaultBuilderOptions(
          // Apply user's typography preferences to the rendered text
          textStyle: _buildTextStyle(settings, pageText),
          chapterDividerBuilder: (_) => Divider(
            color: pageText.withOpacity(0.1),
            height: 48,
          ),
        ),
        chapterBuilder: (context, chapter) {
          // Track current chapter in progress
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateEpubProgress(chapter);
          });
          return null; // null = use default chapter layout
        },
      ),
    );
  }

  // ── PDF view ──────────────────────────────────────────────────────────────

  Widget _buildPdfView(SettingsProvider settings, bool isScrollMode) {
    return PdfView(
      controller: _pdfController!,
      scrollDirection: isScrollMode ? Axis.vertical : Axis.horizontal,
      // Page change callback — updates our progress tracker
      onPageChanged: (page) {
        _updatePdfProgress(page ?? 1);
      },
      builders: PdfViewBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        // Loading indicator shown between page renders
        documentLoaderBuilder: (_) => const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF5B7FA6), strokeWidth: 2),
        ),
        pageLoaderBuilder: (_, __) => const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF5B7FA6), strokeWidth: 2),
        ),
        errorBuilder: (_, error) => Center(
          child: Text('Error: $error',
              style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }

  // ── TXT view ──────────────────────────────────────────────────────────────

  Widget _buildTxtView(
    SettingsProvider settings,
    Color pageBg,
    Color pageText,
    bool  isScrollMode,
  ) {
    // For TXT we use a FutureBuilder to read the file asynchronously
    return FutureBuilder<String>(
      future: _readTxtFile(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF5B7FA6), strokeWidth: 2));
        }
        return SingleChildScrollView(
          controller:     _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: SelectableText(
            snapshot.data!,
            style: _buildTextStyle(settings, pageText),
          ),
        );
      },
    );
  }

  Future<String> _readTxtFile() async {
    try {
      return await Future.value(
          'TXT reader — file content would load here.');
    } catch (_) {
      return 'Could not read file.';
    }
  }

  // ── Text style builder — applies user preferences ─────────────────────────

  TextStyle _buildTextStyle(SettingsProvider settings, Color textColor) {
    // For OpenDyslexic we use the local asset; for others we rely on Google Fonts
    // (google_fonts provides them bundled, no internet needed at runtime)
    final fontFamily = settings.fontFamily == ReaderFontFamily.openDyslexic
        ? 'OpenDyslexic'
        : settings.fontFamilyName;

    return TextStyle(
      fontFamily:  fontFamily,
      fontSize:    settings.fontSize,
      height:      settings.lineHeightMultiplier,
      color:       settings.highContrastText
          ? textColor                          // Full opacity
          : textColor.withOpacity(0.88),       // Slightly softened for normal reading
      letterSpacing: 0.1,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAP ZONES — Page Mode
  // Invisible left/right tap zones that turn pages.
  // The centre zone shows/hides the toolbar.
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPageTapZones(SettingsProvider settings, ReaderProvider reader) {
    return Positioned.fill(
      child: Row(
        children: [
          // ── Left zone: previous page ──────────────────────────────────
          Expanded(
            flex: 3, // 30% of screen width
            child: GestureDetector(
              onTap: () {
                if (_toolbarVisible) {
                  _hideToolbar();
                } else {
                  _previousPage(settings, reader);
                }
              },
              // Transparent colour makes the zone register taps but stay invisible
              child: Container(color: Colors.transparent),
            ),
          ),

          // ── Centre zone: toggle toolbar ───────────────────────────────
          Expanded(
            flex: 4, // 40% of screen width
            child: GestureDetector(
              onTap: _toggleToolbar,
              child: Container(color: Colors.transparent),
            ),
          ),

          // ── Right zone: next page ─────────────────────────────────────
          Expanded(
            flex: 3, // 30% of screen width
            child: GestureDetector(
              onTap: () {
                if (_toolbarVisible) {
                  _hideToolbar();
                } else {
                  _nextPage(settings, reader);
                }
              },
              child: Container(color: Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SCROLL MODE TAP OVERLAY
  // A single tap pauses/resumes auto-scroll. No separate tap zones.
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildScrollModeTapOverlay(ReaderProvider reader) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent, // Pass events through to content
        onTap: () {
          if (reader.autoScrollActive) {
            // Single tap = pause/resume auto-scroll
            reader.toggleAutoScrollPause();
            _showPauseIndicator(reader.autoScrollPaused);
          } else {
            // If auto-scroll is not running, tap shows/hides the toolbar
            _toggleToolbar();
          }
        },
        // Double tap shows the toolbar (useful in scroll mode)
        onDoubleTap: _toggleToolbar,
        child: Container(color: Colors.transparent),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // VOLUME KEY HANDLING
  // ─────────────────────────────────────────────────────────────────────────

  void _handleKeyEvent(
    KeyEvent           event,
    SettingsProvider   settings,
    ReaderProvider     reader,
    bool               isScrollMode,
  ) {
    // Only handle key-down events — not repeat or key-up
    if (event is! KeyDownEvent) return;

    // Determine if volume-up means "forward" or "back" based on user preference
    final isInverted = settings.volumeDirection == VolumeButtonDirection.inverted;

    final isVolumeUp   = event.logicalKey == LogicalKeyboardKey.audioVolumeUp;
    final isVolumeDown = event.logicalKey == LogicalKeyboardKey.audioVolumeDown;

    if (!isVolumeUp && !isVolumeDown) return;

    if (isScrollMode) {
      // ── Scroll Mode: volume buttons change speed ─────────────────────
      // isInverted flips which button increases and which decreases
      final shouldIncrease = isInverted ? isVolumeDown : isVolumeUp;

      if (shouldIncrease) {
        reader.increaseScrollSpeed();
      } else {
        reader.decreaseScrollSpeed();
      }

      // Show the speed indicator briefly
      _showSpeedIndicator();

    } else {
      // ── Page Mode: volume buttons turn pages ─────────────────────────
      // Check if volume buttons are enabled for page turning
      final method = settings.pageTurnMethod;
      if (method == PageTurnMethod.tapOnly) return;

      // Map button to direction based on inversion setting
      final goForward = isInverted ? isVolumeDown : isVolumeUp;
      // Note: "normal" = Volume Up → PREVIOUS page (like scrolling up)
      //       matching the convention many e-readers use
      final goNext = !goForward;

      if (goNext) {
        _nextPage(settings, reader);
      } else {
        _previousPage(settings, reader);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PAGE NAVIGATION
  // ─────────────────────────────────────────────────────────────────────────

  void _nextPage(SettingsProvider settings, ReaderProvider reader) {
    HapticFeedback.selectionClick(); // Subtle physical feedback

    final book = reader.currentBook ?? widget.book;
    if (book.format == BookFormat.epub && _epubController != null) {
      _epubController!.nextPage();
    } else if (book.format == BookFormat.pdf && _pdfController != null) {
      _pdfController!.nextPage(
        duration: const Duration(milliseconds: 250),
        curve:    Curves.easeInOut,
      );
    }
  }

  void _previousPage(SettingsProvider settings, ReaderProvider reader) {
    HapticFeedback.selectionClick();

    final book = reader.currentBook ?? widget.book;
    if (book.format == BookFormat.epub && _epubController != null) {
      _epubController!.prevPage();
    } else if (book.format == BookFormat.pdf && _pdfController != null) {
      _pdfController!.previousPage(
        duration: const Duration(milliseconds: 250),
        curve:    Curves.easeInOut,
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // AUTO-SCROLL CONTROL
  // ─────────────────────────────────────────────────────────────────────────

  void _toggleAutoScroll(ReaderProvider reader) {
    if (reader.autoScrollActive && !reader.autoScrollPaused) {
      reader.pauseAutoScroll();
      _showPauseIndicator(true);
    } else if (reader.autoScrollPaused) {
      reader.resumeAutoScroll();
      _showPauseIndicator(false);
    } else {
      reader.startAutoScroll();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PROGRESS TRACKING
  // ─────────────────────────────────────────────────────────────────────────

  /// Called by the EPUB view when the current chapter changes.
  void _updateEpubProgress(dynamic chapterData) {
    if (!mounted) return;
    final reader = context.read<ReaderProvider>();
    final now    = DateTime.now();

    // chapterData provides current chapter index
    // The page number within the chapter comes from scroll position
    // In epub_view, the current position is accessed through currentValueListenable.
    // EpubChapterViewValue has a 'chapter' field with the current EpubViewChapter.
    // We get its index from the chapterNumber field (1-based), converting to 0-based.
    final chapterValue = _epubController?.currentValueListenable.value;
    final spineIdx     = chapterValue != null
        ? ((chapterValue.chapterNumber ?? 1) - 1).clamp(0, _totalPages - 1)
        : 0;
    final fraction = _totalPages > 1 ? spineIdx / _totalPages : 0.0;

    final updated = ReadingProgress(
      bookId:           widget.book.id,
      spineIndex:       spineIdx,
      scrollOffset:     _scrollController.hasClients
          ? _scrollController.offset
          : 0.0,
      pageNumber:       spineIdx + 1,
      totalPages:       _totalPages,
      progressFraction: fraction,
      lastReadAt:       now,
    );

    reader.updateProgress(updated);
    if (mounted) setState(() => _progress = updated);

    // If we've reached the last chapter, notify the library
    if (spineIdx >= _totalPages - 1) {
      context.read<LibraryProvider>().onBookFinished(widget.book.id);
    }
  }

  /// Called by the PDF view when the page changes.
  void _updatePdfProgress(int pageNumber) {
    if (!mounted) return;
    final reader   = context.read<ReaderProvider>();
    final fraction = _totalPages > 0 ? pageNumber / _totalPages : 0.0;

    final updated = ReadingProgress(
      bookId:           widget.book.id,
      pageNumber:       pageNumber,
      totalPages:       _totalPages,
      progressFraction: fraction,
      lastReadAt:       DateTime.now(),
    );

    reader.updateProgress(updated);
    if (mounted) setState(() => _progress = updated);

    // Book finished: last page reached
    if (pageNumber >= _totalPages) {
      context.read<LibraryProvider>().onBookFinished(widget.book.id);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TOOLBAR VISIBILITY
  // ─────────────────────────────────────────────────────────────────────────

  void _toggleToolbar() {
    if (_toolbarVisible) {
      _hideToolbar();
    } else {
      _showToolbarTemporarily();
    }
  }

  void _showToolbarTemporarily() {
    setState(() => _toolbarVisible = true);
    _toolbarHideTimer?.cancel();
    _toolbarHideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toolbarVisible = false);
    });
  }

  void _hideToolbar() {
    _toolbarHideTimer?.cancel();
    setState(() => _toolbarVisible = false);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // OVERLAY INDICATORS
  // ─────────────────────────────────────────────────────────────────────────

  /// Shows a brief speed-change indicator overlay (Scroll Mode).
  void _showSpeedIndicator() {
    setState(() => _speedIndicatorVisible = true);
    _speedHideTimer?.cancel();
    _speedHideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _speedIndicatorVisible = false);
    });
  }

  /// Shows or hides the ⏸ indicator.
  void _showPauseIndicator(bool paused) {
    if (paused) {
      setState(() => _pauseIndicatorVisible = true);
      _pauseHideTimer?.cancel();
      _pauseHideTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _pauseIndicatorVisible = false);
      });
    } else {
      setState(() => _pauseIndicatorVisible = false);
    }
  }

  /// Speed indicator overlay — shows current speed in px/s
  Widget _buildSpeedIndicator(
      ReaderProvider reader, Color bg, Color fg) {
    return Positioned(
      top: 70, right: 16,
      child: AnimatedOpacity(
        opacity: _speedIndicatorVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color:        bg.withOpacity(0.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: fg.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8)
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.speed_rounded,
                  color: fg.withOpacity(0.6), size: 14),
              const SizedBox(width: 6),
              Text(
                '${reader.autoScrollSpeed.round()} px/s',
                style: TextStyle(
                    color: fg.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pause indicator — a subtle ⏸ icon in the corner
  Widget _buildPauseIndicator(Color bg) {
    return Positioned(
      top: 70, left: 0, right: 0,
      child: Center(
        child: AnimatedOpacity(
          opacity: _pauseIndicatorVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:  Colors.black.withOpacity(0.45),
              shape:  BoxShape.circle,
            ),
            child: const Icon(Icons.pause_rounded,
                color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SLEEP TIMER EXPIRED OVERLAY
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSleepTimerOverlay(
      Color bg, Color fg, ReaderProvider reader) {
    return Positioned.fill(
      child: Container(
        color: bg.withOpacity(0.92),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bedtime_outlined,
                  color: fg.withOpacity(0.5), size: 56),
              const SizedBox(height: 24),
              Text('Sleep timer ended',
                  style: TextStyle(
                      color: fg.withOpacity(0.8),
                      fontSize: 22,
                      fontWeight: FontWeight.w300)),
              const SizedBox(height: 12),
              Text('Tap to keep reading',
                  style: TextStyle(
                      color: fg.withOpacity(0.4), fontSize: 14)),
              const SizedBox(height: 36),
              GestureDetector(
                onTap: () {
                  reader.cancelSleepTimer();
                  final settings = context.read<SettingsProvider>();
                  if (settings.sleepTimerEnabled) {
                    reader.startSleepTimer(settings.sleepTimerMinutes);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 13),
                  decoration: BoxDecoration(
                    color:        const Color(0xFF5B7FA6).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF5B7FA6).withOpacity(0.4)),
                  ),
                  child: const Text('Continue reading',
                      style: TextStyle(
                          color: Color(0xFF7BA7D4),
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOADING & ERROR STATES
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildLoadingState(Color bg, Color fg) {
    return Container(
      color: bg,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 36, height: 36,
              child: CircularProgressIndicator(
                  color: Color(0xFF5B7FA6), strokeWidth: 2),
            ),
            const SizedBox(height: 24),
            Text(
              _loadingMessage,
              style: TextStyle(
                  color: fg.withOpacity(0.5),
                  fontSize: 14,
                  fontWeight: FontWeight.w300),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Color bg, Color fg) {
    return Container(
      color: bg,
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded,
              color: fg.withOpacity(0.3), size: 56),
          const SizedBox(height: 24),
          Text(
            _loadError ?? 'Unknown error',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: fg.withOpacity(0.55), fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 36),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color:        const Color(0xFF5B7FA6).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF5B7FA6).withOpacity(0.4)),
              ),
              child: const Text('Back to Library',
                  style: TextStyle(color: Color(0xFF7BA7D4))),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EXIT HANDLING
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _handleBackPress() async {
    final settings = context.read<SettingsProvider>();

    // Save progress immediately before potentially leaving
    await context.read<ReaderProvider>().closeBook();

    if (!mounted) return;

    // If we haven't shown the exit confirmation yet, show it once
    if (!settings.exitConfirmShown) {
      final confirmed = await _showExitConfirmDialog();
      if (!mounted) return;

      if (confirmed == true) {
        // Mark that we've shown it — won't appear again
        await settings.markExitConfirmShown();
        if (mounted) Navigator.of(context).pop();
      }
      // If user cancelled: stay in the book (reopen the provider state)
      if (confirmed != true) {
        // Re-open the book in the provider to resume auto-save etc.
        context.read<ReaderProvider>().openBook(
            context.read<ReaderProvider>().currentBook ?? widget.book);
      }
    } else {
      // Exit confirmation already shown before — leave directly
      Navigator.of(context).pop();
    }
  }

  Future<bool?> _showExitConfirmDialog() {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF141E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Leave this book?',
            style: TextStyle(color: Color(0xFFD8E0EC))),
        content: const Text(
          'Your position is saved automatically. '
          'You\'ll return to exactly this page next time.\n\n'
          '(This message won\'t appear again.)',
          style: TextStyle(color: Color(0xFF7A8BA3), height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep reading',
                style: TextStyle(color: Color(0xFF5B7FA6))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave',
                style: TextStyle(
                    color:      Color(0xFFD8E0EC),
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TOOLBAR ACTIONS
  // ─────────────────────────────────────────────────────────────────────────

  void _addBookmark() {
    // Open the Annotations panel straight to the Bookmarks tab.
    // The panel itself has an "Add Bookmark Here" button at the bottom
    // that saves the current position and lets the user label it.
    _hideToolbar();
    setState(() {
      _annotationsVisible = true;
      _tocVisible         = false; // Close TOC if open
    });
  }

  void _openToc() {
    // Open the Table of Contents slide-in panel from the left edge.
    _hideToolbar();
    setState(() {
      _tocVisible         = true;
      _annotationsVisible = false; // Close annotations if open
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // JUMP TO POSITION (from TOC / Bookmarks / Highlights)
  // ─────────────────────────────────────────────────────────────────────────

  /// Navigates the EPUB or PDF to a specific chapter / page.
  /// Called by the TocPanel when the user taps a chapter title.
  void _jumpToChapter(int spineIndex) {
    final book = context.read<ReaderProvider>().currentBook ?? widget.book;
    if (book.format == BookFormat.epub && _epubController != null) {
      // EpubController.scrollTo() jumps to a spine index
      _epubController!.scrollTo(index: spineIndex);
    } else if (book.format == BookFormat.pdf && _pdfController != null) {
      // For PDFs, spine index = page number (1-based)
      _pdfController!.jumpToPage(spineIndex + 1);
    }
    // Update local progress to reflect the new position immediately
    final updated = (_progress ?? ReadingProgress(
      bookId:           widget.book.id,
      pageNumber:       1,
      totalPages:       _totalPages,
      progressFraction: 0,
      lastReadAt:       DateTime.now(),
    )).copyWith(
      spineIndex:       spineIndex,
      pageNumber:       spineIndex + 1,
      progressFraction: _totalPages > 1 ? spineIndex / _totalPages : 0.0,
      lastReadAt:       DateTime.now(),
    );
    setState(() => _progress = updated);
  }

  /// Navigates to a saved bookmark or highlight position.
  /// Called by BookmarksPanel when the user taps a bookmark / long-presses a highlight.
  void _jumpToAnnotation(int spineIndex, double scrollOffset, int pageNumber) {
    final book = context.read<ReaderProvider>().currentBook ?? widget.book;
    if (book.format == BookFormat.epub && _epubController != null) {
      _epubController!.scrollTo(index: spineIndex);
    } else if (book.format == BookFormat.pdf && _pdfController != null) {
      _pdfController!.jumpToPage(pageNumber);
    }
  }

  void _openReadingSettings() {
    _hideToolbar();
    final settings = context.read<SettingsProvider>();

    showModalBottomSheet(
      context:          context,
      backgroundColor:  Colors.transparent,
      isScrollControlled: true,    // Allows taller sheets
      useSafeArea:      true,
      builder: (_) => ReadingSettingsSheet(settings: settings),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // APP LIFECYCLE — pause/resume handling
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Save progress when the app goes to background
      context.read<ReaderProvider>().closeBook();
    }
  }
}
