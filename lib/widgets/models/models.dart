/// models.dart
/// All data models for the eBook Reader in a single file.
/// Each model represents one "thing" the app needs to store and track:
///
///   Book            — a book found on the device (metadata + file path)
///   ReadingProgress — how far the user has read in a specific book
///   Bookmark        — a saved position in a book (like a physical bookmark)
///   Highlight       — a highlighted passage with an optional note
///
/// All models have:
///   - A fromMap()  constructor so they can be loaded from the SQLite database
///   - A toMap()    method       so they can be saved to   the SQLite database

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENUMS
// ─────────────────────────────────────────────────────────────────────────────

/// The file format of the book.
enum BookFormat { epub, pdf, txt }

/// The four highlight colours available when the user selects text.
enum HighlightColor { yellow, green, blue, pink }

// Helper to convert HighlightColor to a Flutter Color for rendering
extension HighlightColorExt on HighlightColor {
  Color get color {
    switch (this) {
      case HighlightColor.yellow: return const Color(0xFFFFF176);
      case HighlightColor.green:  return const Color(0xFFA5D6A7);
      case HighlightColor.blue:   return const Color(0xFF90CAF9);
      case HighlightColor.pink:   return const Color(0xFFF48FB1);
    }
  }

  String get name {
    switch (this) {
      case HighlightColor.yellow: return 'yellow';
      case HighlightColor.green:  return 'green';
      case HighlightColor.blue:   return 'blue';
      case HighlightColor.pink:   return 'pink';
    }
  }

  static HighlightColor fromString(String s) {
    return HighlightColor.values.firstWhere(
      (c) => c.name == s,
      orElse: () => HighlightColor.yellow,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOOK MODEL
// ─────────────────────────────────────────────────────────────────────────────

/// Represents a single book file found on the device.
/// This is what the Library screen displays as a card/row.
class Book {
  /// A unique identifier — we use the full file path as the ID
  /// because no two files can have the same path on a device
  final String id;

  /// The display title (from file metadata, or filename if metadata is missing)
  final String title;

  /// The author's name (from metadata, or empty string if unknown)
  final String author;

  /// Full path to the file on the device (e.g. /storage/emulated/0/Books/mybook.epub)
  final String filePath;

  /// Whether this is an EPUB, PDF, or TXT file
  final BookFormat format;

  /// The book description / back-cover blurb (from metadata)
  final String description;

  /// The publisher name (from metadata)
  final String publisher;

  /// The language of the book (from metadata, e.g. "en", "it")
  final String language;

  /// Raw bytes of the cover image, extracted from the book file.
  /// Null if the book has no embedded cover.
  final List<int>? coverBytes;

  /// File size in bytes — shown on the detail screen
  final int fileSizeBytes;

  /// When this book was first added to the library (scanned for the first time)
  final DateTime addedAt;

  // ── Reading date tracking ─────────────────────────────────────────────────

  /// When the user first opened this book. Null until first open.
  final DateTime? startedReadingAt;

  /// When the user reached the last page. Null until completion.
  final DateTime? finishedReadingAt;

  /// If true, startedReadingAt and finishedReadingAt are "locked" and
  /// will NOT be overwritten even if the user re-reads the book.
  final bool readingDatesLocked;

  /// How many times this book has been opened (for the metadata screen)
  final int openCount;

  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.filePath,
    required this.format,
    this.description        = '',
    this.publisher          = '',
    this.language           = '',
    this.coverBytes,
    this.fileSizeBytes      = 0,
    required this.addedAt,
    this.startedReadingAt,
    this.finishedReadingAt,
    this.readingDatesLocked = false,
    this.openCount          = 0,
  });

  /// Creates a Book from a database row (a Map of column → value)
  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id:                  map['id']            as String,
      title:               map['title']         as String,
      author:              map['author']        as String? ?? '',
      filePath:            map['file_path']     as String,
      format:              BookFormat.values[map['format'] as int],
      description:         map['description']  as String? ?? '',
      publisher:           map['publisher']    as String? ?? '',
      language:            map['language']     as String? ?? '',
      // Cover bytes are stored as a BLOB in SQLite
      coverBytes: map['cover_bytes'] != null
          ? List<int>.from(map['cover_bytes'] as List)
          : null,
      fileSizeBytes:       map['file_size']    as int? ?? 0,
      addedAt:             DateTime.parse(map['added_at'] as String),
      startedReadingAt:    map['started_at'] != null
          ? DateTime.parse(map['started_at'] as String)
          : null,
      finishedReadingAt:   map['finished_at'] != null
          ? DateTime.parse(map['finished_at'] as String)
          : null,
      readingDatesLocked:  (map['dates_locked'] as int? ?? 0) == 1,
      openCount:           map['open_count']   as int? ?? 0,
    );
  }

  /// Converts this Book to a Map for storing in the database
  Map<String, dynamic> toMap() {
    return {
      'id':           id,
      'title':        title,
      'author':       author,
      'file_path':    filePath,
      'format':       format.index,
      'description':  description,
      'publisher':    publisher,
      'language':     language,
      'cover_bytes':  coverBytes,
      'file_size':    fileSizeBytes,
      'added_at':     addedAt.toIso8601String(),
      'started_at':   startedReadingAt?.toIso8601String(),
      'finished_at':  finishedReadingAt?.toIso8601String(),
      'dates_locked': readingDatesLocked ? 1 : 0,
      'open_count':   openCount,
    };
  }

  /// Creates a copy of this Book with specific fields changed.
  /// Used when we need to update just one or two fields without rebuilding everything.
  Book copyWith({
    String?    title,
    String?    author,
    String?    description,
    List<int>? coverBytes,
    DateTime?  startedReadingAt,
    DateTime?  finishedReadingAt,
    bool?      readingDatesLocked,
    int?       openCount,
    // Use a special sentinel to allow setting nullable fields to null
    bool       clearStartedAt  = false,
    bool       clearFinishedAt = false,
  }) {
    return Book(
      id:                  id,
      title:               title               ?? this.title,
      author:              author              ?? this.author,
      filePath:            filePath,
      format:              format,
      description:         description         ?? this.description,
      publisher:           publisher,
      language:            language,
      coverBytes:          coverBytes          ?? this.coverBytes,
      fileSizeBytes:       fileSizeBytes,
      addedAt:             addedAt,
      startedReadingAt:    clearStartedAt  ? null : (startedReadingAt  ?? this.startedReadingAt),
      finishedReadingAt:   clearFinishedAt ? null : (finishedReadingAt ?? this.finishedReadingAt),
      readingDatesLocked:  readingDatesLocked  ?? this.readingDatesLocked,
      openCount:           openCount           ?? this.openCount,
    );
  }

  /// Converts the format enum to a user-friendly display string
  String get formatDisplayName {
    switch (format) {
      case BookFormat.epub: return 'EPUB';
      case BookFormat.pdf:  return 'PDF';
      case BookFormat.txt:  return 'TXT';
    }
  }

  /// Converts file size bytes to a human-readable string (e.g. "2.4 MB")
  String get fileSizeDisplay {
    if (fileSizeBytes < 1024) return '${fileSizeBytes} B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// READING PROGRESS MODEL
// ─────────────────────────────────────────────────────────────────────────────

/// Tracks exactly how far the user has read in a specific book.
/// There is one ReadingProgress record per book in the database.
class ReadingProgress {
  /// The book this progress record belongs to (matches Book.id)
  final String bookId;

  // ── EPUB-specific position ────────────────────────────────────────────────
  // EPUB books are divided into "spine items" (usually chapters).
  // We track both which chapter (spineIndex) and how far within it (scrollOffset)

  /// Index of the current chapter in the EPUB spine (0 = first chapter)
  final int spineIndex;

  /// Scroll offset within the current chapter, in pixels from the top
  final double scrollOffset;

  // ── PDF-specific position ─────────────────────────────────────────────────
  /// Current page number (1-based, so first page = 1)
  final int pageNumber;

  /// Total number of pages in the PDF (used to calculate percentage)
  final int totalPages;

  /// Progress as a fraction from 0.0 (start) to 1.0 (end)
  /// Calculated differently for EPUB (spine + scroll) vs PDF (pageNumber / totalPages)
  final double progressFraction;

  /// When this progress was last saved (shown in "last read" display)
  final DateTime lastReadAt;

  const ReadingProgress({
    required this.bookId,
    this.spineIndex       = 0,
    this.scrollOffset     = 0.0,
    this.pageNumber       = 1,
    this.totalPages       = 1,
    this.progressFraction = 0.0,
    required this.lastReadAt,
  });

  factory ReadingProgress.fromMap(Map<String, dynamic> map) {
    return ReadingProgress(
      bookId:           map['book_id']           as String,
      spineIndex:       map['spine_index']        as int?    ?? 0,
      scrollOffset:     (map['scroll_offset']     as num?)?.toDouble() ?? 0.0,
      pageNumber:       map['page_number']        as int?    ?? 1,
      totalPages:       map['total_pages']        as int?    ?? 1,
      progressFraction: (map['progress_fraction'] as num?)?.toDouble() ?? 0.0,
      lastReadAt:       DateTime.parse(map['last_read_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'book_id':           bookId,
      'spine_index':       spineIndex,
      'scroll_offset':     scrollOffset,
      'page_number':       pageNumber,
      'total_pages':       totalPages,
      'progress_fraction': progressFraction,
      'last_read_at':      lastReadAt.toIso8601String(),
    };
  }

  /// Returns a nicely formatted percentage string, e.g. "42%"
  String get percentageDisplay => '${(progressFraction * 100).round()}%';

  ReadingProgress copyWith({
    int?      spineIndex,
    double?   scrollOffset,
    int?      pageNumber,
    int?      totalPages,
    double?   progressFraction,
    DateTime? lastReadAt,
  }) {
    return ReadingProgress(
      bookId:           bookId,
      spineIndex:       spineIndex       ?? this.spineIndex,
      scrollOffset:     scrollOffset     ?? this.scrollOffset,
      pageNumber:       pageNumber       ?? this.pageNumber,
      totalPages:       totalPages       ?? this.totalPages,
      progressFraction: progressFraction ?? this.progressFraction,
      lastReadAt:       lastReadAt       ?? this.lastReadAt,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOOKMARK MODEL
// ─────────────────────────────────────────────────────────────────────────────

/// A user-saved position in a book — like a physical bookmark.
/// Bookmarks can have an optional label (e.g. "Important scene").
class Bookmark {
  /// Unique ID for this bookmark (generated when saved)
  final String id;

  /// The book this bookmark belongs to
  final String bookId;

  /// For EPUB: which chapter (spine index) the bookmark is in
  final int spineIndex;

  /// For EPUB: scroll offset within the chapter
  final double scrollOffset;

  /// For PDF: which page the bookmark is on
  final int pageNumber;

  /// An optional label the user can type when creating the bookmark
  final String label;

  /// A short excerpt of text near the bookmark, for context in the bookmarks panel
  final String textSnippet;

  /// When the bookmark was created
  final DateTime createdAt;

  const Bookmark({
    required this.id,
    required this.bookId,
    this.spineIndex   = 0,
    this.scrollOffset = 0.0,
    this.pageNumber   = 1,
    this.label        = '',
    this.textSnippet  = '',
    required this.createdAt,
  });

  factory Bookmark.fromMap(Map<String, dynamic> map) {
    return Bookmark(
      id:           map['id']            as String,
      bookId:       map['book_id']       as String,
      spineIndex:   map['spine_index']   as int?    ?? 0,
      scrollOffset: (map['scroll_offset'] as num?)?.toDouble() ?? 0.0,
      pageNumber:   map['page_number']   as int?    ?? 1,
      label:        map['label']         as String? ?? '',
      textSnippet:  map['text_snippet']  as String? ?? '',
      createdAt:    DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id':            id,
      'book_id':       bookId,
      'spine_index':   spineIndex,
      'scroll_offset': scrollOffset,
      'page_number':   pageNumber,
      'label':         label,
      'text_snippet':  textSnippet,
      'created_at':    createdAt.toIso8601String(),
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HIGHLIGHT MODEL
// ─────────────────────────────────────────────────────────────────────────────

/// A highlighted text passage, optionally annotated with a note.
/// Created when the user long-presses and selects text while reading.
class Highlight {
  /// Unique ID for this highlight
  final String id;

  /// The book this highlight belongs to
  final String bookId;

  /// For EPUB: which chapter the highlighted text is in
  final int spineIndex;

  /// For PDF: which page the highlighted text is on
  final int pageNumber;

  /// The actual text that was highlighted
  final String selectedText;

  /// An optional note the user added to this highlight
  final String note;

  /// The colour used to highlight (yellow / green / blue / pink)
  final HighlightColor color;

  /// Character offset of the start of the selection within the chapter/page
  final int startOffset;

  /// Character offset of the end of the selection within the chapter/page
  final int endOffset;

  /// When the highlight was created
  final DateTime createdAt;

  const Highlight({
    required this.id,
    required this.bookId,
    this.spineIndex   = 0,
    this.pageNumber   = 1,
    required this.selectedText,
    this.note         = '',
    this.color        = HighlightColor.yellow,
    this.startOffset  = 0,
    this.endOffset    = 0,
    required this.createdAt,
  });

  factory Highlight.fromMap(Map<String, dynamic> map) {
    return Highlight(
      id:           map['id']            as String,
      bookId:       map['book_id']       as String,
      spineIndex:   map['spine_index']   as int?    ?? 0,
      pageNumber:   map['page_number']   as int?    ?? 1,
      selectedText: map['selected_text'] as String,
      note:         map['note']          as String? ?? '',
      color:        HighlightColorExt.fromString(map['color'] as String? ?? 'yellow'),
      startOffset:  map['start_offset']  as int?    ?? 0,
      endOffset:    map['end_offset']    as int?    ?? 0,
      createdAt:    DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id':            id,
      'book_id':       bookId,
      'spine_index':   spineIndex,
      'page_number':   pageNumber,
      'selected_text': selectedText,
      'note':          note,
      'color':         color.name,
      'start_offset':  startOffset,
      'end_offset':    endOffset,
      'created_at':    createdAt.toIso8601String(),
    };
  }

  Highlight copyWith({String? note, HighlightColor? color}) {
    return Highlight(
      id:           id,
      bookId:       bookId,
      spineIndex:   spineIndex,
      pageNumber:   pageNumber,
      selectedText: selectedText,
      note:         note  ?? this.note,
      color:        color ?? this.color,
      startOffset:  startOffset,
      endOffset:    endOffset,
      createdAt:    createdAt,
    );
  }
}
