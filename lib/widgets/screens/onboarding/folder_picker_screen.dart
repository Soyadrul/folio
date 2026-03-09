/// folder_picker_screen.dart
/// The onboarding experience shown on the very first launch of the app.
///
/// This screen has THREE pages the user swipes through:
///   Page 1 — Welcome: animated book illustration + app tagline
///   Page 2 — Folder setup: explains the concept and lets the user pick folders
///   Page 3 — Ready: confirmation and "Enter Library" button
///
/// After completing onboarding, the user is taken directly to LibraryScreen.
/// If the user already configured folders (i.e. they came from Settings),
/// we skip the welcome pages and show only the folder management view.

import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../providers/settings_provider.dart';
import '../../providers/library_provider.dart';
import '../library/library_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FOLDER PICKER SCREEN — root widget
// ─────────────────────────────────────────────────────────────────────────────

class FolderPickerScreen extends StatefulWidget {
  /// If true, we came from Settings — skip welcome slides, show only folder management.
  final bool fromSettings;

  const FolderPickerScreen({super.key, this.fromSettings = false});

  @override
  State<FolderPickerScreen> createState() => _FolderPickerScreenState();
}

class _FolderPickerScreenState extends State<FolderPickerScreen>
    with TickerProviderStateMixin {

  // ── Page controller for the three onboarding slides ──────────────────────
  late final PageController _pageController;
  int _currentPage = 0;

  // ── Entrance animation: fades and slides content up on screen load ────────
  late final AnimationController _entranceCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  // ── Floating book illustration: gentle up/down bob ────────────────────────
  late final AnimationController _floatCtrl;
  late final Animation<double>   _floatAnim;

  // ── Folder list ───────────────────────────────────────────────────────────
  final List<String> _pendingFolders = [];
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();

    _currentPage  = widget.fromSettings ? 1 : 0;
    _pageController = PageController(initialPage: _currentPage);

    // Entrance: 900ms fade + upward slide
    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnim = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _entranceCtrl, curve: Curves.easeOutCubic));

    // Float: repeating gentle bob
    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3200))
      ..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -8.0, end: 8.0).animate(
        CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Pre-populate with any already-saved folders (for Settings mode)
      final saved = context.read<SettingsProvider>().libraryFolders;
      setState(() => _pendingFolders.addAll(saved));
      _entranceCtrl.forward();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _entranceCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light icons on our dark background
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: widget.fromSettings
                ? _buildFolderManagementPage()
                : _buildOnboardingCarousel(),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ONBOARDING CAROUSEL
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildOnboardingCarousel() {
    return Stack(
      children: [
        PageView(
          controller:    _pageController,
          onPageChanged: (i) => setState(() => _currentPage = i),
          children: [
            _buildWelcomePage(),
            _buildFolderSetupPage(),
            _buildReadyPage(),
          ],
        ),
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: _buildBottomNav(),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PAGE 1 — WELCOME
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildWelcomePage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.0, -0.3),
          radius: 1.1,
          colors: [Color(0xFF2A3550), Color(0xFF0F1623)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // Floating book illustration
            AnimatedBuilder(
              animation: _floatAnim,
              builder: (context, child) => Transform.translate(
                offset: Offset(0, _floatAnim.value),
                child:  child,
              ),
              child: const _BookIllustration(),
            ),

            const SizedBox(height: 56),

            // App name — wide letter-spaced display text
            const Text(
              'FOLIO',
              style: TextStyle(
                color:         Color(0xFFF0E8D8),
                fontSize:      42,
                fontWeight:    FontWeight.w200,
                letterSpacing: 14,
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'Your entire library.\nAlways with you.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color:         Color(0xFF8A9BB5),
                fontSize:      16,
                height:        1.7,
                letterSpacing: 0.2,
              ),
            ),

            const Spacer(flex: 3),
            const SizedBox(height: 120), // Space for bottom nav
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PAGE 2 — FOLDER SETUP
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildFolderSetupPage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin:  Alignment.topCenter,
          end:    Alignment.bottomCenter,
          colors: [Color(0xFF1A2235), Color(0xFF0F1623)],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          // SingleChildScrollView keeps content accessible even on small phones
          // or when the folder list grows long
          padding: const EdgeInsets.fromLTRB(28, 48, 28, 140),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon badge
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color:        const Color(0xFF5B7FA6).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFF5B7FA6).withOpacity(0.3)),
                ),
                child: const Icon(Icons.folder_outlined,
                    color: Color(0xFF7BA7D4), size: 26),
              ),

              const SizedBox(height: 28),

              const Text(
                'Where are\nyour books?',
                style: TextStyle(
                  color:         Color(0xFFF0E8D8),
                  fontSize:      34,
                  fontWeight:    FontWeight.w300,
                  height:        1.25,
                  letterSpacing: 0.3,
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'Folio reads books directly from your device. '
                'Select the folder (or folders) where you keep your '
                'EPUB and PDF files. Subfolders are included automatically — '
                'perfect for organising by author or genre.',
                style: TextStyle(
                  color:    Color(0xFF7A8BA3),
                  fontSize: 15,
                  height:   1.65,
                ),
              ),

              const SizedBox(height: 36),

              _buildAddFolderButton(),

              const SizedBox(height: 24),

              if (_pendingFolders.isNotEmpty) ...[
                const Text(
                  'SELECTED FOLDERS',
                  style: TextStyle(
                    color:         Color(0xFF5B7FA6),
                    fontSize:      11,
                    letterSpacing: 1.4,
                    fontWeight:    FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ...List.generate(_pendingFolders.length,
                    (i) => _buildFolderChip(_pendingFolders[i], i)),
              ],

              if (_pendingFolders.isEmpty) _buildEmptyFolderHint(),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PAGE 3 — READY
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildReadyPage() {
    final hasFolders = _pendingFolders.isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.0, -0.2),
          radius: 1.0,
          colors: [Color(0xFF1E3A2F), Color(0xFF0F1623)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Checkmark or warning depending on whether folders were added
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: hasFolders
                    ? const _AnimatedCheckmark(key: ValueKey('check'))
                    : const Icon(Icons.warning_amber_rounded,
                        key:   ValueKey('warn'),
                        color: Color(0xFFE8A020),
                        size:  72),
              ),

              const SizedBox(height: 40),

              Text(
                hasFolders ? 'All set!' : 'No folder selected',
                style: const TextStyle(
                  color:         Color(0xFFF0E8D8),
                  fontSize:      36,
                  fontWeight:    FontWeight.w300,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                hasFolders
                    ? 'Folio will scan ${_pendingFolders.length} '
                      '${_pendingFolders.length == 1 ? "folder" : "folders"} '
                      'and build your library.\n'
                      'You can add more folders later in Settings.'
                    : 'Go back and add at least one folder\n'
                      'so Folio can find your books.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color:    Color(0xFF7A8BA3),
                  fontSize: 15,
                  height:   1.65,
                ),
              ),

              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BOTTOM NAVIGATION (dots + buttons)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    final isLastPage  = _currentPage == 2;
    final isFirstPage = _currentPage == 0;
    final canFinish   = _pendingFolders.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin:  Alignment.topCenter,
          end:    Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFF0F1623).withOpacity(0.96),
            const Color(0xFF0F1623),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Page indicator dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, _buildDot),
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              // Back button — hidden on first page
              if (!isFirstPage)
                GestureDetector(
                  onTap: _goBack,
                  child: Container(
                    width: 52, height: 52,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFFFF).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: const Color(0xFFFFFFFF).withOpacity(0.1)),
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        color: Color(0xFF8A9BB5), size: 20),
                  ),
                ),

              // Next / Open Library button
              Expanded(
                child: GestureDetector(
                  onTap: isLastPage
                      ? (canFinish ? _startScanning : null)
                      : _goNext,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 52,
                    decoration: BoxDecoration(
                      color: isLastPage && !canFinish
                          ? const Color(0xFF1A2235)
                          : const Color(0xFF5B7FA6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: _isScanning
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  isLastPage ? 'Open Library' : 'Continue',
                                  style: TextStyle(
                                    color: isLastPage && !canFinish
                                        ? const Color(0xFF3A4A60)
                                        : Colors.white,
                                    fontSize:      15,
                                    fontWeight:    FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                if (!isLastPage) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward_rounded,
                                      color: Colors.white, size: 18),
                                ],
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// A single animated page indicator dot
  Widget _buildDot(int index) {
    final isActive = index == _currentPage;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve:    Curves.easeInOut,
      margin:   const EdgeInsets.symmetric(horizontal: 4),
      width:    isActive ? 24 : 6,
      height:   6,
      decoration: BoxDecoration(
        color:        isActive ? const Color(0xFF5B7FA6) : const Color(0xFF2A3550),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FOLDER MANAGEMENT PAGE (from Settings)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildFolderManagementPage() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1623),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1623),
        foregroundColor: const Color(0xFFF0E8D8),
        title: const Text('Library Folders',
            style: TextStyle(
                color:         Color(0xFFF0E8D8),
                fontWeight:    FontWeight.w400,
                letterSpacing: 0.5)),
        elevation: 0,
        leading: IconButton(
          icon:     const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed:
                _pendingFolders.isNotEmpty ? _saveFoldersFromSettings : null,
            child: Text('Save',
                style: TextStyle(
                  color: _pendingFolders.isNotEmpty
                      ? const Color(0xFF7BA7D4)
                      : const Color(0xFF3A4A60),
                  fontWeight: FontWeight.w600,
                )),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Folio scans these folders for EPUB, PDF, and TXT files. '
                'Subfolders are included automatically.',
                style: TextStyle(
                    color: Color(0xFF7A8BA3), fontSize: 14, height: 1.6),
              ),
              const SizedBox(height: 28),
              _buildAddFolderButton(),
              const SizedBox(height: 20),
              if (_pendingFolders.isNotEmpty)
                ...List.generate(_pendingFolders.length,
                    (i) => _buildFolderChip(_pendingFolders[i], i)),
              if (_pendingFolders.isEmpty) _buildEmptyFolderHint(),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REUSABLE WIDGETS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildAddFolderButton() {
    return GestureDetector(
      onTap: _pickFolder,
      child: Container(
        width:   double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color:        const Color(0xFF5B7FA6).withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: const Color(0xFF5B7FA6).withOpacity(0.35), width: 1.5),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: Color(0xFF7BA7D4), size: 20),
            SizedBox(width: 10),
            Text('Add a folder',
                style: TextStyle(
                  color:         Color(0xFF7BA7D4),
                  fontSize:      15,
                  fontWeight:    FontWeight.w500,
                  letterSpacing: 0.3,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderChip(String path, int index) {
    // Show only the last segment of the path as the display name
    final displayName =
        path.split('/').where((s) => s.isNotEmpty).last;

    return Container(
      margin:  const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color:        const Color(0xFFFFFFFF).withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFFFFFFFF).withOpacity(0.08)),
      ),
      child: Row(
        children: [
          const Icon(Icons.folder_rounded,
              color: Color(0xFF5B7FA6), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName,
                    style: const TextStyle(
                        color: Color(0xFFD8E0EC),
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(path,
                    style: const TextStyle(
                        color: Color(0xFF4A5A70), fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _pendingFolders.removeAt(index)),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close_rounded,
                  color: Color(0xFF4A5A70), size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFolderHint() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFFFFFFFF).withOpacity(0.06)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded,
              color: Color(0xFF3A4A60), size: 18),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'No folder selected yet.\nTap "Add a folder" to get started.',
              style: TextStyle(
                  color: Color(0xFF3A4A60), fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACTIONS
  // ─────────────────────────────────────────────────────────────────────────

  void _goNext() => _pageController.nextPage(
      duration: const Duration(milliseconds: 450),
      curve:    Curves.easeInOutCubic);

  void _goBack() => _pageController.previousPage(
      duration: const Duration(milliseconds: 350),
      curve:    Curves.easeInOutCubic);

  /// Opens the native Android folder picker.
  /// First requests the required storage permission.
  Future<void> _pickFolder() async {
    if (Platform.isAndroid) {
      // MANAGE_EXTERNAL_STORAGE allows scanning any folder freely on Android 11+
      final status = await Permission.manageExternalStorage.request();
      if (!status.isGranted) {
        // Fall back to basic storage permission for older Android versions
        final basic = await Permission.storage.request();
        if (!basic.isGranted) {
          _showPermissionDialog();
          return;
        }
      }
    }

    // Opens Android's Storage Access Framework folder picker
    final selectedPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select your books folder',
    );

    if (selectedPath == null) return; // User cancelled

    if (_pendingFolders.contains(selectedPath)) {
      _showSnackBar('This folder is already in your library.');
      return;
    }

    setState(() => _pendingFolders.add(selectedPath));
  }

  /// Saves folders, starts library scan, then navigates to LibraryScreen.
  Future<void> _startScanning() async {
    if (_pendingFolders.isEmpty) return;
    setState(() => _isScanning = true);

    final settings = context.read<SettingsProvider>();
    final library  = context.read<LibraryProvider>();

    for (final folder in _pendingFolders) {
      await settings.addLibraryFolder(folder);
    }
    await library.scanFolders(_pendingFolders);

    if (!mounted) return;
    setState(() => _isScanning = false);

    // Navigate to library and remove onboarding from the back stack
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder:      (_, anim, __) => const LibraryScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
      (route) => false,
    );
  }

  /// Saves changes made from the Settings screen.
  Future<void> _saveFoldersFromSettings() async {
    final settings = context.read<SettingsProvider>();
    final library  = context.read<LibraryProvider>();
    final existing = settings.libraryFolders.toList();

    for (final old in existing) {
      if (!_pendingFolders.contains(old)) {
        await settings.removeLibraryFolder(old);
      }
    }
    for (final newF in _pendingFolders) {
      if (!existing.contains(newF)) {
        await settings.addLibraryFolder(newF);
      }
    }
    await library.scanFolders(_pendingFolders);

    if (mounted) Navigator.of(context).pop();
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2235),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Permission needed',
            style: TextStyle(color: Color(0xFFF0E8D8))),
        content: const Text(
          'Folio needs storage access to find your book files. '
          'Please grant permission in your device Settings.',
          style: TextStyle(color: Color(0xFF7A8BA3), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF5B7FA6))),
          ),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: const Text('Open Settings',
                style: TextStyle(color: Color(0xFF7BA7D4))),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:   Text(msg),
      backgroundColor: const Color(0xFF1A2235),
      behavior:  SnackBarBehavior.floating,
      shape:     RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOOK ILLUSTRATION
// Drawn entirely with Flutter's Canvas — no image files needed.
// This scales perfectly to any screen size and density.
// ─────────────────────────────────────────────────────────────────────────────

class _BookIllustration extends StatelessWidget {
  const _BookIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220, height: 180,
      child: CustomPaint(painter: _BookPainter()),
    );
  }
}

class _BookPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;

    // ── Background glow ──────────────────────────────────────────────────
    canvas.drawCircle(
      Offset(cx, cy),
      100,
      Paint()
        ..shader = RadialGradient(colors: [
          const Color(0xFF5B7FA6).withOpacity(0.22),
          Colors.transparent,
        ]).createShader(
            Rect.fromCircle(center: Offset(cx, cy), radius: 100)),
    );

    // ── Left page ────────────────────────────────────────────────────────
    final leftPage = Path()
      ..moveTo(cx,       cy - 68)
      ..cubicTo(cx - 15, cy - 55, cx - 90, cy - 40, cx - 88, cy)
      ..cubicTo(cx - 90, cy + 40, cx - 15, cy + 55, cx,      cy + 68)
      ..close();

    canvas.drawPath(
      leftPage,
      Paint()
        ..shader = LinearGradient(
          begin:  Alignment.centerRight,
          end:    Alignment.centerLeft,
          colors: [const Color(0xFF3A5070), const Color(0xFF243248)],
        ).createShader(Rect.fromLTWH(cx - 90, cy - 68, 90, 136)),
    );

    // ── Right page ────────────────────────────────────────────────────────
    final rightPage = Path()
      ..moveTo(cx,       cy - 68)
      ..cubicTo(cx + 15, cy - 55, cx + 90, cy - 40, cx + 88, cy)
      ..cubicTo(cx + 90, cy + 40, cx + 15, cy + 55, cx,      cy + 68)
      ..close();

    canvas.drawPath(
      rightPage,
      Paint()
        ..shader = LinearGradient(
          begin:  Alignment.centerLeft,
          end:    Alignment.centerRight,
          colors: [const Color(0xFF3A5070), const Color(0xFF1E3050)],
        ).createShader(Rect.fromLTWH(cx, cy - 68, 90, 136)),
    );

    // ── Page edge outlines ────────────────────────────────────────────────
    final edgePaint = Paint()
      ..color       = const Color(0xFF7BA7D4).withOpacity(0.28)
      ..strokeWidth = 1.0
      ..style       = PaintingStyle.stroke;
    canvas.drawPath(leftPage,  edgePaint);
    canvas.drawPath(rightPage, edgePaint);

    // ── Spine line ────────────────────────────────────────────────────────
    canvas.drawLine(
      Offset(cx, cy - 68), Offset(cx, cy + 68),
      Paint()
        ..color       = const Color(0xFF8AA5C5)
        ..strokeWidth = 2.5
        ..strokeCap   = StrokeCap.round,
    );

    // ── Simulated text lines ──────────────────────────────────────────────
    final linePaint = Paint()
      ..color       = const Color(0xFF5B7FA6).withOpacity(0.38)
      ..strokeWidth = 1.1
      ..strokeCap   = StrokeCap.round;

    for (int i = 0; i < 7; i++) {
      final y = cy - 36 + (i * 11.5);
      // Left page lines
      canvas.drawLine(
        Offset(cx - 72 + (i.isOdd ? 3.0 : 0.0), y),
        Offset(i == 6 ? cx - 28 : cx - 10, y),
        linePaint,
      );
      // Right page lines
      canvas.drawLine(
        Offset(i == 6 ? cx + 28 : cx + 10, y),
        Offset(cx + 72 - (i.isOdd ? 3.0 : 0.0), y),
        linePaint,
      );
    }

    // ── Decorative star dots ──────────────────────────────────────────────
    _star(canvas, Offset(cx - 100, cy - 50), 2.8,
        const Color(0xFF5B7FA6).withOpacity(0.5));
    _star(canvas, Offset(cx + 104, cy - 42), 2.0,
        const Color(0xFF7BA7D4).withOpacity(0.4));
    _star(canvas, Offset(cx + 92,  cy + 56), 2.4,
        const Color(0xFF5B7FA6).withOpacity(0.35));
    _star(canvas, Offset(cx - 88,  cy + 58), 1.8,
        const Color(0xFF7BA7D4).withOpacity(0.3));
  }

  void _star(Canvas canvas, Offset c, double r, Color col) {
    final p = Paint()..color = col;
    canvas.drawCircle(c, r * 0.4, p);
    for (int i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      canvas.drawCircle(
          Offset(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r), 0.9, p);
    }
  }

  @override
  bool shouldRepaint(_BookPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// ANIMATED CHECKMARK
// Draws itself with a smooth animation when it first appears on screen
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedCheckmark extends StatefulWidget {
  const _AnimatedCheckmark({super.key});

  @override
  State<_AnimatedCheckmark> createState() => _AnimatedCheckmarkState();
}

class _AnimatedCheckmarkState extends State<_AnimatedCheckmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    // Slight delay so it runs after the page slide-in transition
    Future.delayed(const Duration(milliseconds: 300),
        () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90, height: 90,
      child: AnimatedBuilder(
        animation: _anim,
        builder:   (_, __) => CustomPaint(painter: _CheckPainter(_anim.value)),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double t; // 0.0 → 1.0
  const _CheckPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Circle background
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF1E3A2F));

    // Circle border draws itself as t increases
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r - 2),
      -math.pi / 2,
      2 * math.pi * t,
      false,
      Paint()
        ..color       = const Color(0xFF4CAF80)
        ..strokeWidth = 2.5
        ..style       = PaintingStyle.stroke,
    );

    // Checkmark appears during the second half of the animation
    if (t > 0.5) {
      final ct = ((t - 0.5) / 0.5).clamp(0.0, 1.0);
      final p1 = Offset(size.width * 0.28, size.height * 0.50);
      final p2 = Offset(size.width * 0.44, size.height * 0.66);
      final p3 = Offset(size.width * 0.72, size.height * 0.36);
      final paint = Paint()
        ..color       = const Color(0xFF4CAF80)
        ..strokeWidth = 3.0
        ..strokeCap   = StrokeCap.round
        ..style       = PaintingStyle.stroke;

      if (ct < 0.5) {
        canvas.drawLine(p1, Offset.lerp(p1, p2, ct / 0.5)!, paint);
      } else {
        canvas.drawLine(p1, p2, paint);
        canvas.drawLine(p2, Offset.lerp(p2, p3, (ct - 0.5) / 0.5)!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.t != t;
}
