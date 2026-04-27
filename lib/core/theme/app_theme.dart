import 'package:antwise/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Application [ThemeData] factories (light / dark).
abstract final class AppTheme {
  static const BorderRadius _fieldRadius = BorderRadius.all(
    Radius.circular(14),
  );
  static const double _fieldTextFontSize = 12;
  static const double _fieldLabelFontSize = 13;

  static TextTheme _withDropdownItemFontSize(TextTheme textTheme) =>
      textTheme.copyWith(
        // DropdownButtonFormField fallback text style in this SDK.
        titleMedium: textTheme.titleMedium?.copyWith(
          fontSize: _fieldTextFontSize,
        ),
      );

  static InputDecorationTheme _inputDecorationTheme(ColorScheme scheme) {
    final Color activePrimary = _actionPrimary(scheme, scheme.brightness);
    return InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: TextStyle(
        fontSize: _fieldTextFontSize,
        color: scheme.onSurfaceVariant,
      ),
      labelStyle: TextStyle(
        fontSize: _fieldLabelFontSize,
        color:
            scheme.brightness == Brightness.dark
                ? activePrimary
                : scheme.onSurfaceVariant,
      ),
      floatingLabelStyle: TextStyle(
        fontSize: _fieldLabelFontSize,
        color: activePrimary,
      ),
      errorStyle: TextStyle(fontSize: _fieldLabelFontSize, color: scheme.error),
      border: OutlineInputBorder(
        borderRadius: _fieldRadius,
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: _fieldRadius,
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: _fieldRadius,
        borderSide: BorderSide(color: scheme.primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: _fieldRadius,
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: _fieldRadius,
        borderSide: BorderSide(color: scheme.error, width: 1.4),
      ),
    );
  }

  static DropdownMenuThemeData _dropdownMenuTheme(ColorScheme scheme) =>
      DropdownMenuThemeData(
        textStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: _fieldTextFontSize,
        ),
        inputDecorationTheme: _inputDecorationTheme(scheme),
        menuStyle: MenuStyle(
          shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
            RoundedRectangleBorder(borderRadius: _fieldRadius),
          ),
          side: WidgetStatePropertyAll<BorderSide>(
            BorderSide(color: scheme.outlineVariant),
          ),
          backgroundColor: WidgetStatePropertyAll<Color>(scheme.surface),
        ),
      );

  static Color _actionPrimary(ColorScheme scheme, Brightness brightness) {
    if (brightness != Brightness.dark) {
      return scheme.primary;
    }
    return Color.alphaBlend(
      Colors.white.withValues(alpha: 0.50),
      scheme.primary,
    );
  }

  static ThemeData light({
    required Color primary,
    required Color secondary,
    Color onPrimary = Colors.white,
  }) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: secondary,
      onPrimary: onPrimary,
      brightness: Brightness.light,
    );
    final TextTheme base =
        Typography.material2021(platform: TargetPlatform.android).black;
    final TextTheme textTheme = _withDropdownItemFontSize(
      AppTextStyles.textTheme(scheme, base),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _actionPrimary(scheme, Brightness.light),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _actionPrimary(scheme, Brightness.light),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith<Color?>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return scheme.onSurface;
          }),
          backgroundColor: WidgetStateProperty.resolveWith<Color?>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.selected)) {
              return scheme.primary;
            }
            return Colors.transparent;
          }),
        ),
      ),
      inputDecorationTheme: _inputDecorationTheme(scheme),
      dropdownMenuTheme: _dropdownMenuTheme(scheme),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: scheme.secondaryContainer,
        backgroundColor: scheme.surface,
      ),
    );
  }

  static ThemeData dark({
    required Color primary,
    required Color secondary,
    Color onPrimary = Colors.white,
  }) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: secondary,
      onPrimary: onPrimary,
      brightness: Brightness.dark,
    );
    final TextTheme base =
        Typography.material2021(platform: TargetPlatform.android).white;
    final TextTheme textTheme = _withDropdownItemFontSize(
      AppTextStyles.textTheme(scheme, base),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _actionPrimary(scheme, Brightness.dark),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _actionPrimary(scheme, Brightness.dark),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith<Color?>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return scheme.onSurface;
          }),
          backgroundColor: WidgetStateProperty.resolveWith<Color?>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.selected)) {
              return scheme.primary;
            }
            return Colors.transparent;
          }),
        ),
      ),
      inputDecorationTheme: _inputDecorationTheme(scheme),
      dropdownMenuTheme: _dropdownMenuTheme(scheme),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: scheme.secondaryContainer,
        backgroundColor: scheme.surface,
      ),
    );
  }
}
