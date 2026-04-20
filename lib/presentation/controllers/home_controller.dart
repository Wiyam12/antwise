import 'package:antwise/domain/entities/bottom_nav_layout_type.dart';
import 'package:antwise/domain/entities/builder_page_entity.dart';
import 'package:antwise/domain/entities/drawer_nav_layout_type.dart';
import 'package:antwise/domain/entities/navigation_config_entity.dart';
import 'package:antwise/domain/usecases/get_builder_pages_usecase.dart';
import 'package:antwise/domain/usecases/get_navigation_config_usecase.dart';
import 'package:antwise/domain/usecases/save_navigation_config_usecase.dart';
import 'package:antwise/domain/validation/bottom_nav_layout_rules.dart';
import 'package:antwise/presentation/routes/app_routes.dart';
import 'package:get/get.dart';

class HomeController extends GetxController {
  HomeController(
    this._getPages,
    this._getNavigationConfig,
    this._saveNavigationConfig,
  );

  final GetBuilderPagesUseCase _getPages;
  final GetNavigationConfigUseCase _getNavigationConfig;
  final SaveNavigationConfigUseCase _saveNavigationConfig;

  final RxList<BuilderPageEntity> pages = <BuilderPageEntity>[].obs;
  final RxnString selectedPageId = RxnString();
  final RxBool isLoading = true.obs;

  /// Increment to remount [DynamicBuilderPageBody] so table/widget data reloads
  /// from storage (e.g. after editing a table under settings while home stays in stack).
  final RxInt builderContentRevision = 0.obs;

  List<BuilderPageEntity> get bottomPages => _orderedPages(
    pages
        .where((BuilderPageEntity p) => p.showInBottomNav && !p.isDeleted)
        .toList(),
    _bottomOrder,
  );

  List<BuilderPageEntity> get drawerPages => _orderedPages(
    pages
        .where((BuilderPageEntity p) => p.showInDrawer && !p.isDeleted)
        .toList(),
    _drawerOrder,
  );

  final RxList<String> _bottomOrder = <String>[].obs;
  final RxList<String> _drawerOrder = <String>[].obs;
  final RxnString _mainPageId = RxnString();
  final Rx<BottomNavLayoutType> bottomNavLayout =
      BottomNavLayoutType.standard.obs;
  final RxnString bottomNavCenterPageId = RxnString();
  final RxBool bottomNavShowLabels = true.obs;
  final Rx<DrawerNavLayoutType> drawerNavLayout =
      DrawerNavLayoutType.softCard.obs;

  bool get hasPages => pages.any((BuilderPageEntity p) => !p.isDeleted);

  bool get shouldShowBottomNav => bottomPages.length >= 2;

  bool get shouldShowDrawer => drawerPages.isNotEmpty;

  BuilderPageEntity? get selectedPage {
    final String? id = selectedPageId.value;
    if (id == null) {
      return null;
    }
    try {
      return pages.firstWhere(
        (BuilderPageEntity p) => p.id == id && !p.isDeleted,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  void onInit() {
    super.onInit();
    final Map<String, dynamic>? args =
        Get.arguments is Map<String, dynamic> ? Get.arguments as Map<String, dynamic> : null;
    loadPages(preferredPageId: args?['selectedPageId'] as String?);
  }

  Future<void> loadPages({String? preferredPageId}) async {
    isLoading.value = true;
    try {
      final List<BuilderPageEntity> list = await _getPages();
      final NavigationConfigEntity? config = await _getNavigationConfig();
      pages.assignAll(list);
      _bottomOrder.assignAll(config?.bottomPageIds ?? <String>[]);
      _drawerOrder.assignAll(config?.drawerPageIds ?? <String>[]);
      _mainPageId.value = config?.mainPageId;
      bottomNavLayout.value =
          config?.bottomNavLayout ?? BottomNavLayoutType.standard;
      bottomNavCenterPageId.value = config?.bottomNavCenterPageId;
      bottomNavShowLabels.value = config?.bottomNavShowLabels ?? true;
      drawerNavLayout.value =
          config?.drawerNavLayout ?? DrawerNavLayoutType.softCard;
      if (bottomNavLayout.value == BottomNavLayoutType.floatingCenterAction &&
          !BottomNavLayoutRules.isFloatingCenterValidForBottomCount(
            bottomPages.length,
          )) {
        bottomNavLayout.value = BottomNavLayoutType.centerIconEmphasis;
        await _saveNavigationConfig(
          NavigationConfigEntity(
            bottomPageIds:
                config?.bottomPageIds ?? _bottomOrder.toList(growable: false),
            drawerPageIds:
                config?.drawerPageIds ?? _drawerOrder.toList(growable: false),
            activePageId: config?.activePageId ?? _mainPageId.value,
            mainPageId: config?.mainPageId ?? _mainPageId.value,
            bottomNavLayout: bottomNavLayout.value,
            bottomNavCenterPageId: bottomNavCenterPageId.value,
            bottomNavShowLabels: bottomNavShowLabels.value,
            drawerNavLayout: drawerNavLayout.value,
          ),
        );
      }
      _ensureSelection(preferredPageId: preferredPageId);
    } finally {
      isLoading.value = false;
    }
  }

  List<BuilderPageEntity> _orderedPages(
    List<BuilderPageEntity> source,
    List<String> order,
  ) {
    if (source.isEmpty) {
      return source;
    }
    final Map<String, BuilderPageEntity> map = <String, BuilderPageEntity>{
      for (final BuilderPageEntity p in source) p.id: p,
    };
    final List<BuilderPageEntity> out = <BuilderPageEntity>[];
    final String? main = _mainPageId.value;
    if (main != null && map.containsKey(main)) {
      out.add(map.remove(main)!);
    }
    for (final String id in order) {
      final BuilderPageEntity? page = map.remove(id);
      if (page != null) {
        out.add(page);
      }
    }
    out.addAll(map.values);
    return out;
  }

  void _ensureSelection({String? preferredPageId}) {
    if (!hasPages) {
      selectedPageId.value = null;
      return;
    }
    if (preferredPageId != null &&
        pages.any((BuilderPageEntity p) => p.id == preferredPageId && !p.isDeleted)) {
      selectedPageId.value = preferredPageId;
      return;
    }
    final String? current = selectedPageId.value;
    if (current != null &&
        pages.any((BuilderPageEntity p) => p.id == current && !p.isDeleted)) {
      return;
    }
    final String? main = _mainPageId.value;
    if (main != null &&
        pages.any((BuilderPageEntity p) => p.id == main && !p.isDeleted)) {
      selectedPageId.value = main;
      return;
    }
    selectedPageId.value =
        bottomPages.isNotEmpty ? bottomPages.first.id : drawerPages.first.id;
  }

  void selectPage(String id) {
    selectedPageId.value = id;
  }

  void refreshBuilderPageContent() {
    builderContentRevision.value++;
  }

  void setDrawerNavLayout(DrawerNavLayoutType value) {
    drawerNavLayout.value = value;
  }

  void openCreateHub() {
    Get.toNamed<void>(AppRoutes.createPage);
  }

  Future<void> openSettings() async {
    await Get.toNamed<void>(AppRoutes.settings);
    await loadPages();
  }

  void openCreateNewPage() {
    Get.toNamed<void>(AppRoutes.createNewPage);
  }
}
