/// reader_provider.dart
/// Manages ALL state for the Reader screen — the most complex part of the app.
///
/// Responsibilities:
///   - Loading and saving reading progress (position in the book)
///   - Auto-scroll: starting, pausing, speed control
///   - Toolbar visibility (shown/hidden on tap)
///   - Bookmarks for the current book
///   - Highlights for the current book
///   - Sleep timer countdown

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/database_service.dart';

class ReaderProvider extends ChangeNotifier {

  final DatabaseService _db = DatabaseService.instance;

  // ── Current book ──────────────────────────────────────────────────────────
  Book?            _currentBook;
  ReadingProgress? _progress;

  Book?            get currentBook => _currentBook;
  ReadingProgress? get progress    => _progress;

  // ── Toolbar visibility ────────────────────────────────────────────────────
  // The top/bottom toolbars hide automatically after a few seconds of no interaction
  bool _toolbarVisible = true;
  Timer? _toolbarHideTimer;

  bool get toolbarVisible => _toolbarVisible;

  // ── Auto-scroll state ─────────────────────────────────────────────────────
  bool   _autoScrollActive = false; // Is auto-scroll currently running?
  bool   _autoScrollPaused = false; // Is it paused (by a tap)?
  double _autoScrollSpeed  = 40.0;  // Pixels per second
  Timer? _autoScrollTimer;

  bool   get autoScrollActive => _autoScrollActive;
  bool   get autoScrollPaused => _autoScrollPaused;
  double get autoScrollSpeed  => _autoScrollSpeed;

  // The ScrollController for the scroll-mode reader.
  // The reader screen passes this in so we can control scrolling from here.
  ScrollController? _scrollController;

  // ── Bookmarks & Highlights for current book ───────────────────────────────
  List<Bookmark>  _bookmarks  = [];
  List<Highlight> _highlights = [];

  List<Bookmark>  get bookmarks  => List.unmodifiable(_bookmarks);
  List<Highlight> get highlights => List.unmodifiable(_highlights);

  // ── Sleep timer ───────────────────────────────────────────────────────────
  Timer? _sleepTimer;
  int    _sleepTimerRemainingSeconds = 0;
  bool   _sleepTimerExpired = false;

  int  get sleepTimerRemainingSeconds => _sleepTimerRemainingSeconds;
  bool get sleepTimerExpired          => _sleepTimerExpired;

  // ── Auto-save timer ───────────────────────────────────────────────────────
  // We save progress every 5 seconds to avoid losing position on app crash
  Timer? _autoSaveTimer;

  // ─────────────────────────────────────────────────────────────────────────
  // BOOK OPEN / CLOSE
  // ─────────────────────────────────────────────────────────────────────────

  /// Call this when the user opens a book. Loads saved progress and annotations.
  Future<void> openBook(Book book) async {
    _currentBook = book;

    // Load saved position
    _progress = await _db.getProgress(book.id);

    // Load all bookmarks and highlights for this book
    _bookmarks  = await _db.getBookmarks(book.id);
    _highlights = await _db.getHighlights(book.id);

    // Show toolbar initially when a book is opened
    _toolbarVisible = true;

    // Start the auto-save loop — saves position every 5 seconds
    _startAutoSave();

    notifyListeners();
  }

  /// Call this when the user leaves the book. Saves progress and cleans up timers.
  Future<void> closeBook() async {
    // Save final position before closing
    await _saveProgressNow();

    // Cancel all running timers to avoid memory leaks
    _autoSaveTimer?.cancel();
    _autoScrollTimer?.cancel();
    _sleepTimer?.cancel();
    _toolbarHideTimer?.cancel();

    _autoScrollActive = false;
    _autoScrollPaused = false;

    _currentBook = null;
    _progress    = null;
    _bookmarks   = [];
    _highlights  = [];

    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PROGRESS SAVING
  // ─────────────────────────────────────────────────────────────────────────

  /// Updates the in-memory progress. The auto-save timer will persist it.
  void updateProgress(ReadingProgress newProgress) {
    _progress = newProgress;
    // Don't call notifyListeners() here — it would cause a rebuild every frame
    // while scrolling. The status bar reads progress directly.
  }

  /// Immediately saves the current progress to the database.
  Future<void> _saveProgressNow() async {
    final p = _progress;
    if (p == null || _currentBook == null) return;
    await _db.saveProgress(p);
  }

  void _startAutoSave() {
    _autoSaveTimer?.cancel();
    // Save to database every 5 seconds while a book is open
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _saveProgressNow();
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TOOLBAR VISIBILITY
  // ─────────────────────────────────────────────────────────────────────────

  /// Toggles the toolbar. Called on screen tap in Page Mode.
  /// Automatically hides the toolbar after 3 seconds of inactivity.
  void toggleToolbar() {
    _toolbarVisible = !_toolbarVisible;
    notifyListeners();

    if (_toolbarVisible) {
      // Schedule auto-hide after 3 seconds
      _toolbarHideTimer?.cancel();
      _toolbarHideTimer = Timer(const Duration(seconds: 3), () {
        _toolbarVisible = false;
        notifyListeners();
      });
    }
  }

  /// Forces the toolbar to show and resets the auto-hide timer.
  void showToolbar() {
    _toolbarVisible = true;
    notifyListeners();
    _toolbarHideTimer?.cancel();
    _toolbarHideTimer = Timer(const Duration(seconds: 3), () {
      _toolbarVisible = false;
      notifyListeners();
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // AUTO-SCROLL CONTROLS
  // ─────────────────────────────────────────────────────────────────────────

  /// Attaches the scroll controller from the reader screen.
  /// Must be called before starting auto-scroll.
  void attachScrollController(ScrollController controller) {
    _scrollController = controller;
  }

  /// Starts auto-scroll at the current speed.
  void startAutoScroll() {
    if (_autoScrollActive && !_autoScrollPaused) return;

    _autoScrollActive = true;
    _autoScrollPaused = false;
    notifyListeners();

    _runScrollTick();
  }

  /// Pauses auto-scroll. A tap indicator (⏸) will show briefly.
  void pauseAutoScroll() {
    if (!_autoScrollActive) return;
    _autoScrollPaused = true;
    _autoScrollTimer?.cancel();
    notifyListeners();
  }

  /// Resumes auto-scroll from pause.
  void resumeAutoScroll() {
    if (!_autoScrollActive || !_autoScrollPaused) return;
    _autoScrollPaused = false;
    notifyListeners();
    _runScrollTick();
  }

  /// Toggles pause/resume with a single tap (the main gesture in scroll mode).
  void toggleAutoScrollPause() {
    if (_autoScrollPaused) {
      resumeAutoScroll();
    } else {
      pauseAutoScroll();
    }
  }

  /// Stops auto-scroll entirely (different from pause — turns it off).
  void stopAutoScroll() {
    _autoScrollActive = false;
    _autoScrollPaused = false;
    _autoScrollTimer?.cancel();
    notifyListeners();
  }

  /// Increases scroll speed by 10 pixels/second.
  /// [inverted] — if true, this action was triggered by Volume Up in inverted mode.
  void increaseScrollSpeed({bool inverted = false}) {
    final delta = inverted ? -10.0 : 10.0;
    _autoScrollSpeed = (_autoScrollSpeed + delta).clamp(10.0, 200.0);
    notifyListeners();
  }

  /// Decreases scroll speed by 10 pixels/second.
  void decreaseScrollSpeed({bool inverted = false}) {
    final delta = inverted ? -10.0 : 10.0;
    _autoScrollSpeed = (_autoScrollSpeed - delta).clamp(10.0, 200.0);
    notifyListeners();
  }

  /// The scroll engine — fires every 16ms (~60fps) and moves the page down.
  void _runScrollTick() {
    _autoScrollTimer?.cancel();
    // 16ms ≈ one frame at 60fps — this gives smooth scrolling
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (_autoScrollPaused || !_autoScrollActive) {
        timer.cancel();
        return;
      }

      final sc = _scrollController;
      if (sc == null || !sc.hasClients) return;

      // How many pixels to move this frame:
      // speed (px/s) × time per frame (s) = pixels per frame
      final pixelsPerFrame = _autoScrollSpeed * (16 / 1000);
      final newOffset      = sc.offset + pixelsPerFrame;

      // Stop if we've reached the end of the book
      if (newOffset >= sc.position.maxScrollExtent) {
        sc.jumpTo(sc.position.maxScrollExtent);
        stopAutoScroll();
        return;
      }

      // Move the scroll position without animation (jumps each frame for performance)
      sc.jumpTo(newOffset);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SLEEP TIMER
  // ─────────────────────────────────────────────────────────────────────────

  /// Starts the sleep timer countdown for [minutes] minutes.
  void startSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    _sleepTimerExpired  = false;
    _sleepTimerRemainingSeconds = minutes * 60;
    notifyListeners();

    // Tick every second, counting down
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _sleepTimerRemainingSeconds--;

      if (_sleepTimerRemainingSeconds <= 0) {
        timer.cancel();
        _sleepTimerExpired = true;
        // Also pause auto-scroll if active
        if (_autoScrollActive) pauseAutoScroll();
      }

      notifyListeners();
    });
  }

  /// Resets the sleep timer (called when the user interacts with the screen).
  void resetSleepTimer(int minutes) {
    if (_sleepTimerRemainingSeconds > 0 || _sleepTimerExpired) {
      _sleepTimerExpired = false;
      startSleepTimer(minutes);
    }
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimerRemainingSeconds = 0;
    _sleepTimerExpired = false;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BOOKMARKS
  // ─────────────────────────────────────────────────────────────────────────

  /// Adds a bookmark at the current reading position.
  Future<void> addBookmark({
    required String label,
    required String textSnippet,
  }) async {
    if (_currentBook == null || _progress == null) return;

    final bookmark = Bookmark(
      id:           DateTime.now().microsecondsSinceEpoch.toString(),
      bookId:       _currentBook!.id,
      spineIndex:   _progress!.spineIndex,
      scrollOffset: _progress!.scrollOffset,
      pageNumber:   _progress!.pageNumber,
      label:        label,
      textSnippet:  textSnippet,
      createdAt:    DateTime.now(),
    );

    await _db.addBookmark(bookmark);
    _bookmarks.add(bookmark);
    notifyListeners();
  }

  /// Removes a bookmark by its ID.
  Future<void> removeBookmark(String bookmarkId) async {
    await _db.deleteBookmark(bookmarkId);
    _bookmarks.removeWhere((b) => b.id == bookmarkId);
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HIGHLIGHTS
  // ─────────────────────────────────────────────────────────────────────────

  /// Adds a new highlight for the currently selected text.
  Future<void> addHighlight({
    required String selectedText,
    required HighlightColor color,
    required int startOffset,
    required int endOffset,
    String note = '',
  }) async {
    if (_currentBook == null || _progress == null) return;

    final highlight = Highlight(
      id:           DateTime.now().microsecondsSinceEpoch.toString(),
      bookId:       _currentBook!.id,
      spineIndex:   _progress!.spineIndex,
      pageNumber:   _progress!.pageNumber,
      selectedText: selectedText,
      note:         note,
      color:        color,
      startOffset:  startOffset,
      endOffset:    endOffset,
      createdAt:    DateTime.now(),
    );

    await _db.addHighlight(highlight);
    _highlights.add(highlight);
    notifyListeners();
  }

  /// Updates the note or colour of an existing highlight.
  Future<void> updateHighlight(String highlightId, {
    String?         note,
    HighlightColor? color,
  }) async {
    final fields = <String, dynamic>{};
    if (note  != null) fields['note']  = note;
    if (color != null) fields['color'] = color.name;
    if (fields.isEmpty) return;

    await _db.updateHighlight(highlightId, fields);

    final idx = _highlights.indexWhere((h) => h.id == highlightId);
    if (idx >= 0) {
      _highlights[idx] = _highlights[idx].copyWith(note: note, color: color);
      notifyListeners();
    }
  }

  /// Removes a highlight.
  Future<void> removeHighlight(String highlightId) async {
    await _db.deleteHighlight(highlightId);
    _highlights.removeWhere((h) => h.id == highlightId);
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CLEANUP
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _autoScrollTimer?.cancel();
    _sleepTimer?.cancel();
    _toolbarHideTimer?.cancel();
    super.dispose();
  }
}
