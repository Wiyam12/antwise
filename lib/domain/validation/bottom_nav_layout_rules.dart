/// Central rules for bottom navigation layout templates (extend for future layouts).
abstract final class BottomNavLayoutRules {
  BottomNavLayoutRules._();

  /// Floating center needs an odd number of bottom-nav slots so a true center FAB exists
  /// (matches app rule: at least 2 bottom pages → valid odd counts are 3, 5, 7, …).
  static bool isFloatingCenterValidForBottomCount(int bottomNavPageCount) {
    if (bottomNavPageCount < 2) {
      return false;
    }
    return bottomNavPageCount.isOdd;
  }

  /// Shown when Floating Center is invalid (snackbar only; keep to one sentence).
  static const String floatingCenterSnackbarMessage =
      'Floating Center requires an odd number of bottom-nav pages.';

  /// When layout is auto-reverted from Floating Center after the bottom count changes.
  static const String floatingCenterRevertedSnackbarMessage =
      'Switched to Center emphasis—an odd number of bottom-nav pages is required.';
}
