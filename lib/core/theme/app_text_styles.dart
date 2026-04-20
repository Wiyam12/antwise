import 'package:antwise/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Reusable text style helpers layered on [TextTheme].
abstract final class AppTextStyles {
  static TextTheme textTheme(ColorScheme scheme, TextTheme base) {
    return base.copyWith(
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        color: scheme.onSurface,
        height: 1.35,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant,
        height: 1.35,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: scheme.primary,
      ),
    );
  }

  static TextStyle emptyStateTitle(TextTheme theme) =>
      theme.headlineSmall ?? const TextStyle(fontSize: 22, fontWeight: FontWeight.w600);

  static TextStyle emptyStateBody(TextTheme theme) =>
      theme.bodyMedium?.copyWith(color: AppColors.secondary) ??
      TextStyle(fontSize: 14, color: AppColors.secondary);
}
