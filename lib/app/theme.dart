import 'package:material_ui/material_ui.dart';

abstract final class VaultTheme {
  static const _seed = Color(0xFF126653);
  static const contentWidth = 680.0;
  static const gutter = 16.0;
  static const space = 20.0;
  static const gap = 12.0;
  static const radius = 16.0;
  static const target = 48.0;
  static const navigationLabelSize = 12.0;

  static ThemeData get light => _create(Brightness.light);
  static ThemeData get dark => _create(Brightness.dark);

  static ThemeData _create(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    final colors = brightness == Brightness.light
        ? scheme.copyWith(
            surface: const Color(0xFFF7F8F4),
            surfaceContainerLowest: Colors.white,
            surfaceContainerLow: const Color(0xFFEEF2EC),
            primaryContainer: const Color(0xFFD5EDE4),
          )
        : scheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      fontFamilyFallback: const ['Noto Sans Devanagari', 'Kohinoor Devanagari'],
      scaffoldBackgroundColor: colors.surface,
      visualDensity: VisualDensity.standard,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(fontWeight: FontWeight.w700),
        headlineSmall: TextStyle(fontWeight: FontWeight.w700),
        titleLarge: TextStyle(fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(fontSize: 15, height: 1.4),
        bodyLarge: TextStyle(fontSize: 16, height: 1.4),
        labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        errorMaxLines: 4,
        fillColor: colors.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(radius)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: shape,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(target, target),
          padding: const EdgeInsets.symmetric(horizontal: gutter, vertical: 12),
          shape: shape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(target, target),
          padding: const EdgeInsets.symmetric(horizontal: gutter, vertical: 12),
          shape: shape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(target, target)),
      ),
      listTileTheme: const ListTileThemeData(minVerticalPadding: 10),
      navigationBarTheme: NavigationBarThemeData(
        height: 66,
        backgroundColor: colors.surfaceContainerLowest,
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: navigationLabelSize, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
