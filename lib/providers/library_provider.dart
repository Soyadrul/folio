/// library_provider.dart
/// Manages the state of the book library:
///   - scanning folders for book files
///   - storing/loading books via the DatabaseService
///   - sorting and filtering books for the Library screen
///
/// This provider acts as the "brain" of the Library screen —
/// the screen itself just reads data from here and displays it.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../models/models.dart';
import '../services/database_service.dart';

/// How the library is currently sorted.
enum LibrarySortOrder {
  titleAZ,       // Alphabetical A → Z
  titleZA,       // Alphabetical Z → A
  authorAZ,      // By author name A → Z
  lastRead,      // Most recently opened first
  recentlyAdded, // Most recently added to the library first
}

/// Whether to show books as a grid (covers) or a list (title + author rows).
enum LibraryViewMode { grid, list }

class LibraryProvider extends ChangeNotifier {

  final DatabaseService _db = DatabaseService.instance;

  // ── State ─────────────────────────────────────────────────────────────────
  List<Book>       _allBooks    = [];    // All books from the database
  bool             _isScanning  = false; // True while the folder scan is running
  String           _scanStatus  = '';    // Status message shown during scan
  LibrarySortOrder _sortOrder   = LibrarySortOrder.titleAZ;
  LibraryViewMode  _viewMode    = LibraryViewMode.grid;
  String           _searchQuery = '';    // Current text in the search bar

  // ── Public getters ────────────────────────────────────────────────────────
  bool             get isScanning  => _isScanning;
  String           get scanStatus  => _scanStatus;
  LibrarySortOrder get sortOrder   => _sortOrder;
  LibraryViewMode  get viewMode    => _viewMode;
  String           get searchQuery => _searchQuery;

  /// Returns the filtered and sorted list of books for display.
  /// "Continue reading" books (those with progress > 0 and < 100%) are
  /// sorted to the top when there's no active search query.
  List<Book> get displayedBooks {
    // Step 1: Apply search filter
    var books = _searchQuery.isEmpty
        ? List<Book>.from(_allBooks)
        : _allBooks.where((b) {
            final q = _searchQuery.toLowerCase();
            return b.title.toLowerCase().contains(q) ||
                   b.author.toLowerCase().contains(q);
          }).toList();

    // Step 2: Sort
    books.sort(_buildComparator());

    return books;
  }

  /// Returns books that are currently in progress (started but not finished).
  /// Shown in the "Continue Reading" strip at the top of the library.
  List<Book> get continueReadingBooks => _allBooks
      .where((b) => b.startedReadingAt != null && b.finishedReadingAt == null)
      .toList();

  /// Total number of books in the library.
  int get bookCount => _allBooks.length;

  // ─────────────────────────────────────────────────────────────────────────
  // INITIALISATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Loads books from the database. Call once when the app starts.
  Future<void> loadBooks() async {
    _allBooks = await _db.getAllBooks();
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FOLDER SCANNING
  // Recursively walks through the selected folders and finds all book files.
  // ─────────────────────────────────────────────────────────────────────────

  /// Scans all folders in [folderPaths] for EPUB, PDF, and TXT files.
  /// Updates [_isScanning] and [_scanStatus] so the UI can show a progress indicator.
  Future<void> scanFolders(List<String> folderPaths) async {
    if (folderPaths.isEmpty) return;

    _isScanning = true;
    _scanStatus = 'Starting scan...';
    notifyListeners();

    try {
      // Collect all valid book file paths found during the scan
      final foundFilePaths = <String>[];

      for (final folderPath in folderPaths) {
        _scanStatus = 'Scanning $folderPath...';
        notifyListeners();

        final dir = Directory(folderPath);
        if (!await dir.exists()) continue;

        // Walk the directory tree recursively
        // recursive: true means it goes into subfolders automatically
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          // We only care about files, not sub-directories
          if (entity is! File) continue;

          final ext = p.extension(entity.path).toLowerCase();
          if (ext == '.epub' || ext == '.pdf' || ext == '.txt') {
            foundFilePaths.add(entity.path);
          }
        }
      }

      _scanStatus = 'Found ${foundFilePaths.length} books. Processing...';
      notifyListeners();

      // Get the IDs of books already in the database so we can skip them
      final existingIds = await _db.getAllBookIds();

      int processed = 0;
      for (final filePath in foundFilePaths) {
        // Use the file path as the unique ID
        final bookId = filePath;

        // Skip books that are already in the database — no need to re-parse them
        if (existingIds.contains(bookId)) {
          processed++;
          continue;
        }

        // Create a minimal Book record from the file system info.
        // Full metadata (title, author, cover) will be extracted by the
        // respective services (EpubService / PdfService) when the book is first opened.
        final file     = File(filePath);
        final stat     = await file.stat();
        final filename = p.basenameWithoutExtension(filePath);
        final ext      = p.extension(filePath).toLowerCase();

        final format = ext == '.epub'
            ? BookFormat.epub
            : ext == '.pdf'
                ? BookFormat.pdf
                : BookFormat.txt;

        final book = Book(
          id:            bookId,
          title:         filename, // Will be replaced with real metadata on first open
          author:        '',
          filePath:      filePath,
          format:        format,
          fileSizeBytes: stat.size,
          addedAt:       DateTime.now(),
        );

        await _db.upsertBook(book);

        processed++;
        _scanStatus = 'Processing $processed / ${foundFilePaths.length}...';
        notifyListeners();
      }

      // Reload the full book list from the database now that scanning is done
      _allBooks = await _db.getAllBooks();

    } catch (e) {
      _scanStatus = 'Scan error: $e';
    } finally {
      _isScanning = false;
      _scanStatus = '';
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BOOK UPDATES
  // ─────────────────────────────────────────────────────────────────────────

  /// Updates a book's metadata after it has been fully parsed on first open.
  /// This is called by EpubService/PdfService after extracting title, author, etc.
  Future<void> updateBookMetadata(Book updatedBook) async {
    await _db.upsertBook(updatedBook);
    // Replace the old entry in the local list
    final idx = _allBooks.indexWhere((b) => b.id == updatedBook.id);
    if (idx >= 0) {
      _allBooks[idx] = updatedBook;
      notifyListeners();
    }
  }

  /// Called when the user opens a book — increments the open counter and
  /// sets the started reading date if not already set (and not locked).
  Future<void> onBookOpened(String bookId) async {
    final book = await _db.getBook(bookId);
    if (book == null) return;

    final now = DateTime.now();
    final fields = <String, dynamic>{
      'open_count': book.openCount + 1,
    };

    // Set the "started" date only if it's not set yet, AND not locked
    if (book.startedReadingAt == null && !book.readingDatesLocked) {
      fields['started_at'] = now.toIso8601String();
    }

    await _db.updateBook(bookId, fields);

    // Refresh local copy
    final updated = await _db.getBook(bookId);
    if (updated != null) {
      final idx = _allBooks.indexWhere((b) => b.id == bookId);
      if (idx >= 0) {
        _allBooks[idx] = updated;
        notifyListeners();
      }
    }
  }

  /// Called when the user reaches the last page of a book.
  /// Sets the "finished" date if not locked.
  Future<void> onBookFinished(String bookId) async {
    final book = await _db.getBook(bookId);
    if (book == null || book.readingDatesLocked) return;

    await _db.updateBook(bookId, {
      'finished_at': DateTime.now().toIso8601String(),
    });

    final updated = await _db.getBook(bookId);
    if (updated != null) {
      final idx = _allBooks.indexWhere((b) => b.id == bookId);
      if (idx >= 0) {
        _allBooks[idx] = updated;
        notifyListeners();
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SORT & VIEW
  // ─────────────────────────────────────────────────────────────────────────

  void setSortOrder(LibrarySortOrder order) {
    _sortOrder = order;
    notifyListeners();
  }

  void setViewMode(LibraryViewMode mode) {
    _viewMode = mode;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PROGRESS CACHE
  // ReadingProgress is loaded from the DB for library card display.
  // We keep an in-memory cache so cards don't all fire DB queries simultaneously.
  // ─────────────────────────────────────────────────────────────────────────

  /// In-memory map of bookId → ReadingProgress for books we've already loaded.
  final Map<String, ReadingProgress?> _progressCache = {};

  /// Returns the cached ReadingProgress for [bookId], or null if not yet loaded.
  /// Triggers an async load if not in cache — the card rebuilds when it arrives.
  ReadingProgress? getProgress(String bookId) {
    if (_progressCache.containsKey(bookId)) {
      return _progressCache[bookId];
    }
    // Start async load — don't await here; just notify listeners when done
    _loadProgressForBook(bookId);
    return null;
  }

  Future<void> _loadProgressForBook(String bookId) async {
    // Mark as "loading" so we don't fire duplicate requests
    _progressCache[bookId] = null;
    final progress = await _db.getProgress(bookId);
    _progressCache[bookId] = progress;
    notifyListeners();
  }

  /// Clears the cached progress for [bookId].
  /// Call this after resetting a book's progress so the card shows 0%.
  void clearProgressCache(String bookId) {
    _progressCache.remove(bookId);
    notifyListeners();
  }

  /// Warms up the progress cache for all currently displayed books.
  /// Called by the library screen after a scan completes.
  Future<void> preloadProgress() async {
    for (final book in _allBooks) {
      if (!_progressCache.containsKey(book.id)) {
        _progressCache[book.id] = await _db.getProgress(book.id);
      }
    }
    notifyListeners();
  }

  /// Builds a comparator function based on the current sort order.
  Comparator<Book> _buildComparator() {
    switch (_sortOrder) {
      case LibrarySortOrder.titleAZ:
        return (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase());
      case LibrarySortOrder.titleZA:
        return (a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase());
      case LibrarySortOrder.authorAZ:
        return (a, b) => a.author.toLowerCase().compareTo(b.author.toLowerCase());
      case LibrarySortOrder.lastRead:
        return (a, b) {
          // Books never opened go to the bottom
          if (a.startedReadingAt == null) return 1;
          if (b.startedReadingAt == null) return -1;
          return b.startedReadingAt!.compareTo(a.startedReadingAt!);
        };
      case LibrarySortOrder.recentlyAdded:
        return (a, b) => b.addedAt.compareTo(a.addedAt);
    }
  }
}
