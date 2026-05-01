import 'dart:convert';

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
import 'package:flutter/services.dart';
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
  final RxList<String> accountNames = <String>[].obs;
  final RxString activeAccountName = ''.obs;
  final RxBool forceSetupMode = false.obs;

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
  bool get shouldShowSetupMode =>
      forceSetupMode.value || (!hasPages && !firstInstallCompleted.value);

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
    forceSetupMode.value = args?['forceSetupMode'] == true;
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
      accountNames.assignAll(const <String>[]);
      activeAccountName.value = '';
      return;
    }
    final Box<AppSettingsHiveModel> box = Hive.box<AppSettingsHiveModel>(
      HiveBoxes.settingsBox,
    );
    final AppSettingsHiveModel? settings = box.get(_settingsKey);
    firstInstallCompleted.value = settings?.firstInstallCompleted ?? false;
    accountNames.assignAll(_sanitizeAccountNames(settings?.accountNames));
    activeAccountName.value = settings?.activeAccountName.trim() ?? '';
  }

  Future<void> _markSetupCompleted({
    required String accountName,
    Map<String, dynamic>? accountWorkspaces,
  }) async {
    if (!Hive.isBoxOpen(HiveBoxes.settingsBox)) {
      return;
    }
    final Box<AppSettingsHiveModel> box = Hive.box<AppSettingsHiveModel>(
      HiveBoxes.settingsBox,
    );
    final AppSettingsHiveModel? old = box.get(_settingsKey);
    final List<String> mergedAccounts = _mergeAccountNames(
      old?.accountNames ?? accountNames,
      accountName,
    );
    await box.put(
      _settingsKey,
      AppSettingsHiveModel(
        resourcesDownloaded: old?.resourcesDownloaded ?? false,
        themeMode: old?.themeMode ?? 'system',
        firstInstallCompleted: true,
        themePresetName: old?.themePresetName ?? 'Ocean Blue',
        accountNames: mergedAccounts,
        activeAccountName: accountName.trim(),
        accountWorkspaces:
            accountWorkspaces ?? old?.accountWorkspaces ?? <String, dynamic>{},
      ),
    );
    firstInstallCompleted.value = true;
    accountNames.assignAll(mergedAccounts);
    activeAccountName.value = accountName.trim();
    forceSetupMode.value = false;
  }

  bool isAccountNameUnique(String rawValue) {
    final String candidate = rawValue.trim();
    if (candidate.isEmpty) {
      return false;
    }
    final String normalized = candidate.toLowerCase();
    return !accountNames.any((String name) => name.toLowerCase() == normalized);
  }

  Future<void> chooseAdvanceMode({required String accountName}) async {
    final Map<String, dynamic> workspaces =
        await _captureStoredWorkspacesWithActiveSnapshot();
    await _initializeEmptyWorkspace();
    workspaces[accountName.trim()] = _captureWorkspaceSnapshot(
      accountName: accountName.trim(),
    );
    await _markSetupCompleted(
      accountName: accountName,
      accountWorkspaces: workspaces,
    );
    await loadPages();
  }

  Future<void> applySimplePosTemplate({required String accountName}) async {
    if (isApplyingSetupTemplate.value) {
      return;
    }
    isApplyingSetupTemplate.value = true;
    try {
      final String raw = await rootBundle.loadString(_simplePosSnapshotPath);
      final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
      final List<Map<String, dynamic>> pagesRaw = _asMapList(json['pages']);
      final List<Map<String, dynamic>> tablesRaw = _asMapList(json['tables']);
      final List<Map<String, dynamic>> widgetsRaw = _asMapList(json['widgets']);
      final Map<String, dynamic> navigationRaw = _asStringDynamicMap(
        json['navigation'],
      );

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
        await Hive.box<NavigationConfigHiveModel>(
          HiveBoxes.navigationBox,
        ).clear();
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
      final List<String> savedBottomPageIds = _asStringList(
        navigationRaw['bottomPageIds'],
      );
      final List<String> savedDrawerPageIds = _asStringList(
        navigationRaw['drawerPageIds'],
      );
      final List<String> resolvedBottomPageIds =
          savedBottomPageIds.isEmpty ? bottomPageIds : savedBottomPageIds;
      final List<String> resolvedDrawerPageIds =
          savedDrawerPageIds.isEmpty ? drawerPageIds : savedDrawerPageIds;
      final String? resolvedMainPageId =
          navigationRaw['mainPageId']?.toString() ?? mainPageId;
      final String? resolvedActivePageId =
          navigationRaw['activePageId']?.toString() ?? resolvedMainPageId;

      String? resolvedCenterPageId =
          navigationRaw['bottomNavCenterPageId']?.toString();
      if (resolvedCenterPageId != null &&
          !resolvedBottomPageIds.contains(resolvedCenterPageId)) {
        resolvedCenterPageId = null;
      }
      if (resolvedCenterPageId == null &&
          resolvedBottomPageIds.length >= 3 &&
          resolvedBottomPageIds.length.isOdd) {
        resolvedCenterPageId =
            resolvedBottomPageIds[resolvedBottomPageIds.length ~/ 2];
      }

      BottomNavLayoutType resolvedBottomLayout =
          BottomNavLayoutType.fromStorage(
            navigationRaw['bottomNavLayout']?.toString(),
          );
      if (resolvedBottomLayout == BottomNavLayoutType.floatingCenterAction &&
          !BottomNavLayoutRules.isFloatingCenterValidForBottomCount(
            resolvedBottomPageIds.length,
          )) {
        resolvedBottomLayout = BottomNavLayoutType.centerIconEmphasis;
        resolvedCenterPageId = null;
      }
      final bool resolvedShowLabels =
          navigationRaw['bottomNavShowLabels'] is bool
              ? navigationRaw['bottomNavShowLabels'] as bool
              : true;
      final DrawerNavLayoutType resolvedDrawerLayout =
          DrawerNavLayoutType.fromStorage(
            navigationRaw['drawerNavLayout']?.toString(),
          );
      await _saveNavigationConfig(
        NavigationConfigEntity(
          bottomPageIds: resolvedBottomPageIds,
          drawerPageIds: resolvedDrawerPageIds,
          activePageId: resolvedActivePageId,
          mainPageId: resolvedMainPageId,
          bottomNavLayout: resolvedBottomLayout,
          bottomNavCenterPageId: resolvedCenterPageId,
          bottomNavShowLabels: resolvedShowLabels,
          drawerNavLayout: resolvedDrawerLayout,
        ),
      );

      final Map<String, dynamic> workspaces =
          await _captureStoredWorkspacesWithActiveSnapshot();
      workspaces[accountName.trim()] = _captureWorkspaceSnapshot(
        accountName: accountName.trim(),
      );
      await _markSetupCompleted(
        accountName: accountName,
        accountWorkspaces: workspaces,
      );
      await loadPages();
    } catch (e) {
      Get.snackbar(
        'Template',
        'Failed to apply Simple POS template: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
      print('Failed to apply Simple POS template: $e');
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

  Future<void> switchAccount(String accountName) async {
    final String targetAccount = accountName.trim();
    if (targetAccount.isEmpty || targetAccount == activeAccountName.value) {
      return;
    }
    if (!Hive.isBoxOpen(HiveBoxes.settingsBox)) {
      return;
    }
    final Box<AppSettingsHiveModel> box = Hive.box<AppSettingsHiveModel>(
      HiveBoxes.settingsBox,
    );
    final AppSettingsHiveModel? old = box.get(_settingsKey);
    final String currentAccountName = old?.activeAccountName.trim() ?? '';
    final Map<String, dynamic> workspaces = _asStringDynamicMap(
      old?.accountWorkspaces,
    );
    if (currentAccountName.isNotEmpty) {
      workspaces[currentAccountName] = _captureWorkspaceSnapshot(
        accountName: currentAccountName,
      );
    }

    await _initializeEmptyWorkspace();
    final Map<String, dynamic>? targetWorkspace = _asNullableMap(
      workspaces[targetAccount],
    );
    if (targetWorkspace != null) {
      await _restoreWorkspaceSnapshot(targetWorkspace);
    }
    workspaces[targetAccount] = _captureWorkspaceSnapshot(
      accountName: targetAccount,
    );

    await box.put(
      _settingsKey,
      AppSettingsHiveModel(
        resourcesDownloaded: old?.resourcesDownloaded ?? false,
        themeMode: old?.themeMode ?? 'system',
        firstInstallCompleted: old?.firstInstallCompleted ?? false,
        themePresetName: old?.themePresetName ?? 'Ocean Blue',
        accountNames: old?.accountNames ?? accountNames,
        activeAccountName: targetAccount,
        accountWorkspaces: workspaces,
      ),
    );
    forceSetupMode.value = false;
    activeAccountName.value = targetAccount;
    await loadPages();
  }

  Future<void> openAccountSwitcher() async {
    await Get.toNamed<void>(
      AppRoutes.settings,
      arguments: <String, dynamic>{'openAccountSelector': true},
    );
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
      'assets/templates/simple-pos.json';

  Future<void> _initializeEmptyWorkspace() async {
    if (Hive.isBoxOpen(HiveBoxes.pagesBox)) {
      await Hive.box<BuilderPageHiveModel>(HiveBoxes.pagesBox).clear();
    }
    if (Hive.isBoxOpen(HiveBoxes.tablesBox)) {
      await Hive.box<TableSchemaHiveModel>(HiveBoxes.tablesBox).clear();
    }
    if (Hive.isBoxOpen(HiveBoxes.widgetsBox)) {
      await Hive.box<BuilderWidgetHiveModel>(HiveBoxes.widgetsBox).clear();
    }
    if (Hive.isBoxOpen(HiveBoxes.rowsBox)) {
      await Hive.box<TableRowHiveModel>(HiveBoxes.rowsBox).clear();
    }
    if (Hive.isBoxOpen(HiveBoxes.navigationBox)) {
      await Hive.box<NavigationConfigHiveModel>(
        HiveBoxes.navigationBox,
      ).clear();
    }
  }

  Future<Map<String, dynamic>>
  _captureStoredWorkspacesWithActiveSnapshot() async {
    if (!Hive.isBoxOpen(HiveBoxes.settingsBox)) {
      return <String, dynamic>{};
    }
    final Box<AppSettingsHiveModel> box = Hive.box<AppSettingsHiveModel>(
      HiveBoxes.settingsBox,
    );
    final AppSettingsHiveModel? settings = box.get(_settingsKey);
    final Map<String, dynamic> workspaces = _asStringDynamicMap(
      settings?.accountWorkspaces,
    );
    final String currentAccountName = settings?.activeAccountName.trim() ?? '';
    if (currentAccountName.isNotEmpty) {
      workspaces[currentAccountName] = _captureWorkspaceSnapshot(
        accountName: currentAccountName,
      );
    }
    return workspaces;
  }

  Map<String, dynamic> _captureWorkspaceSnapshot({String? accountName}) {
    final List<Map<String, dynamic>> pagesSnapshot = <Map<String, dynamic>>[];
    if (Hive.isBoxOpen(HiveBoxes.pagesBox)) {
      final Box<BuilderPageHiveModel> pagesBox = Hive.box<BuilderPageHiveModel>(
        HiveBoxes.pagesBox,
      );
      pagesSnapshot.addAll(
        pagesBox.values.map((BuilderPageHiveModel page) {
          return <String, dynamic>{
            'id': page.id,
            'name': page.name,
            'icon': page.icon,
            'navigationType': page.navigationType,
            'isDeleted': page.isDeleted,
            'isDrawerParentContainer': page.isDrawerParentContainer,
            'parentPageId': page.parentPageId,
            'nestedDisplayType': page.nestedDisplayType,
            'nestedRootContentTabName': page.nestedRootContentTabName,
            'widgetGridCount': page.widgetGridCount,
            'layoutOrder': _asStringList(page.layoutOrder),
            'widgetOrder': _asStringList(page.widgetOrder),
          };
        }),
      );
    }

    final List<Map<String, dynamic>> tablesSnapshot = <Map<String, dynamic>>[];
    if (Hive.isBoxOpen(HiveBoxes.tablesBox)) {
      final Box<TableSchemaHiveModel> tablesBox =
          Hive.box<TableSchemaHiveModel>(HiveBoxes.tablesBox);
      tablesSnapshot.addAll(
        tablesBox.values.map((TableSchemaHiveModel table) {
          return <String, dynamic>{
            'id': table.id,
            'pageId': table.pageId,
            'name': table.name,
            'description': table.description,
            'mode': table.mode,
            'layoutType': table.layoutType,
            'listDesignLayout': table.listDesignLayout,
            'swipeToDelete': table.swipeToDelete,
            'productDisplayMode': table.productDisplayMode,
            'tableKind': table.tableKind,
            'summaryConfig': _asNullableMap(table.summaryConfig),
            'inventoryDeduction': _asNullableMap(table.inventoryDeduction),
            'affectingTables': _asMapList(table.affectingTables),
            'validationRules': _asMapList(table.validationRules),
            'searchEnabled': table.searchEnabled,
            'dataLoadingMode': table.dataLoadingMode,
            'pageSize': table.pageSize,
            'lazyInitialLoad': table.lazyInitialLoad,
            'columns': _asMapList(table.columns),
          };
        }),
      );
    }

    final List<Map<String, dynamic>> widgetsSnapshot = <Map<String, dynamic>>[];
    if (Hive.isBoxOpen(HiveBoxes.widgetsBox)) {
      final Box<BuilderWidgetHiveModel> widgetsBox =
          Hive.box<BuilderWidgetHiveModel>(HiveBoxes.widgetsBox);
      widgetsSnapshot.addAll(
        widgetsBox.values.map((BuilderWidgetHiveModel widget) {
          return <String, dynamic>{
            'id': widget.id,
            'pageId': widget.pageId,
            'type': widget.type,
            'config': _asStringDynamicMap(widget.config),
          };
        }),
      );
    }

    final List<Map<String, dynamic>> rowsSnapshot = <Map<String, dynamic>>[];
    if (Hive.isBoxOpen(HiveBoxes.rowsBox)) {
      final Box<TableRowHiveModel> rowsBox = Hive.box<TableRowHiveModel>(
        HiveBoxes.rowsBox,
      );
      rowsSnapshot.addAll(
        rowsBox.values.map((TableRowHiveModel row) {
          return <String, dynamic>{
            'id': row.id,
            'tableId': row.tableId,
            'values': _asStringDynamicMap(row.values),
          };
        }),
      );
    }

    Map<String, dynamic> navigationSnapshot = <String, dynamic>{};
    if (Hive.isBoxOpen(HiveBoxes.navigationBox)) {
      final Box<NavigationConfigHiveModel> navBox =
          Hive.box<NavigationConfigHiveModel>(HiveBoxes.navigationBox);
      if (navBox.isNotEmpty) {
        final NavigationConfigHiveModel nav = navBox.values.first;
        navigationSnapshot = <String, dynamic>{
          'bottomPageIds': _asStringList(nav.bottomPageIds),
          'drawerPageIds': _asStringList(nav.drawerPageIds),
          'activePageId': nav.activePageId,
          'mainPageId': nav.mainPageId,
          'bottomNavLayout': nav.bottomNavLayout,
          'bottomNavCenterPageId': nav.bottomNavCenterPageId,
          'bottomNavShowLabels': nav.bottomNavShowLabels,
          'drawerNavLayout': nav.drawerNavLayout,
        };
      }
    }

    return <String, dynamic>{
      'pages': pagesSnapshot,
      'tables': tablesSnapshot,
      'widgets': widgetsSnapshot,
      'rows': rowsSnapshot,
      'navigation': navigationSnapshot,
      'notifications': _notificationsForAccount(accountName),
    };
  }

  List<Map<String, dynamic>> _notificationsForAccount(String? accountName) {
    if (!Hive.isBoxOpen(HiveBoxes.settingsBox)) {
      return const <Map<String, dynamic>>[];
    }
    final Box<AppSettingsHiveModel> box = Hive.box<AppSettingsHiveModel>(
      HiveBoxes.settingsBox,
    );
    final AppSettingsHiveModel? settings = box.get(_settingsKey);
    final String targetAccount = (accountName ?? settings?.activeAccountName ?? '')
        .trim();
    if (targetAccount.isEmpty) {
      return const <Map<String, dynamic>>[];
    }
    final Map<String, dynamic> workspaces = _asStringDynamicMap(
      settings?.accountWorkspaces,
    );
    final Map<String, dynamic> workspace = _asStringDynamicMap(
      workspaces[targetAccount],
    );
    return _asMapList(workspace['notifications'])
        .map((Map<String, dynamic> item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<void> _restoreWorkspaceSnapshot(Map<String, dynamic> snapshot) async {
    final List<Map<String, dynamic>> pagesRaw = _asMapList(snapshot['pages']);
    final List<Map<String, dynamic>> tablesRaw = _asMapList(snapshot['tables']);
    final List<Map<String, dynamic>> widgetsRaw = _asMapList(
      snapshot['widgets'],
    );
    final List<Map<String, dynamic>> rowsRaw = _asMapList(snapshot['rows']);
    final Map<String, dynamic> navigationRaw = _asStringDynamicMap(
      snapshot['navigation'],
    );

    if (Hive.isBoxOpen(HiveBoxes.pagesBox)) {
      final Box<BuilderPageHiveModel> box = Hive.box<BuilderPageHiveModel>(
        HiveBoxes.pagesBox,
      );
      await box.clear();
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
        await box.put(model.id, model);
      }
    }

    if (Hive.isBoxOpen(HiveBoxes.tablesBox)) {
      final Box<TableSchemaHiveModel> box = Hive.box<TableSchemaHiveModel>(
        HiveBoxes.tablesBox,
      );
      await box.clear();
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
        await box.put(model.id, model);
      }
    }

    if (Hive.isBoxOpen(HiveBoxes.widgetsBox)) {
      final Box<BuilderWidgetHiveModel> box = Hive.box<BuilderWidgetHiveModel>(
        HiveBoxes.widgetsBox,
      );
      await box.clear();
      for (final Map<String, dynamic> widget in widgetsRaw) {
        final BuilderWidgetHiveModel model = BuilderWidgetHiveModel(
          id: (widget['id'] ?? '').toString(),
          pageId: (widget['pageId'] ?? '').toString(),
          type: (widget['type'] ?? 'card').toString(),
          config: _asStringDynamicMap(widget['config']),
        );
        await box.put(model.id, model);
      }
    }

    if (Hive.isBoxOpen(HiveBoxes.rowsBox)) {
      final Box<TableRowHiveModel> box = Hive.box<TableRowHiveModel>(
        HiveBoxes.rowsBox,
      );
      await box.clear();
      for (final Map<String, dynamic> row in rowsRaw) {
        final TableRowHiveModel model = TableRowHiveModel(
          id: (row['id'] ?? '').toString(),
          tableId: (row['tableId'] ?? '').toString(),
          values: _asStringDynamicMap(row['values']),
        );
        await box.put(model.id, model);
      }
    }

    if (Hive.isBoxOpen(HiveBoxes.navigationBox)) {
      final Box<NavigationConfigHiveModel> box =
          Hive.box<NavigationConfigHiveModel>(HiveBoxes.navigationBox);
      await box.clear();
      final NavigationConfigHiveModel model = NavigationConfigHiveModel(
        bottomPageIds: _asStringList(navigationRaw['bottomPageIds']),
        drawerPageIds: _asStringList(navigationRaw['drawerPageIds']),
        activePageId: navigationRaw['activePageId']?.toString(),
        mainPageId: navigationRaw['mainPageId']?.toString(),
        bottomNavLayout:
            (navigationRaw['bottomNavLayout'] ?? 'standard').toString(),
        bottomNavCenterPageId:
            navigationRaw['bottomNavCenterPageId']?.toString(),
        bottomNavShowLabels:
            navigationRaw['bottomNavShowLabels'] is bool
                ? navigationRaw['bottomNavShowLabels'] as bool
                : true,
        drawerNavLayout:
            (navigationRaw['drawerNavLayout'] ?? 'softCard').toString(),
      );
      await box.put('navigation_config', model);
    }
  }

  List<String> _sanitizeAccountNames(List<String>? raw) {
    if (raw == null || raw.isEmpty) {
      return <String>[];
    }
    final List<String> out = <String>[];
    final Set<String> seen = <String>{};
    for (final String item in raw) {
      final String name = item.trim();
      if (name.isEmpty) {
        continue;
      }
      final String normalized = name.toLowerCase();
      if (seen.add(normalized)) {
        out.add(name);
      }
    }
    return out;
  }

  List<String> _mergeAccountNames(List<String> existing, String accountName) {
    final List<String> out = _sanitizeAccountNames(existing);
    final String candidate = accountName.trim();
    if (candidate.isEmpty) {
      return out;
    }
    final String normalized = candidate.toLowerCase();
    final bool exists = out.any(
      (String stored) => stored.toLowerCase() == normalized,
    );
    if (!exists) {
      out.add(candidate);
    }
    return out;
  }
}
