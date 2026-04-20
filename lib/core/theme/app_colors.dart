import 'package:flutter/material.dart';

class ThemePreset {
  const ThemePreset({
    required this.name,
    required this.primary,
    required this.secondary,
    this.accent,
    this.onPrimary = Colors.white,
  });

  final String name;
  final Color primary;
  final Color secondary;
  final Color? accent;

  /// Foreground on [FilledButton] / primary actions (e.g. black on lighter primaries).
  final Color onPrimary;
}

/// Central color tokens for light/dark themes and builder UI.
abstract final class AppColors {
  static const Color primary = Color(0xFF6750A4);
  static const Color secondary = Color(0xFF625B71);
  static const Color error = Color(0xFFB3261E);
  static const Color surfaceTint = Color(0xFF6750A4);

  /// Muted fills (empty states, disabled options).
  static const Color neutralOutline = Color(0xFFCAC4D0);

  static const String defaultPresetName = 'Ocean Blue';

  static const List<ThemePreset> presets = <ThemePreset>[
    ThemePreset(
      name: 'Ocean Blue',
      primary: Color(0xFF1565C0),
      secondary: Color(0xFF26A69A),
      accent: Color(0xFF81D4FA),
      onPrimary: Colors.black,
    ),
    ThemePreset(
      name: 'Sunset',
      primary: Color(0xFFEF6C00),
      secondary: Color(0xFFD84315),
      accent: Color(0xFFFFCC80),
      onPrimary: Colors.black,
    ),
    ThemePreset(
      name: 'Dark Purple',
      primary: Color(0xFF6A1B9A),
      secondary: Color(0xFF8E24AA),
      accent: Color(0xFFCE93D8),
    ),
    ThemePreset(
      name: 'Forest Green',
      primary: Color(0xFF2E7D32),
      secondary: Color(0xFF00897B),
      accent: Color(0xFFA5D6A7),
    ),
    ThemePreset(
      name: 'Ruby Red',
      primary: Color(0xFFC62828),
      secondary: Color(0xFFD81B60),
      accent: Color(0xFFEF9A9A),
    ),
    ThemePreset(
      name: 'Indigo Night',
      primary: Color(0xFF283593),
      secondary: Color(0xFF5C6BC0),
      accent: Color(0xFF9FA8DA),
    ),
  ];

  static ThemePreset presetByName(String name) {
    for (final ThemePreset preset in presets) {
      if (preset.name == name) {
        return preset;
      }
    }
    return presets.first;
  }
}
