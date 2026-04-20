import 'package:antwise/core/app_snackbar.dart';
import 'package:antwise/domain/entities/bottom_nav_layout_type.dart';
import 'package:antwise/domain/entities/builder_page_entity.dart';
import 'package:antwise/domain/entities/drawer_nav_layout_type.dart';
import 'package:antwise/domain/entities/navigation_config_entity.dart';
import 'package:antwise/domain/usecases/get_builder_pages_usecase.dart';
import 'package:antwise/domain/validation/bottom_nav_layout_rules.dart';
import 'package:antwise/domain/usecases/get_navigation_config_usecase.dart';
import 'package:antwise/domain/usecases/replace_builder_pages_usecase.dart';
import 'package:antwise/domain/usecases/save_navigation_config_usecase.dart';
import 'package:antwise/presentation/controllers/home_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingsController extends GetxController {
  SettingsController(
    this._getPages,
    this._replacePages,
    this._getConfig,
    this._saveConfig,
  );

  final GetBuilderPagesUseCase _getPages;
  final ReplaceBuilderPagesUseCase _replacePages;
  final GetNavigationConfigUseCase _getConfig;
  final SaveNavigationConfigUseCase _saveConfig;

  final RxList<BuilderPageEntity> pages = <BuilderPageEntity>[].obs;
  final RxList<String> bottomOrder = <String>[].obs;
  final RxList<String> drawerOrder = <String>[].obs;
  final RxnString mainPageId = RxnString();
  final Rx<BottomNavLayoutType> bottomNavLayout =
      BottomNavLayoutType.standard.obs;
  final RxnString bottomNavCenterPageId = RxnString();
  final RxBool bottomNavShowLabels = true.obs;
  final Rx<DrawerNavLayoutType> drawerNavLayout =
      DrawerNavLayoutType.softCard.obs;
  final RxBool isLoading = true.obs;

  /// Bumps when [pages] metadata changes (e.g. icon) so Obx lists rebuild.
  final RxInt pagesRevision = 0.obs;

  List<BuilderPageEntity> get deletedPages =>
      pages.where((BuilderPageEntity p) => p.isDeleted).toList(growable: false);

  /// True when Floating Center is allowed for the current bottom-nav page count.
  bool get canApplyFloatingCenterLayout =>
      BottomNavLayoutRules.isFloatingCenterValidForBottomCount(
        bottomOrder.length,
      );

  /// False only when Floating Center is selected but the bottom count is invalid.
  bool get isFloatingCenterRuleSatisfied =>
      bottomNavLayout.value != BottomNavLayoutType.floatingCenterAction ||
      canApplyFloatingCenterLayout;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      final List<BuilderPageEntity> pageList = await _getPages();
      final NavigationConfigEntity? config = await _getConfig();
      pages.assignAll(pageList);
      bottomOrder.assignAll(
        _resolvedOrder(
          explicitOrder: config?.bottomPageIds ?? <String>[],
          fallbackIds: pageList
              .where((BuilderPageEntity p) => p.showInBottomNav && !p.isDeleted)
              .map((BuilderPageEntity p) => p.id),
        ),
      );
      drawerOrder.assignAll(
        _resolvedOrder(
          explicitOrder: config?.drawerPageIds ?? <String>[],
          fallbackIds: pageList
              .where((BuilderPageEntity p) => p.showInDrawer && !p.isDeleted)
              .map((BuilderPageEntity p) => p.id),
        ),
      );
      mainPageId.value = config?.mainPageId ?? _pickDefaultMainPage();
      bottomNavLayout.value =
          config?.bottomNavLayout ?? BottomNavLayoutType.standard;
      bottomNavCenterPageId.value = config?.bottomNavCenterPageId;
      bottomNavShowLabels.value = config?.bottomNavShowLabels ?? true;
      drawerNavLayout.value =
          config?.drawerNavLayout ?? DrawerNavLayoutType.softCard;
      _ensureMainStillValid();
      final bool repairedFloating = _ensureFloatingCenterOrRevert(
        notify: false,
      );
      _ensureCenterStillValid();
      pagesRevision.value++;
      if (repairedFloating) {
        await _save();
      }
    } finally {
      isLoading.value = false;
    }
  }

  List<String> _resolvedOrder({
    required List<String> explicitOrder,
    required Iterable<String> fallbackIds,
  }) {
    final Set<String> existingIds =
        pages
            .where((BuilderPageEntity p) => !p.isDeleted)
            .map((BuilderPageEntity p) => p.id)
            .toSet();
    final List<String> ordered = explicitOrder
        .where(existingIds.contains)
        .toList(growable: true);
    for (final String id in fallbackIds) {
      if (!ordered.contains(id) && existingIds.contains(id)) {
        ordered.add(id);
      }
    }
    return ordered;
  }

  String? _pickDefaultMainPage() {
    if (bottomOrder.isNotEmpty) {
      return bottomOrder.first;
    }
    if (drawerOrder.isNotEmpty) {
      return drawerOrder.first;
    }
    return null;
  }

  BuilderPageEntity? pageById(String id) {
    for (final BuilderPageEntity p in pages) {
      if (p.id == id && !p.isDeleted) {
        return p;
      }
    }
    return null;
  }

  void reorderBottom(int oldIndex, int newIndex) {
    _reorder(bottomOrder, oldIndex, newIndex);
    if (bottomOrder.isNotEmpty) {
      mainPageId.value = bottomOrder.first;
    } else {
      _ensureMainStillValid();
    }
    _ensureFloatingCenterOrRevert(notify: false);
    _ensureCenterStillValid();
    _save();
  }

  void reorderDrawer(int oldIndex, int newIndex) {
    _reorder(drawerOrder, oldIndex, newIndex);
    if (bottomOrder.isEmpty && drawerOrder.isNotEmpty) {
      mainPageId.value = drawerOrder.first;
    } else {
      _ensureMainStillValid();
    }
    _save();
  }

  List<String> get drawerParentIds => drawerOrder
      .where((String id) {
        final BuilderPageEntity? page = pageById(id);
        return page != null && _isTopLevelDrawerPage(page);
      })
      .toList(growable: false);

  List<String> drawerChildIdsOf(String parentId) => drawerOrder
      .where((String id) {
        final BuilderPageEntity? page = pageById(id);
        return page != null && page.parentPageId == parentId;
      })
      .toList(growable: false);

  void reorderDrawerParents(int oldIndex, int newIndex) {
    final List<String> parents = drawerParentIds.toList(growable: true);
    _reorderList(parents, oldIndex, newIndex);
    _rebuildDrawerOrder(parentOrder: parents);
    _save();
  }

  void reorderDrawerChildren(String parentId, int oldIndex, int newIndex) {
    final List<String> parents = drawerParentIds.toList(growable: true);
    final Map<String, List<String>> childOrder = <String, List<String>>{
      for (final String parent in parents)
        parent: drawerChildIdsOf(parent).toList(growable: true),
    };
    final List<String>? target = childOrder[parentId];
    if (target == null) {
      return;
    }
    _reorderList(target, oldIndex, newIndex);
    _rebuildDrawerOrder(parentOrder: parents, childOrder: childOrder);
    _save();
  }

  void _reorder(RxList<String> target, int oldIndex, int newIndex) {
    _reorderList(target, oldIndex, newIndex);
  }

  void _reorderList(List<String> target, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final String item = target.removeAt(oldIndex);
    target.insert(newIndex, item);
  }

  bool _isTopLevelDrawerPage(BuilderPageEntity page) {
    final String? parentId = page.parentPageId;
    if (parentId == null || parentId == page.id) {
      return true;
    }
    final BuilderPageEntity? parent = pageById(parentId);
    return parent == null || !parent.showInDrawer;
  }

  void _rebuildDrawerOrder({
    required List<String> parentOrder,
    Map<String, List<String>>? childOrder,
  }) {
    final Map<String, List<String>> resolvedChildOrder =
        childOrder ??
        <String, List<String>>{
          for (final String parent in parentOrder)
            parent: drawerChildIdsOf(parent).toList(growable: false),
        };
    final List<String> next = <String>[];
    for (final String parentId in parentOrder) {
      if (!drawerOrder.contains(parentId)) {
        continue;
      }
      next.add(parentId);
      final List<String> children =
          resolvedChildOrder[parentId] ?? const <String>[];
      for (final String childId in children) {
        if (!drawerOrder.contains(childId)) {
          continue;
        }
        final BuilderPageEntity? childPage = pageById(childId);
        if (childPage == null || childPage.parentPageId != parentId) {
          continue;
        }
        next.add(childId);
      }
    }
    for (final String id in drawerOrder) {
      if (!next.contains(id)) {
        next.add(id);
      }
    }
    drawerOrder.assignAll(next);
    if (bottomOrder.isEmpty && drawerOrder.isNotEmpty) {
      mainPageId.value = drawerOrder.first;
    } else {
      _ensureMainStillValid();
    }
  }

  Future<void> setMainPage(String id) async {
    mainPageId.value = id;
    await _save();
  }

  Future<void> removeFromBottom(String id) async {
    if (!bottomOrder.contains(id)) {
      return;
    }
    if (bottomOrder.length <= 2) {
      showAppSnackbar(
        'Validation',
        'Bottom navigation requires at least 2 pages',
      );
      return;
    }
    final bool confirmed = await _confirmRemoval();
    if (!confirmed) {
      return;
    }
    _softDelete(id);
    bottomOrder.remove(id);
    drawerOrder.remove(id);
    if (bottomNavCenterPageId.value == id) {
      bottomNavCenterPageId.value = null;
    }
    _ensureMainStillValid();
    _ensureFloatingCenterOrRevert(notify: true);
    _ensureCenterStillValid();
    await _save();
  }

  Future<void> removeFromDrawer(String id) async {
    if (!drawerOrder.contains(id)) {
      return;
    }
    final BuilderPageEntity? page = pageById(id);
    if (page != null && page.showInBottomNav && bottomOrder.length <= 2) {
      showAppSnackbar(
        'Validation',
        'Bottom navigation requires at least 2 pages',
      );
      return;
    }
    final bool confirmed = await _confirmRemoval();
    if (!confirmed) {
      return;
    }
    _softDelete(id);
    drawerOrder.remove(id);
    bottomOrder.remove(id);
    if (bottomNavCenterPageId.value == id) {
      bottomNavCenterPageId.value = null;
    }
    _ensureMainStillValid();
    _ensureFloatingCenterOrRevert(notify: true);
    _ensureCenterStillValid();
    await _save();
  }

  Future<void> softDeleteAllBottomPages() async {
    if (bottomOrder.isEmpty) {
      showAppSnackbar('Bottom navigation', 'No pages to delete');
      return;
    }
    final bool confirmed = await _confirmBulkRemoval();
    if (!confirmed) {
      return;
    }
    final List<String> ids = bottomOrder.toList(growable: false);
    for (final String id in ids) {
      _softDelete(id);
    }
    bottomOrder.clear();
    drawerOrder.removeWhere(ids.contains);
    bottomNavCenterPageId.value = null;
    _ensureMainStillValid();
    _ensureFloatingCenterOrRevert(notify: true);
    _ensureCenterStillValid();
    await _save();
  }

  Future<void> restoreDeletedPage(String id) async {
    final List<BuilderPageEntity> next = pages
        .map((BuilderPageEntity p) {
          if (p.id != id) {
            return p;
          }
          final bool restoreBottom = p.showInBottomNav;
          final bool restoreDrawer = p.showInDrawer || !restoreBottom;
          return p.copyWith(
            showInBottomNav: restoreBottom,
            showInDrawer: restoreDrawer,
            isDeleted: false,
          );
        })
        .toList(growable: false);
    pages.assignAll(next);
    final BuilderPageEntity? restored = pageById(id);
    if (restored == null) {
      return;
    }
    if (restored.showInBottomNav && !bottomOrder.contains(id)) {
      bottomOrder.add(id);
    }
    if (restored.showInDrawer && !drawerOrder.contains(id)) {
      drawerOrder.add(id);
    }
    _ensureMainStillValid();
    _ensureFloatingCenterOrRevert(notify: true);
    _ensureCenterStillValid();
    await _save();
  }

  Future<void> setBottomNavLayout(BottomNavLayoutType layout) async {
    if (layout == BottomNavLayoutType.floatingCenterAction &&
        !BottomNavLayoutRules.isFloatingCenterValidForBottomCount(
          bottomOrder.length,
        )) {
      showAppSnackbar(
        'Bottom navigation',
        BottomNavLayoutRules.floatingCenterSnackbarMessage,
      );
      return;
    }
    bottomNavLayout.value = layout;
    _ensureCenterStillValid();
    await _save();
  }

  Future<void> setCenterPage(String pageId) async {
    if (!bottomOrder.contains(pageId)) {
      return;
    }
    bottomNavCenterPageId.value = pageId;
    await _save();
  }

  Future<void> setBottomNavShowLabels(bool value) async {
    bottomNavShowLabels.value = value;
    await _save();
  }

  Future<void> setDrawerNavLayout(DrawerNavLayoutType value) async {
    drawerNavLayout.value = value;
    if (Get.isRegistered<HomeController>()) {
      Get.find<HomeController>().setDrawerNavLayout(value);
    }
    await _save();
  }

  Future<void> updatePageDetails(
    String pageId, {
    required String iconName,
    required String name,
  }) async {
    final String trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      showAppSnackbar('Validation', 'Page name is required');
      return;
    }
    final List<BuilderPageEntity> next = pages
        .map((BuilderPageEntity p) {
          if (p.id != pageId) {
            return p;
          }
          return p.copyWith(name: trimmedName, iconName: iconName);
        })
        .toList(growable: false);
    pages.assignAll(next);
    pagesRevision.value++;
    await _replacePages(next);
    _reloadHomeNavigation();
    if (Get.isSnackbarOpen) {
      await Get.closeCurrentSnackbar();
    }
    showAppSnackbar('Page', 'Page details saved');
  }

  Future<bool> _confirmRemoval() async {
    final bool? ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Remove page from navigation?'),
        content: const Text('This only removes placement from navigation.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<bool> _confirmBulkRemoval() async {
    final bool? ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Delete all bottom-nav pages?'),
        content: const Text(
          'All pages currently in bottom navigation will be soft deleted. '
          'You can restore them from delete history.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  void _softDelete(String id) {
    final List<BuilderPageEntity> next = pages
        .map((BuilderPageEntity p) {
          if (p.id != id) {
            return p;
          }
          return p.copyWith(isDeleted: true);
        })
        .toList(growable: false);
    pages.assignAll(next);
  }

  void _ensureMainStillValid() {
    final String? id = mainPageId.value;
    if (id == null) {
      mainPageId.value = _pickDefaultMainPage();
      return;
    }
    if (!bottomOrder.contains(id) && !drawerOrder.contains(id)) {
      mainPageId.value = _pickDefaultMainPage();
    }
  }

  void _ensureCenterStillValid() {
    if (!bottomNavLayout.value.needsCenterPageSelection) {
      return;
    }
    if (bottomOrder.isEmpty) {
      bottomNavCenterPageId.value = null;
      return;
    }
    final String? c = bottomNavCenterPageId.value;
    if (c != null && bottomOrder.contains(c)) {
      return;
    }
    bottomNavCenterPageId.value = bottomOrder[bottomOrder.length ~/ 2];
  }

  /// If Floating Center is stored but the bottom count is invalid, fall back to
  /// [BottomNavLayoutType.centerIconEmphasis] so nothing invalid is persisted.
  bool _ensureFloatingCenterOrRevert({required bool notify}) {
    if (bottomNavLayout.value != BottomNavLayoutType.floatingCenterAction) {
      return false;
    }
    if (BottomNavLayoutRules.isFloatingCenterValidForBottomCount(
      bottomOrder.length,
    )) {
      return false;
    }
    bottomNavLayout.value = BottomNavLayoutType.centerIconEmphasis;
    if (notify) {
      showAppSnackbar(
        'Bottom navigation',
        BottomNavLayoutRules.floatingCenterRevertedSnackbarMessage,
      );
    }
    return true;
  }

  Future<void> _save() async {
    await _replacePages(pages);
    await _saveConfig(
      NavigationConfigEntity(
        bottomPageIds: bottomOrder.toList(growable: false),
        drawerPageIds: drawerOrder.toList(growable: false),
        activePageId: mainPageId.value,
        mainPageId: mainPageId.value,
        bottomNavLayout: bottomNavLayout.value,
        bottomNavCenterPageId: bottomNavCenterPageId.value,
        bottomNavShowLabels: bottomNavShowLabels.value,
        drawerNavLayout: drawerNavLayout.value,
      ),
    );
    _reloadHomeNavigation();
  }

  void _reloadHomeNavigation() {
    if (Get.isRegistered<HomeController>()) {
      Get.find<HomeController>().loadPages();
    }
  }
}
