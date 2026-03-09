/// pdf_service.dart
/// Handles PDF-specific operations:
///   - Extracting metadata (title, author, page count) from a PDF file
///   - PDFs store metadata in an optional XMP/Info dictionary
///
/// Unlike EPUB, PDFs are page-based and fixed-layout. This means:
///   - The "spine" concept doesn't apply — we track by page number instead
///   - Font size changes don't reflow the text (we zoom the page instead)
///   - Cover image = the first page rendered as a thumbnail
///   - Text extraction for highlights is more complex (not in Step 4)

import 'dart:io';
import 'package:pdfx/pdfx.dart';
import '../models/models.dart';

class PdfService {
  /// Extracts available metadata from a PDF file.
  ///
  /// PDF metadata is often missing or incorrect in user files,
  /// so we fall back gracefully at every step.
  ///
  /// [existingBook] — the placeholder Book from the library scan.
  static Future<Book> extractMetadata(Book existingBook) async {
    try {
      // pdfx.PdfDocument opens the PDF for reading.
      // We must close it when done to release the file handle.
      final doc = await PdfDocument.openFile(existingBook.filePath);

      // ── Page count ────────────────────────────────────────────────────
      // PDFs always have a page count — this is reliable metadata.
      final pageCount = doc.pagesCount;

      // ── Cover image from first page ───────────────────────────────────
      // We render the first page at low resolution to use as a thumbnail.
      // 150px wide is plenty for a library cover card.
      List<int>? coverBytes;
      try {
        final firstPage = await doc.getPage(1);
        final image     = await firstPage.render(
          width:  150,
          height: (150 * firstPage.height / firstPage.width).round(),
          format: PdfPageImageFormat.jpeg,
          backgroundColor: '#FFFFFF',
        );
        await firstPage.close();
        if (image?.bytes != null) {
          coverBytes = image!.bytes.toList();
        }
      } catch (_) {
        // Cover generation failed — use generated placeholder
      }

      await doc.close();

      // ── File size ─────────────────────────────────────────────────────
      final fileSize = await File(existingBook.filePath).length();

      // Return updated book. PDF metadata (title, author) is unreliable
      // so we keep the filename-based title from the scan.
      return Book(
        id:            existingBook.id,
        title:         existingBook.title,
        author:        existingBook.author,
        filePath:      existingBook.filePath,
        format:        BookFormat.pdf,
        description:   existingBook.description,
        publisher:     existingBook.publisher,
        language:      existingBook.language,
        coverBytes:    coverBytes ?? existingBook.coverBytes,
        fileSizeBytes: fileSize,
        addedAt:       existingBook.addedAt,
        startedReadingAt:  existingBook.startedReadingAt,
        finishedReadingAt: existingBook.finishedReadingAt,
        readingDatesLocked: existingBook.readingDatesLocked,
        openCount:     existingBook.openCount,
      );

    } catch (e) {
      return existingBook;
    }
  }

  /// Returns the total number of pages in a PDF.
  /// Used by the reader to calculate progress percentage.
  static Future<int> getPageCount(String filePath) async {
    try {
      final doc   = await PdfDocument.openFile(filePath);
      final count = doc.pagesCount;
      await doc.close();
      return count;
    } catch (_) {
      return 1;
    }
  }
}
