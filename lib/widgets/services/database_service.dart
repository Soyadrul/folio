/// database_service.dart
/// Manages the local SQLite database — the app's "memory" that persists
/// everything between sessions: books, reading progress, bookmarks, highlights.
///
/// SQLite is a lightweight database that lives as a single file on the device.
/// We use the 'sqflite' Flutter package to interact with it.
///
/// Tables:
///   books            — one row per book file found on the device
///   reading_progress — one row per book (the user's last reading position)
///   bookmarks        — many rows per book (each saved position)
///   highlights       — many rows per book (each highlighted passage)

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'models.dart';

class DatabaseService {
  // ── Singleton pattern ─────────────────────────────────────────────────────
  // We only ever want ONE database connection open at a time.
  // The singleton pattern ensures only one DatabaseService instance exists.
  DatabaseService._internal();
  static final DatabaseService instance = DatabaseService._internal();
  factory DatabaseService() => instance;

  // The actual database connection — null until initialised
  Database? _db;

  // ─────────────────────────────────────────────────────────────────────────
  // INITIALISATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Opens (or creates) the database file.
  /// Call once at app startup. Safe to call multiple times — returns cached db.
  Future<Database> get database async {
    // Return existing connection if already open
    if (_db != null) return _db!;

    // Build the path to the database file on the device
    // getDatabasesPath() returns the standard app database directory
    final dbPath = p.join(await getDatabasesPath(), 'ebook_reader.db');

    // Open the database, creating it and its tables if it doesn't exist yet
    _db = await openDatabase(
      dbPath,
      version: 1,               // Increment this when the schema changes
      onCreate: _createTables,
      onUpgrade: _onUpgrade,    // Called when version number increases
    );

    return _db!;
  }

  /// Creates all database tables on first launch.
  /// Each CREATE TABLE statement defines the columns and their types.
  Future<void> _createTables(Database db, int version) async {
    // ── books table ──────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE books (
        id                TEXT PRIMARY KEY,
        title             TEXT NOT NULL,
        author            TEXT,
        file_path         TEXT NOT NULL UNIQUE,
        format            INTEGER NOT NULL,
        description       TEXT,
        publisher         TEXT,
        language          TEXT,
        cover_bytes       BLOB,
        file_size         INTEGER,
        added_at          TEXT NOT NULL,
        started_at        TEXT,
        finished_at       TEXT,
        dates_locked      INTEGER DEFAULT 0,
        open_count        INTEGER DEFAULT 0
      )
    ''');

    // ── reading_progress table ────────────────────────────────────────────
    // One row per book. When the user reads, we UPDATE this row (not insert).
    await db.execute('''
      CREATE TABLE reading_progress (
        book_id           TEXT PRIMARY KEY,
        spine_index       INTEGER DEFAULT 0,
        scroll_offset     REAL    DEFAULT 0.0,
        page_number       INTEGER DEFAULT 1,
        total_pages       INTEGER DEFAULT 1,
        progress_fraction REAL    DEFAULT 0.0,
        last_read_at      TEXT    NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
      )
    ''');

    // ── bookmarks table ───────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE bookmarks (
        id            TEXT PRIMARY KEY,
        book_id       TEXT NOT NULL,
        spine_index   INTEGER DEFAULT 0,
        scroll_offset REAL    DEFAULT 0.0,
        page_number   INTEGER DEFAULT 1,
        label         TEXT,
        text_snippet  TEXT,
        created_at    TEXT NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
      )
    ''');

    // ── highlights table ──────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE highlights (
        id            TEXT PRIMARY KEY,
        book_id       TEXT NOT NULL,
        spine_index   INTEGER DEFAULT 0,
        page_number   INTEGER DEFAULT 1,
        selected_text TEXT NOT NULL,
        note          TEXT,
        color         TEXT NOT NULL,
        start_offset  INTEGER DEFAULT 0,
        end_offset    INTEGER DEFAULT 0,
        created_at    TEXT NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
      )
    ''');
  }

  /// Called when the database version number is bumped.
  /// Add ALTER TABLE statements here when you need to add columns in updates.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Example: if (oldVersion < 2) { await db.execute('ALTER TABLE ...'); }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BOOK OPERATIONS
  // ─────────────────────────────────────────────────────────────────────────

  /// Saves a book to the database.
  /// If a book with the same file path already exists, we update it instead.
  Future<void> upsertBook(Book book) async {
    final db = await database;
    await db.insert(
      'books',
      book.toMap(),
      // conflictAlgorithm: replace means "if id already exists, overwrite"
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns ALL books from the database, sorted by title alphabetically.
  Future<List<Book>> getAllBooks() async {
    final db   = await database;
    final rows = await db.query('books', orderBy: 'title ASC');
    return rows.map(Book.fromMap).toList();
  }

  /// Returns a single book by its ID, or null if not found.
  Future<Book?> getBook(String bookId) async {
    final db   = await database;
    final rows = await db.query('books', where: 'id = ?', whereArgs: [bookId]);
    if (rows.isEmpty) return null;
    return Book.fromMap(rows.first);
  }

  /// Updates specific fields of a book without touching the rest.
  Future<void> updateBook(String bookId, Map<String, dynamic> fields) async {
    final db = await database;
    await db.update('books', fields, where: 'id = ?', whereArgs: [bookId]);
  }

  /// Removes a book and all its progress/bookmarks/highlights from the database.
  /// The ON DELETE CASCADE in the schema handles deleting related rows automatically.
  Future<void> deleteBook(String bookId) async {
    final db = await database;
    await db.delete('books', where: 'id = ?', whereArgs: [bookId]);
  }

  /// Returns the IDs of all books currently in the database.
  /// Used by the scanner to detect which books have been removed from the device.
  Future<Set<String>> getAllBookIds() async {
    final db   = await database;
    final rows = await db.query('books', columns: ['id']);
    return rows.map((r) => r['id'] as String).toSet();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // READING PROGRESS OPERATIONS
  // ─────────────────────────────────────────────────────────────────────────

  /// Saves or updates the reading position for a book.
  /// This is called every few seconds while the user is reading.
  Future<void> saveProgress(ReadingProgress progress) async {
    final db = await database;
    await db.insert(
      'reading_progress',
      progress.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieves the last saved position for a book.
  /// Returns null if the book has never been opened.
  Future<ReadingProgress?> getProgress(String bookId) async {
    final db   = await database;
    final rows = await db.query(
      'reading_progress',
      where:     'book_id = ?',
      whereArgs: [bookId],
    );
    if (rows.isEmpty) return null;
    return ReadingProgress.fromMap(rows.first);
  }

  /// Resets progress for a book (e.g. when the user wants to start over).
  Future<void> deleteProgress(String bookId) async {
    final db = await database;
    await db.delete(
      'reading_progress',
      where:     'book_id = ?',
      whereArgs: [bookId],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BOOKMARK OPERATIONS
  // ─────────────────────────────────────────────────────────────────────────

  /// Saves a new bookmark.
  Future<void> addBookmark(Bookmark bookmark) async {
    final db = await database;
    await db.insert('bookmarks', bookmark.toMap());
  }

  /// Returns all bookmarks for a given book, sorted oldest → newest.
  Future<List<Bookmark>> getBookmarks(String bookId) async {
    final db   = await database;
    final rows = await db.query(
      'bookmarks',
      where:     'book_id = ?',
      whereArgs: [bookId],
      orderBy:   'created_at ASC',
    );
    return rows.map(Bookmark.fromMap).toList();
  }

  /// Deletes a bookmark by its ID.
  Future<void> deleteBookmark(String bookmarkId) async {
    final db = await database;
    await db.delete('bookmarks', where: 'id = ?', whereArgs: [bookmarkId]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HIGHLIGHT OPERATIONS
  // ─────────────────────────────────────────────────────────────────────────

  /// Saves a new highlight.
  Future<void> addHighlight(Highlight highlight) async {
    final db = await database;
    await db.insert('highlights', highlight.toMap());
  }

  /// Returns all highlights for a given book.
  Future<List<Highlight>> getHighlights(String bookId) async {
    final db   = await database;
    final rows = await db.query(
      'highlights',
      where:     'book_id = ?',
      whereArgs: [bookId],
      orderBy:   'created_at ASC',
    );
    return rows.map(Highlight.fromMap).toList();
  }

  /// Updates the note or colour of an existing highlight.
  Future<void> updateHighlight(String highlightId, Map<String, dynamic> fields) async {
    final db = await database;
    await db.update('highlights', fields, where: 'id = ?', whereArgs: [highlightId]);
  }

  /// Deletes a highlight by its ID.
  Future<void> deleteHighlight(String highlightId) async {
    final db = await database;
    await db.delete('highlights', where: 'id = ?', whereArgs: [highlightId]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CLEANUP
  // ─────────────────────────────────────────────────────────────────────────

  /// Closes the database connection. Called when the app is terminating.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
