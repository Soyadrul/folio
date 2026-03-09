/// epub_service.dart
/// Handles all EPUB-specific operations:
///   - Extracting metadata (title, author, description, cover image)
///     from an EPUB file the first time it is opened
///   - Building a rich Book record to update the database with real data
///
/// An EPUB file is essentially a ZIP archive containing HTML chapters,
/// a metadata XML file (OPF), a table-of-contents file (NCX/NAV),
/// and optionally image files for the cover.
///
/// The epub_view package gives us a high-level EpubController that handles
/// rendering; this service handles the lower-level metadata extraction.

import 'dart:io';
import 'package:epub_view/epub_view.dart' as epublib;
import '../models/models.dart';

class EpubService {
  /// Extracts all available metadata from an EPUB file and returns
  /// an updated [Book] object with real title, author, cover, etc.
  ///
  /// Call this the first time a book is opened. After that, metadata
  /// is cached in the database and this method is not called again.
  ///
  /// [existingBook] — the placeholder Book created during library scan.
  ///                  We keep its id, filePath, addedAt, and openCount.
  static Future<Book> extractMetadata(Book existingBook) async {
    try {
      final file  = File(existingBook.filePath);
      final bytes = await file.readAsBytes();

      // epublib.EpubBook parses the entire EPUB structure from raw bytes.
      // This gives us access to the OPF metadata package.
      final epubBook = await epublib.EpubDocument.openData(bytes);

      // ── Title ────────────────────────────────────────────────────────
      // EPUB metadata can have multiple titles; we take the first non-empty one.
      final title = epubBook.Title?.trim().isNotEmpty == true
          ? epubBook.Title!.trim()
          : existingBook.title; // Fall back to filename if no title found

      // ── Author ───────────────────────────────────────────────────────
      // Authors is a List<String> in EPUB 2; we join with ", " for display.
      final authors = epubBook.AuthorList ?? [];
      final author  = authors.isNotEmpty
          ? authors
              .where((a) => a != null && a.trim().isNotEmpty)
              .join(', ')
          : (epubBook.Author?.trim() ?? '');

      // ── Cover image bytes ─────────────────────────────────────────────
      // EPUB covers are stored as image files inside the package.
      // epub_view exposes them via CoverImage.
      List<int>? coverBytes;
      try {
        final cover = epubBook.CoverImage;
        if (cover != null) {
          coverBytes = cover;
        }
      } catch (_) {
        // Some EPUBs declare a cover in metadata but the file is missing.
        // We silently ignore this — the generated placeholder will be used.
      }

      // ── Description ──────────────────────────────────────────────────
      // The description (synopsis) is in the Dublin Core metadata.
      final description = epubBook.Schema?.Package?.Metadata
              ?.Description
              ?.trim() ?? '';

      // ── Language ─────────────────────────────────────────────────────
      final language = epubBook.Schema?.Package?.Metadata
              ?.Languages
              ?.firstOrNull
              ?.trim() ?? '';

      // ── Publisher ────────────────────────────────────────────────────
      final publisher = epubBook.Schema?.Package?.Metadata
              ?.Publishers
              ?.firstOrNull
              ?.trim() ?? '';

      // Return a new Book with all fields filled in from real EPUB metadata
      return existingBook.copyWith(
        title:       title.isNotEmpty       ? title       : null,
        author:      author.isNotEmpty      ? author      : null,
        description: description.isNotEmpty ? description : null,
        coverBytes:  coverBytes,
      );

    } catch (e) {
      // If metadata extraction fails for any reason (corrupt file, unsupported
      // EPUB version), we return the original book unchanged.
      // The user can still read it — we just won't have pretty metadata.
      return existingBook;
    }
  }

  /// Counts the total number of "pages" in an EPUB for progress calculation.
  /// Since EPUB is reflowable, "pages" are approximated by
  /// counting spine items (chapters) — not physical pages.
  static Future<int> countSpineItems(String filePath) async {
    try {
      final bytes    = await File(filePath).readAsBytes();
      final epubBook = await epublib.EpubDocument.openData(bytes);
      return epubBook.Chapters?.length ?? 1;
    } catch (_) {
      return 1;
    }
  }
}
