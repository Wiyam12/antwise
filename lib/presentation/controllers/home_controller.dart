import 'dart:convert';
import 'dart:io';

import 'package:antwise/core/storage/hive_boxes.dart';
import 'package:antwise/data/models/hive/app_settings_hive_model.dart';
import 'package:antwise/data/models/hive/builder_page_hive_model.dart';
import 'package:antwise/data/models/hive/builder_widget_hive_model.dart';
import 'package:antwise/data/models/hive/navigation_config_hive_model.dart';
import 'package:antwise/data/models/hive/table_row_hive_model.dart';
import 'package:antwise/data/models/hive/table_schema_hive_model.dart';
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
import 'package:hive/hive.dart';

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
  final RxBool firstInstallCompleted = false.obs;
  final RxBool isApplyingSetupTemplate = false.obs;

  /// Increment to remount [DynamicBuilderPageBody] so table/widget data reloads
  /// from storage (e.g. after editing a table under settings while home stays in stack).
  final RxInt builderContentRevision = 0.obs;

  List<BuilderPageEntity> get bottomPages => _orderedPages(
    pages
        .where(
          (BuilderPageEntity p) =>
              p.showInBottomNav && !p.isDeleted && !p.isDrawerParentContainer,
        )
        .toList(),
    _bottomOrder,
  );

  List<BuilderPageEntity> get drawerPages => _orderedPages(
    pages
        .where(
          (BuilderPageEntity p) =>
              p.showInDrawer && !p.isDeleted && p.nestedDisplayType == null,
        )
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

  bool get hasPages => pages.any(_isUsablePage);
  bool get shouldShowSetupMode => !hasPages && !firstInstallCompleted.value;

  bool get shouldShowBottomNav => bottomPages.length >= 2;

  bool get shouldShowDrawer => drawerPages.isNotEmpty;

  BuilderPageEntity? get selectedPage {
    final String? id = selectedPageId.value;
    if (id == null) {
      return null;
    }
    try {
      final BuilderPageEntity page = pages.firstWhere(
        (BuilderPageEntity p) => p.id == id && !p.isDeleted,
      );
      if (!page.isDrawerParentContainer) {
        return page;
      }
      return _firstUsableChildOf(page.id);
    } catch (_) {
      return null;
    }
  }

  @override
  void onInit() {
    super.onInit();
    final Map<String, dynamic>? args =
        Get.arguments is Map<String, dynamic>
            ? Get.arguments as Map<String, dynamic>
            : null;
    loadPages(preferredPageId: args?['selectedPageId'] as String?);
  }

  Future<void> loadPages({String? preferredPageId}) async {
    isLoading.value = true;
    try {
      _loadInstallState();
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

  void _loadInstallState() {
    if (!Hive.isBoxOpen(HiveBoxes.settingsBox)) {
      firstInstallCompleted.value = false;
      return;
    }
    final Box<AppSettingsHiveModel> box = Hive.box<AppSettingsHiveModel>(
      HiveBoxes.settingsBox,
    );
    final AppSettingsHiveModel? settings = box.get(_settingsKey);
    firstInstallCompleted.value = settings?.firstInstallCompleted ?? false;
  }

  Future<void> _markSetupCompleted() async {
    if (!Hive.isBoxOpen(HiveBoxes.settingsBox)) {
      return;
    }
    final Box<AppSettingsHiveModel> box = Hive.box<AppSettingsHiveModel>(
      HiveBoxes.settingsBox,
    );
    final AppSettingsHiveModel? old = box.get(_settingsKey);
    await box.put(
      _settingsKey,
      AppSettingsHiveModel(
        resourcesDownloaded: old?.resourcesDownloaded ?? false,
        themeMode: old?.themeMode ?? 'system',
        firstInstallCompleted: true,
        themePresetName: old?.themePresetName ?? 'Ocean Blue',
      ),
    );
    firstInstallCompleted.value = true;
  }

  Future<void> chooseAdvanceMode() async {
    await _markSetupCompleted();
    await loadPages();
  }

  Future<void> applySimplePosTemplate() async {
    if (isApplyingSetupTemplate.value) {
      return;
    }
    isApplyingSetupTemplate.value = true;
    try {
      final File snapshotFile = File(_simplePosSnapshotPath);
      if (!snapshotFile.existsSync()) {
        Get.snackbar(
          'Template',
          'Snapshot file not found: $_simplePosSnapshotPath',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
      final String raw = await snapshotFile.readAsString();
      final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
      final List<Map<String, dynamic>> pagesRaw = _asMapList(json['pages']);
      final List<Map<String, dynamic>> tablesRaw = _asMapList(json['tables']);
      final List<Map<String, dynamic>> widgetsRaw = _asMapList(json['widgets']);

      if (Hive.isBoxOpen(HiveBoxes.pagesBox)) {
        final Box<BuilderPageHiveModel> pagesBox =
            Hive.box<BuilderPageHiveModel>(HiveBoxes.pagesBox);
        await pagesBox.clear();
        for (final Map<String, dynamic> page in pagesRaw) {
          final BuilderPageHiveModel model = BuilderPageHiveModel(
            id: (page['id'] ?? '').toString(),
            name: (page['name'] ?? '').toString(),
            icon: (page['icon'] ?? 'article_outlined').toString(),
            navigationType: (page['navigationType'] ?? 'drawer').toString(),
            isDeleted: page['isDeleted'] == true,
            isDrawerParentContainer: page['isDrawerParentContainer'] == true,
            parentPageId: page['parentPageId']?.toString(),
            nestedDisplayType: page['nestedDisplayType']?.toString(),
            nestedRootContentTabName:
                page['nestedRootContentTabName']?.toString(),
            widgetGridCount: (page['widgetGridCount'] as num?)?.toInt() ?? 1,
            layoutOrder: _asStringList(page['layoutOrder']),
            widgetOrder: _asStringList(page['widgetOrder']),
          );
          await pagesBox.put(model.id, model);
        }
      }

      if (Hive.isBoxOpen(HiveBoxes.tablesBox)) {
        final Box<TableSchemaHiveModel> tablesBox =
            Hive.box<TableSchemaHiveModel>(HiveBoxes.tablesBox);
        await tablesBox.clear();
        for (final Map<String, dynamic> table in tablesRaw) {
          final TableSchemaHiveModel model = TableSchemaHiveModel(
            id: (table['id'] ?? '').toString(),
            pageId: (table['pageId'] ?? '').toString(),
            name: (table['name'] ?? '').toString(),
            description: (table['description'] ?? '').toString(),
            mode: (table['mode'] ?? 'crud').toString(),
            layoutType: (table['layoutType'] ?? 'vertical').toString(),
            listDesignLayout:
                (table['listDesignLayout'] ?? 'standard').toString(),
            swipeToDelete: table['swipeToDelete'] == true,
            productDisplayMode:
                (table['productDisplayMode'] ?? 'list').toString(),
            tableKind: (table['tableKind'] ?? 'standard').toString(),
            summaryConfig: _asNullableMap(table['summaryConfig']),
            inventoryDeduction: _asNullableMap(table['inventoryDeduction']),
            affectingTables: _asMapList(table['affectingTables']),
            validationRules: _asMapList(table['validationRules']),
            searchEnabled: table['searchEnabled'] == true,
            dataLoadingMode: (table['dataLoadingMode'] ?? 'lazy').toString(),
            pageSize: (table['pageSize'] as num?)?.toInt() ?? 10,
            lazyInitialLoad: (table['lazyInitialLoad'] as num?)?.toInt() ?? 5,
            columns: _asMapList(table['columns']),
          );
          await tablesBox.put(model.id, model);
        }
      }

      if (Hive.isBoxOpen(HiveBoxes.widgetsBox)) {
        final Box<BuilderWidgetHiveModel> widgetsBox =
            Hive.box<BuilderWidgetHiveModel>(HiveBoxes.widgetsBox);
        await widgetsBox.clear();
        for (final Map<String, dynamic> widget in widgetsRaw) {
          final BuilderWidgetHiveModel model = BuilderWidgetHiveModel(
            id: (widget['id'] ?? '').toString(),
            pageId: (widget['pageId'] ?? '').toString(),
            type: (widget['type'] ?? 'card').toString(),
            config: _asStringDynamicMap(widget['config']),
          );
          await widgetsBox.put(model.id, model);
        }
      }

      if (Hive.isBoxOpen(HiveBoxes.rowsBox)) {
        final Box<TableRowHiveModel> rowsBox = Hive.box<TableRowHiveModel>(
          HiveBoxes.rowsBox,
        );
        await rowsBox.clear();
      }
      if (Hive.isBoxOpen(HiveBoxes.navigationBox)) {
        await Hive.box<NavigationConfigHiveModel>(HiveBoxes.navigationBox)
            .clear();
      }

      final List<String> bottomPageIds = <String>[];
      final List<String> drawerPageIds = <String>[];
      for (final Map<String, dynamic> page in pagesRaw) {
        if (page['isDeleted'] == true) {
          continue;
        }
        final bool isDrawerParent = page['isDrawerParentContainer'] == true;
        if (isDrawerParent) {
          continue;
        }
        final String id = (page['id'] ?? '').toString();
        if (id.isEmpty) {
          continue;
        }
        final String navType = (page['navigationType'] ?? '').toString();
        if (navType == 'bottom' || navType == 'both') {
          bottomPageIds.add(id);
        }
        if (navType == 'drawer' || navType == 'both') {
          drawerPageIds.add(id);
        }
      }
      final String? mainPageId =
          bottomPageIds.isNotEmpty
              ? bottomPageIds.first
              : (drawerPageIds.isNotEmpty ? drawerPageIds.first : null);
      String? centerPageId;
      if (bottomPageIds.length >= 3 && bottomPageIds.length.isOdd) {
        centerPageId = bottomPageIds[bottomPageIds.length ~/ 2];
      }
      await _saveNavigationConfig(
        NavigationConfigEntity(
          bottomPageIds: bottomPageIds,
          drawerPageIds: drawerPageIds,
          activePageId: mainPageId,
          mainPageId: mainPageId,
          bottomNavLayout:
              BottomNavLayoutType
                  .floatingCenterAction, // design layout option 3
          bottomNavCenterPageId: centerPageId,
          bottomNavShowLabels: true,
          drawerNavLayout: DrawerNavLayoutType.softCard,
        ),
      );

      await _markSetupCompleted();
      await loadPages();
    } catch (e) {
      Get.snackbar(
        'Template',
        'Failed to apply Simple POS template: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isApplyingSetupTemplate.value = false;
    }
  }

  List<Map<String, dynamic>> _asMapList(dynamic raw) {
    if (raw is! List) {
      return const <Map<String, dynamic>>[];
    }
    final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];
    for (final dynamic item in raw) {
      if (item is Map<String, dynamic>) {
        out.add(item);
      } else if (item is Map) {
        out.add(
          item.map<String, dynamic>(
            (dynamic k, dynamic v) =>
                MapEntry<String, dynamic>(k.toString(), v),
          ),
        );
      }
    }
    return out;
  }

  List<String> _asStringList(dynamic raw) {
    if (raw is! List) {
      return const <String>[];
    }
    return raw.map((dynamic e) => e.toString()).toList(growable: false);
  }

  Map<String, dynamic> _asStringDynamicMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return raw.map<String, dynamic>(
        (dynamic k, dynamic v) => MapEntry<String, dynamic>(k.toString(), v),
      );
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic>? _asNullableMap(dynamic raw) {
    final Map<String, dynamic> value = _asStringDynamicMap(raw);
    if (value.isEmpty) {
      return null;
    }
    return value;
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
        pages.any(
          (BuilderPageEntity p) => p.id == preferredPageId && !p.isDeleted,
        )) {
      final String? resolved = _resolveSelectablePageId(preferredPageId);
      if (resolved != null) {
        selectedPageId.value = resolved;
        return;
      }
    }
    final String? current = selectedPageId.value;
    if (current != null &&
        pages.any((BuilderPageEntity p) => p.id == current && !p.isDeleted)) {
      final String? resolved = _resolveSelectablePageId(current);
      if (resolved != null) {
        selectedPageId.value = resolved;
        return;
      }
    }
    final String? main = _mainPageId.value;
    if (main != null &&
        pages.any((BuilderPageEntity p) => p.id == main && !p.isDeleted)) {
      final String? resolved = _resolveSelectablePageId(main);
      if (resolved != null) {
        selectedPageId.value = resolved;
        return;
      }
    }
    if (bottomPages.isNotEmpty) {
      selectedPageId.value = bottomPages.first.id;
      return;
    }
    final BuilderPageEntity? firstDrawerPage = drawerPages.firstWhereOrNull(
      (BuilderPageEntity p) => !p.isDrawerParentContainer,
    );
    if (firstDrawerPage != null) {
      selectedPageId.value = firstDrawerPage.id;
      return;
    }
    final BuilderPageEntity? fallback = pages.firstWhereOrNull(_isUsablePage);
    selectedPageId.value = fallback?.id;
  }

  void selectPage(String id) {
    selectedPageId.value = _resolveSelectablePageId(id);
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

  bool _isUsablePage(BuilderPageEntity p) =>
      !p.isDeleted && !p.isDrawerParentContainer;

  BuilderPageEntity? _firstUsableChildOf(String parentId) {
    for (final BuilderPageEntity page in drawerPages) {
      if (_isUsablePage(page) && page.parentPageId == parentId) {
        return page;
      }
    }
    return pages.firstWhereOrNull(
      (BuilderPageEntity p) => _isUsablePage(p) && p.parentPageId == parentId,
    );
  }

  String? _resolveSelectablePageId(String id) {
    final BuilderPageEntity? page = pages.firstWhereOrNull(
      (BuilderPageEntity p) => p.id == id && !p.isDeleted,
    );
    if (page == null) {
      return null;
    }
    if (!page.isDrawerParentContainer) {
      return page.id;
    }
    final BuilderPageEntity? child = _firstUsableChildOf(page.id);
    return child?.id;
  }

  static const String _settingsKey = 'app_settings';
  static const String _simplePosSnapshotPath =
      '/Users/janicenofuente/Library/Developer/CoreSimulator/Devices/96D78193-4A72-4459-A497-9FA140F2BE76/data/Containers/Data/Application/F0D3D985-89B3-4FFE-9603-B9D28C887D2F/Documents/startup_snapshot_2026-04-29T19-13-04-566480.json';
}
