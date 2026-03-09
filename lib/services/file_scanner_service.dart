/// file_scanner_service.dart
/// Responsible for discovering eBook files on the device's storage.
///
/// The scanner is called in two situations:
///   1. On first launch (after the user picks a folder in onboarding)
///   2. When the user taps "Rescan Library" in Settings
///
/// What it does:
///   - Recursively walks each folder the user has added
///   - Identifies .epub, .pdf, and .txt files by extension
///   - Returns a stream of ScanResult objects so the UI can update in real-time
///   - Skips hidden files (names starting with '.') and system directories
///   - Reports progress via a callback so the library screen can update its
///     status message without needing to poll
///
/// The scanner does NOT extract metadata (title, author, cover) — that is
/// handled lazily by EpubService / PdfService the first time a book is opened.
/// This keeps scanning fast: a 500-book library scans in under a second.

import 'dart:io';
import 'package:path/path.dart' as p;

// ─────────────────────────────────────────────────────────────────────────────
// SCAN RESULT
// A single file found during the scan, with its basic file-system metadata
// ─────────────────────────────────────────────────────────────────────────────

/// Holds everything we know about an eBook file discovered during a scan.
class ScanResult {
  /// The absolute path to the file on the device storage.
  final String filePath;

  /// The file extension (.epub / .pdf / .txt), already lowercase.
  final String extension;

  /// File size in bytes.
  final int fileSizeBytes;

  /// The date the file was last modified on the device.
  final DateTime modifiedAt;

  /// Filename without extension — used as the initial title until real
  /// metadata is extracted when the book is first opened.
  final String fileBaseName;

  const ScanResult({
    required this.filePath,
    required this.extension,
    required this.fileSizeBytes,
    required this.modifiedAt,
    required this.fileBaseName,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// SCAN PROGRESS
// Passed to the progress callback so the UI can show live status
// ─────────────────────────────────────────────────────────────────────────────

/// Live progress update sent to the UI during a scan.
class ScanProgress {
  /// Short name of the folder currently being scanned.
  final String currentFolder;

  /// Total book files found so far.
  final int foundCount;

  /// True when the scan has finished completely.
  final bool isDone;

  const ScanProgress({
    required this.currentFolder,
    required this.foundCount,
    this.isDone = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// FILE SCANNER SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class FileScannerService {
  /// Supported file extensions — Set for O(1) lookup.
  static const _supportedExtensions = {'.epub', '.pdf', '.txt'};

  /// System/hidden folder names that will never contain eBooks — skip them
  /// to avoid wasting scan time and hitting permission errors.
  static const _skipDirs = {
    'Android', 'DCIM', 'LOST.DIR',
    '.thumbnails', '.cache', 'cache', '.android_secure',
  };

  /// Scans all [folderPaths] recursively and returns all found eBook files.
  ///
  /// [onProgress] is called periodically so the UI can show live feedback.
  /// Returns a sorted list of [ScanResult]s (newest files first).
  static Future<List<ScanResult>> scanFolders(
    List<String> folderPaths, {
    void Function(ScanProgress)? onProgress,
  }) async {
    final results    = <ScanResult>[];
    var   foundCount = 0;

    for (final folderPath in folderPaths) {
      final dir = Directory(folderPath);
      if (!await dir.exists()) continue;

      onProgress?.call(ScanProgress(
        currentFolder: _shortName(folderPath),
        foundCount:    foundCount,
      ));

      try {
        // Walk the directory tree depth-first.
        // followLinks: false prevents infinite loops from symlinks.
        await for (final entity
            in dir.list(recursive: true, followLinks: false)) {
          if (entity is! File) continue;

          // Skip hidden files
          final basename = p.basename(entity.path);
          if (basename.startsWith('.')) continue;

          // Skip files inside system/hidden folders
          final segments = entity.path.split(Platform.pathSeparator);
          final inSkipped = segments.any(
              (s) => _skipDirs.contains(s) || s.startsWith('.'));
          if (inSkipped) continue;

          // Filter by extension
          final ext = p.extension(entity.path).toLowerCase();
          if (!_supportedExtensions.contains(ext)) continue;

          // Read file metadata — gracefully skip if no permission
          FileStat stat;
          try {
            stat = await entity.stat();
          } catch (_) {
            continue;
          }

          results.add(ScanResult(
            filePath:      entity.path,
            extension:     ext,
            fileSizeBytes: stat.size,
            modifiedAt:    stat.modified,
            fileBaseName:  p.basenameWithoutExtension(entity.path),
          ));

          foundCount++;

          // Notify every 5 files — responsive without flooding setState()
          if (foundCount % 5 == 0) {
            onProgress?.call(ScanProgress(
              currentFolder: _shortName(folderPath),
              foundCount:    foundCount,
            ));
          }
        }
      } catch (_) {
        // Permission denied or IO error for this folder — skip, don't crash
        continue;
      }
    }

    // Final completion notification
    onProgress?.call(ScanProgress(
      currentFolder: '',
      foundCount:    foundCount,
      isDone:        true,
    ));

    // Sort newest files first so recently added books surface at the top
    results.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));

    return results;
  }

  /// Returns the last segment of a path for display in status messages.
  /// e.g. "/storage/emulated/0/Books" → "Books"
  static String _shortName(String path) =>
      p.basename(path).isEmpty ? path : p.basename(path);
}
