/// Visual layout template for the app bottom navigation bar.
enum BottomNavLayoutType {
  /// Icon + label for each destination (Material [NavigationBar]).
  standard,

  /// Same row as standard; the selected destination uses a pill / background.
  centerIconEmphasis,

  /// Left segment, floating center action (FAB), right segment.
  floatingCenterAction,
  ;

  static BottomNavLayoutType fromStorage(String? value) {
    switch (value) {
      case 'centerIconEmphasis':
        return BottomNavLayoutType.centerIconEmphasis;
      case 'floatingCenterAction':
        return BottomNavLayoutType.floatingCenterAction;
      default:
        return BottomNavLayoutType.standard;
    }
  }

  String get storageValue => switch (this) {
    BottomNavLayoutType.standard => 'standard',
    BottomNavLayoutType.centerIconEmphasis => 'centerIconEmphasis',
    BottomNavLayoutType.floatingCenterAction => 'floatingCenterAction',
  };

  /// Only [floatingCenterAction] persists and configures a center page for the FAB.
  bool get needsCenterPageSelection =>
      this == BottomNavLayoutType.floatingCenterAction;
}
