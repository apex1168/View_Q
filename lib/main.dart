import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'app_theme.dart';
import 'home_screen.dart';
import 'library.dart';

export 'detail_screen.dart' show DetailPage;

void main() => runApp(ViewQApp(library: Library()));

class ViewQApp extends StatefulWidget {
  const ViewQApp({super.key, required this.library});
  final Library library;
  @override
  State<ViewQApp> createState() => _ViewQAppState();
}

class _ViewQAppState extends State<ViewQApp> {
  bool dark = true;
  bool themeChanged = false;

  @override
  void initState() {
    super.initState();
    unawaited(loadTheme());
  }

  Future<void> loadTheme() async {
    try {
      final saved = await widget.library.themeMode();
      if (mounted && !themeChanged) setState(() => dark = saved);
    } catch (_) {
      // The app starts in dark mode if preferences are unavailable.
    }
  }

  Future<void> toggleTheme() async {
    final next = !dark;
    themeChanged = true;
    setState(() => dark = next);
    try {
      await widget.library.themeMode(next);
    } catch (_) {
      // The selected theme still applies to this session.
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'View Q',
    debugShowCheckedModeBanner: false,
    themeAnimationDuration:
        MediaQuery.maybeOf(context)?.disableAnimations == true
        ? Duration.zero
        : const Duration(milliseconds: 260),
    themeAnimationCurve: Curves.easeInOutCubic,
    theme: appTheme(Brightness.light),
    darkTheme: appTheme(Brightness.dark),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: LibraryPage(library: widget.library, onToggleTheme: toggleTheme),
  );
}
