/// main.dart
/// The entry point of the eBook Reader app.
///
/// This file does three things:
///   1. Loads saved settings before the first frame is drawn
///   2. Sets up all "providers" — the state management objects that
///      share data between screens without complicated passing of variables
///   3. Launches the app with the correct theme already applied

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/library_provider.dart';
import 'providers/reader_provider.dart';
import 'theme/app_theme.dart';
import 'screens/onboarding/folder_picker_screen.dart';
import 'screens/library/library_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MAIN — the first function Flutter calls when the app starts
// ─────────────────────────────────────────────────────────────────────────────

Future<void> main() async {
  // WidgetsFlutterBinding.ensureInitialized() must be called before any
  // async work in main(). It initialises the bridge between Dart and the
  // Flutter engine, which is required for things like SharedPreferences.
  WidgetsFlutterBinding.ensureInitialized();

  // Lock the app to portrait orientation only.
  // Reading a book in landscape is unusual on phones; we can add it later.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Make the status bar (time, battery icons at top) transparent
  // so our reader theme can show through it without a white bar interrupting
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:       Colors.transparent,
    statusBarBrightness:  Brightness.dark,
  ));

  // ── Load saved settings before the first frame ──────────────────────────
  // We must load settings NOW so the app starts with the correct theme
  // and doesn't flash a white screen before applying the saved dark/sepia theme.

  final themeProvider    = ThemeProvider();
  final settingsProvider = SettingsProvider();

  // Both of these read from SharedPreferences — they must complete before
  // we call runApp() so the first frame is already correctly themed.
  await Future.wait([
    themeProvider.loadSavedTheme(),
    settingsProvider.loadSettings(),
  ]);

  // ── Launch the app ───────────────────────────────────────────────────────
  runApp(
    // MultiProvider wraps the entire app in all our state providers.
    // Any widget anywhere in the tree can now access these providers.
    MultiProvider(
      providers: [
        // ChangeNotifierProvider creates the provider and disposes it
        // automatically when the widget tree is torn down.
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),

        // LibraryProvider manages the book collection
        ChangeNotifierProvider<LibraryProvider>(
          create: (_) => LibraryProvider(),
        ),

        // ReaderProvider manages the active reading session
        // It's created fresh — a new instance per app launch
        ChangeNotifierProvider<ReaderProvider>(
          create: (_) => ReaderProvider(),
        ),
      ],
      child: const EBookReaderApp(),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ROOT APP WIDGET
// ─────────────────────────────────────────────────────────────────────────────

/// The root widget of the application.
/// Sets up the MaterialApp with theme support and the initial route.
class EBookReaderApp extends StatelessWidget {
  const EBookReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Consumer<ThemeProvider> rebuilds this widget whenever the theme changes.
    // This is what makes switching from light to dark mode instant.
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          title: 'eBook Reader',

          // Removes the debug banner in the top-right corner
          debugShowCheckedModeBanner: false,

          // ── Theme configuration ──────────────────────────────────────────
          // We provide both light and dark ThemeData.
          // MaterialApp uses themeMode to decide which one to apply.
          theme:     AppTheme.light,
          darkTheme: AppTheme.dark,

          // themeMode tells MaterialApp which theme to use:
          //   ThemeMode.system → follow phone setting
          //   ThemeMode.light  → always light
          //   ThemeMode.dark   → always dark
          // For sepia, we use light mode here and apply sepia colours inside
          // the reader via the ReadingTheme extension.
          themeMode: themeProvider.materialThemeMode,

          // ── App-wide theme for specific components ───────────────────────
          // builder wraps every screen in a MediaQuery listener so the sepia
          // theme is correctly applied everywhere, not just in the reader.
          builder: (context, child) {
            // For sepia mode, we wrap the entire app in a ColorFiltered widget
            // that shifts the white towards a warm sepia tone.
            // This works even for PDF pages which we can't theme from inside.
            if (themeProvider.themeMode == AppThemeMode.sepia) {
              return Theme(
                data: AppTheme.sepia,
                child: child!,
              );
            }
            return child!;
          },

          // ── Routing ──────────────────────────────────────────────────────
          // onGenerateRoute handles navigation between screens.
          // We use named routes for clarity.
          initialRoute: '/',
          onGenerateRoute: _generateRoute,
        );
      },
    );
  }

  /// Maps route names to screen widgets.
  /// Called every time the app navigates to a new screen.
  Route<dynamic>? _generateRoute(RouteSettings settings) {
    switch (settings.name) {

      // '/' is the first screen shown when the app launches.
      // We decide which screen to show in _HomeDecider below.
      case '/':
        return MaterialPageRoute(builder: (_) => const HomeDecider());

      case '/library':
        return MaterialPageRoute(builder: (_) => const LibraryScreen());

      case '/folder-picker':
        return MaterialPageRoute(builder: (_) => const FolderPickerScreen());

      default:
        // If an unknown route is requested, show a simple error screen
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('Page not found: ${settings.name}'),
            ),
          ),
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOME DECIDER
// Decides whether to show the onboarding screen or go straight to the library.
// ─────────────────────────────────────────────────────────────────────────────

/// Shown at '/' — checks if the user has already set up a library folder.
/// If yes → go to LibraryScreen.
/// If no  → go to FolderPickerScreen (onboarding).
class HomeDecider extends StatelessWidget {
  const HomeDecider({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    // If the user has at least one library folder configured, go to the library
    if (settings.libraryFolders.isNotEmpty) {
      return const LibraryScreen();
    }

    // Otherwise, show the folder picker onboarding
    return const FolderPickerScreen();
  }
}
