import 'package:antwise/domain/entities/bottom_nav_layout_type.dart';
import 'package:antwise/domain/entities/drawer_nav_layout_type.dart';

class NavigationConfigEntity {
  const NavigationConfigEntity({
    required this.bottomPageIds,
    required this.drawerPageIds,
    required this.activePageId,
    required this.mainPageId,
    this.bottomNavLayout = BottomNavLayoutType.standard,
    this.bottomNavCenterPageId,
    this.bottomNavShowLabels = true,
    this.drawerNavLayout = DrawerNavLayoutType.softCard,
  });

  final List<String> bottomPageIds;
  final List<String> drawerPageIds;
  final String? activePageId;
  final String? mainPageId;

  /// Stored bottom navigation layout template.
  final BottomNavLayoutType bottomNavLayout;

  /// Page id for the floating center FAB; used when [bottomNavLayout] is [BottomNavLayoutType.floatingCenterAction].
  final String? bottomNavCenterPageId;

  /// When false, bottom navigation shows icons only (no text labels).
  final bool bottomNavShowLabels;

  /// Stored drawer navigation layout template.
  final DrawerNavLayoutType drawerNavLayout;
}
