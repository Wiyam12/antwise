import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Solid snackbar using the theme’s inverse surface (Material 3 snackbar pairing).
void showAppSnackbar(
  String title,
  String message, {
  Duration duration = const Duration(seconds: 3),
}) {
  final ThemeData theme = Get.theme;
  final ColorScheme scheme = theme.colorScheme;
  final SnackBarThemeData snackTheme = theme.snackBarTheme;
  final Color backgroundColor =
      snackTheme.backgroundColor ?? scheme.inverseSurface;
  final Color foregroundColor =
      snackTheme.contentTextStyle?.color ?? scheme.onInverseSurface;
  Get.snackbar(
    title,
    message,
    backgroundColor: backgroundColor,
    colorText: foregroundColor,
    snackPosition: SnackPosition.BOTTOM,
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    borderRadius: 12,
    duration: duration,
    // GetX defaults to barBlur 7 + translucent grey when background is omitted.
    barBlur: 0,
    shouldIconPulse: false,
  );
}
