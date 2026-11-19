import 'package:material_ui/material_ui.dart';

const ink = Color(0xFF20252B);
const accent = Color(0xFF7C3AED);
const paper = Color(0xFFF7F7F7);
const card = Color(0xFFFFFFFF);
const line = Color(0xFFE1E4E8);
const darkPaper = Color(0xFF000000);
const darkCard = Color(0xFF141414);
const darkLine = Color(0xFF2B2B2B);

ThemeData appTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final background = dark ? darkPaper : paper;
  final container = dark ? darkCard : card;
  final foreground = dark ? const Color(0xFFF3F4F7) : ink;
  final readableAccent = dark
      ? const Color(0xFFC4A3FF)
      : const Color(0xFF6D28D9);
  final accentContainer = dark
      ? const Color(0xFF302044)
      : const Color(0xFFEDE3FF);
  final onAccentContainer = dark
      ? const Color(0xFFE9DAFF)
      : const Color(0xFF431582);
  return ThemeData(
    brightness: brightness,
    useMaterial3: true,
    scaffoldBackgroundColor: background,
    splashFactory: InkRipple.splashFactory,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: brightness,
          surface: background,
          surfaceContainer: container,
          primary: readableAccent,
          onPrimary: dark ? darkPaper : Colors.white,
          onSurface: foreground,
          outlineVariant: dark ? darkLine : line,
          primaryContainer: accentContainer,
          onPrimaryContainer: onAccentContainer,
        ).copyWith(
          // Keep every elevation neutral: seed-generated surfaces carry a tint.
          surfaceDim: dark ? darkPaper : const Color(0xFFE5E5E5),
          surfaceBright: dark ? const Color(0xFF262626) : card,
          surfaceContainerLowest: dark ? darkPaper : card,
          surfaceContainerLow: dark
              ? const Color(0xFF0D0D0D)
              : const Color(0xFFF2F2F2),
          surfaceContainerHigh: dark
              ? const Color(0xFF1C1C1C)
              : const Color(0xFFECECEC),
          surfaceContainerHighest: dark
              ? const Color(0xFF242424)
              : const Color(0xFFE6E6E6),
          onSurfaceVariant: dark
              ? const Color(0xFFBDBDBD)
              : const Color(0xFF555555),
          outline: dark ? const Color(0xFF777777) : const Color(0xFF767676),
          surfaceTint: Colors.transparent,
          secondary: readableAccent,
          onSecondary: dark ? darkPaper : Colors.white,
          secondaryContainer: accentContainer,
          onSecondaryContainer: onAccentContainer,
          tertiary: readableAccent,
          onTertiary: dark ? darkPaper : Colors.white,
          tertiaryContainer: accentContainer,
          onTertiaryContainer: onAccentContainer,
          inverseSurface: dark
              ? const Color(0xFFEDEDED)
              : const Color(0xFF242424),
          onInverseSurface: dark
              ? const Color(0xFF202020)
              : const Color(0xFFF3F3F3),
          inversePrimary: dark
              ? const Color(0xFF6D28D9)
              : const Color(0xFFC4A3FF),
        ),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: foreground,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        height: 1.12,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.1,
      ),
      titleLarge: TextStyle(
        fontSize: 21,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: -.4,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        height: 1.3,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(fontSize: 17, height: 1.5),
      bodyMedium: TextStyle(fontSize: 15, height: 1.45),
      labelMedium: TextStyle(
        fontSize: 12,
        height: 1.3,
        fontWeight: FontWeight.w500,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: background,
      elevation: 0,
      indicatorColor: accentContainer,
      height: 76,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xFF242424) : const Color(0xFF202020),
      contentTextStyle: TextStyle(color: Colors.white, fontSize: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: container,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      dragHandleColor: dark ? const Color(0xFF777777) : const Color(0xFF808080),
    ),
    dividerTheme: DividerThemeData(
      color: dark ? darkLine : line,
      thickness: 1,
      space: 24,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: readableAccent,
      foregroundColor: dark ? darkPaper : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    chipTheme: ChipThemeData(
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      backgroundColor: container,
      labelStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: foreground,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 56),
        padding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 52),
        textStyle: const TextStyle(fontSize: 18),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: container,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: dark ? darkLine : line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: readableAccent, width: 2),
      ),
      contentPadding: const EdgeInsets.all(18),
    ),
  );
}
