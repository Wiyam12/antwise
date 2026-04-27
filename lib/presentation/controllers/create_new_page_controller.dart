import 'package:antwise/core/app_snackbar.dart';
import 'package:antwise/core/icons/app_icon_registry.dart';
import 'package:antwise/domain/entities/bottom_nav_layout_type.dart';
import 'package:antwise/domain/entities/builder_page_entity.dart';
import 'package:antwise/domain/entities/builder_widget_entity.dart';
import 'package:antwise/domain/entities/drawer_nav_layout_type.dart';
import 'package:antwise/domain/entities/navigation_config_entity.dart';
import 'package:antwise/domain/usecases/get_builder_pages_usecase.dart';
import 'package:antwise/domain/usecases/get_builder_widgets_by_page_usecase.dart';
import 'package:antwise/domain/usecases/get_navigation_config_usecase.dart';
import 'package:antwise/domain/usecases/get_table_schema_by_page_usecase.dart';
import 'package:antwise/domain/usecases/replace_builder_pages_usecase.dart';
import 'package:antwise/domain/usecases/save_builder_page_usecase.dart';
import 'package:antwise/domain/usecases/save_navigation_config_usecase.dart';
import 'package:antwise/presentation/models/page_creation_placement.dart';
import 'package:antwise/presentation/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

class CreateNewPageController extends GetxController {
  CreateNewPageController(
    this._savePage,
    this._getPages,
    this._replacePages,
    this._getWidgetsByPage,
    this._getTableSchemaByPage,
  );

  final SaveBuilderPageUseCase _savePage;
  final GetBuilderPagesUseCase _getPages;
  final ReplaceBuilderPagesUseCase _replacePages;
  final GetBuilderWidgetsByPageUseCase _getWidgetsByPage;
  final GetTableSchemaByPageUseCase _getTableSchemaByPage;
  final GetNavigationConfigUseCase _getNavigationConfig = Get.find();
  final SaveNavigationConfigUseCase _saveNavigationConfig = Get.find();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController secondBottomPageNameController =
      TextEditingController();
  final TextEditingController newParentPageNameController =
      TextEditingController();
  final TextEditingController currentContentTabNameController =
      TextEditingController();
  final RxBool showInBottomNav = false.obs;
  final RxBool showInDrawer = false.obs;
  final RxBool isSaving = false.obs;
  final RxBool requiresSecondBottomPage = false.obs;
  final RxnString selectedParentPageId = RxnString();
  final RxBool createParentInline = false.obs;
  final RxList<BuilderPageEntity> drawerParentCandidates =
      <BuilderPageEntity>[].obs;
  final Rx<PageCreationPlacement> pagePlacement =
      PageCreationPlacement.standalone.obs;
  final RxnString selectedNestedParentPageId = RxnString();
  final Rx<NestedPageDisplayType> selectedNestedDisplayType =
      NestedPageDisplayType.tab.obs;
  final RxList<BuilderPageEntity> allPages = <BuilderPageEntity>[].obs;
  final RxnBool nestedParentPageHasBuilderContent = RxnBool();

  /// True only for the first conversion of a page with content into a nested
  /// host (not when adding another tab to an already converted parent).
  final RxBool showInitialContentTabNameField = false.obs;

  /// Material icon key for the new page (drawer / bottom nav).
  final RxString pageIconKey = AppIconRegistry.defaultKey.obs;

  final Uuid _uuid = Uuid();

  @override
  void onClose() {
    nameController.dispose();
    secondBottomPageNameController.dispose();
    newParentPageNameController.dispose();
    currentContentTabNameController.dispose();
    super.onClose();
  }

  @override
  void onInit() {
    super.onInit();
    setPlacementBottomNav();
    _loadBottomNavRequirement();
  }

  void setPagePlacement(PageCreationPlacement value) {
    if (pagePlacement.value == value) {
      return;
    }
    pagePlacement.value = value;
    if (value == PageCreationPlacement.nestedInPage) {
      selectedParentPageId.value = null;
      createParentInline.value = false;
      newParentPageNameController.clear();
      showInBottomNav.value = false;
      showInDrawer.value = true;
    } else {
      selectedNestedParentPageId.value = null;
      nestedParentPageHasBuilderContent.value = null;
      showInitialContentTabNameField.value = false;
      currentContentTabNameController.clear();
      if (!showInBottomNav.value && !showInDrawer.value) {
        setPlacementBottomNav();
      }
    }
  }

  Future<void> _loadBottomNavRequirement() async {
    final List<BuilderPageEntity> existing = await _getPages();
    allPages.assignAll(existing);
    final int bottomCount =
        existing
            .where((BuilderPageEntity p) => p.showInBottomNav && !p.isDeleted)
            .length;
    requiresSecondBottomPage.value = bottomCount == 0;
    drawerParentCandidates.assignAll(
      existing
          .where(
            (BuilderPageEntity p) =>
                !p.isDeleted && p.showInDrawer && p.isDrawerParentContainer,
          )
          .toList(growable: false),
    );
  }

  Future<void> onNestedParentPageChanged(String? pageId) async {
    currentContentTabNameController.clear();
    selectedNestedParentPageId.value = pageId;
    nestedParentPageHasBuilderContent.value = null;
    showInitialContentTabNameField.value = false;
    if (pageId == null) {
      return;
    }
    await _recomputeParentHasBuilderContent();
  }

  static bool isFirstNestedContentTabSetup({
    required BuilderPageEntity parent,
    required List<BuilderPageEntity> allPages,
  }) {
    if ((parent.nestedRootContentTabName ?? '').trim().isNotEmpty) {
      return false;
    }
    return !allPages.any(
      (BuilderPageEntity p) => p.parentPageId == parent.id && !p.isDeleted,
    );
  }

  Future<void> _recomputeParentHasBuilderContent() async {
    final String? id = selectedNestedParentPageId.value;
    if (id == null) {
      nestedParentPageHasBuilderContent.value = null;
      _syncShowInitialContentTabNameField();
      return;
    }
    final List<Object?> result = await Future.wait<Object?>(<Future<Object?>>[
      _getWidgetsByPage(id),
      _getTableSchemaByPage(id),
    ]);
    final List<BuilderWidgetEntity> widgets =
        result[0]! as List<BuilderWidgetEntity>;
    final bool hasTable = result[1] != null;
    nestedParentPageHasBuilderContent.value = widgets.isNotEmpty || hasTable;
    _syncShowInitialContentTabNameField();
  }

  void _syncShowInitialContentTabNameField() {
    bool show = false;
    if (pagePlacement.value == PageCreationPlacement.nestedInPage) {
      final String? id = selectedNestedParentPageId.value;
      if (id != null && nestedParentPageHasBuilderContent.value == true) {
        BuilderPageEntity? parent;
        for (final BuilderPageEntity p in allPages) {
          if (p.id == id) {
            parent = p;
            break;
          }
        }
        if (parent != null) {
          show = isFirstNestedContentTabSetup(
            parent: parent,
            allPages: allPages,
          );
        }
      }
    }
    showInitialContentTabNameField.value = show;
    if (!show) {
      currentContentTabNameController.clear();
    }
  }

  void setPlacementBottomNav() {
    if (pagePlacement.value == PageCreationPlacement.nestedInPage) {
      return;
    }
    showInBottomNav.value = true;
    showInDrawer.value = false;
    selectedParentPageId.value = null;
    createParentInline.value = false;
    newParentPageNameController.clear();
  }

  void setPlacementDrawer() {
    if (pagePlacement.value == PageCreationPlacement.nestedInPage) {
      return;
    }
    showInBottomNav.value = false;
    showInDrawer.value = true;
    secondBottomPageNameController.clear();
  }

  void selectParentPage(String? pageId) {
    selectedParentPageId.value = pageId;
    if (pageId != null) {
      createParentInline.value = false;
      newParentPageNameController.clear();
    }
  }

  void toggleCreateParentInline(bool value) {
    createParentInline.value = value;
    if (value) {
      selectedParentPageId.value = null;
    } else {
      newParentPageNameController.clear();
    }
  }

  bool get hasUnsavedChanges =>
      nameController.text.trim().isNotEmpty ||
      secondBottomPageNameController.text.trim().isNotEmpty ||
      currentContentTabNameController.text.trim().isNotEmpty ||
      pagePlacement.value != PageCreationPlacement.standalone ||
      !showInBottomNav.value ||
      showInDrawer.value ||
      pageIconKey.value != AppIconRegistry.defaultKey;

  Future<bool> validate() async {
    final String name = nameController.text.trim();
    if (name.isEmpty) {
      showAppSnackbar('Page name', 'Enter a page name');
      return false;
    }
    if (pagePlacement.value == PageCreationPlacement.nestedInPage) {
      if (selectedNestedParentPageId.value == null) {
        showAppSnackbar('Parent page', 'Select a parent page');
        return false;
      }
      if (nestedParentPageHasBuilderContent.value == null) {
        await _recomputeParentHasBuilderContent();
      }
      if (showInitialContentTabNameField.value) {
        if (currentContentTabNameController.text.trim().isEmpty) {
          showAppSnackbar(
            'Current content tab name',
            'Enter a name for the tab that shows the parent page’s existing content',
          );
          return false;
        }
      }
      return true;
    }
    if (!showInBottomNav.value && !showInDrawer.value) {
      showAppSnackbar('Navigation', 'Select at least one placement');
      return false;
    }
    if (showInBottomNav.value && requiresSecondBottomPage.value) {
      final String secondName = secondBottomPageNameController.text.trim();
      if (secondName.isEmpty) {
        showAppSnackbar(
          'Bottom navigation',
          'Create a second bottom-nav page before saving.',
        );
        return false;
      }
    }
    if (showInDrawer.value &&
        createParentInline.value &&
        newParentPageNameController.text.trim().isEmpty) {
      showAppSnackbar('Parent page', 'Enter a parent page name');
      return false;
    }
    return true;
  }

  Future<void> save() async {
    if (!await validate()) {
      return;
    }
    isSaving.value = true;
    try {
      if (pagePlacement.value == PageCreationPlacement.nestedInPage) {
        final String? parentId = selectedNestedParentPageId.value;
        if (parentId == null) {
          return;
        }
        final List<BuilderPageEntity> list = List<BuilderPageEntity>.from(
          await _getPages(),
        );
        final int parentIndex = list.indexWhere(
          (BuilderPageEntity p) => p.id == parentId,
        );
        if (parentIndex < 0) {
          showAppSnackbar('Parent page', 'Selected parent no longer exists');
          return;
        }
        final BuilderPageEntity oldParent = list[parentIndex];
        final String rootTab = currentContentTabNameController.text.trim();
        final bool hasExistingChild = list.any(
          (BuilderPageEntity p) => p.parentPageId == parentId && !p.isDeleted,
        );
        final bool hasRootName =
            (oldParent.nestedRootContentTabName ?? '').trim().isNotEmpty;
        final bool isFirstNestedSetup = !hasRootName && !hasExistingChild;
        final String defaultRootTabName =
            rootTab.isNotEmpty ? rootTab : oldParent.name;
        final BuilderPageEntity updatedParent =
            isFirstNestedSetup
                ? oldParent.copyWith(
                  nestedRootContentTabName: defaultRootTabName,
                )
                : oldParent;
        list[parentIndex] = updatedParent;
        final BuilderPageEntity newChild = BuilderPageEntity(
          id: _uuid.v4(),
          name: nameController.text.trim(),
          showInBottomNav: false,
          showInDrawer: true,
          isDeleted: false,
          parentPageId: parentId,
          nestedDisplayType: selectedNestedDisplayType.value,
          iconName: pageIconKey.value,
        );
        list.add(newChild);
        await _replacePages(list);
        Get.offAllNamed<void>(AppRoutes.home);
        return;
      }
      String? parentPageId = selectedParentPageId.value;
      if (showInDrawer.value && createParentInline.value) {
        final String parentName = newParentPageNameController.text.trim();
        final BuilderPageEntity parent = BuilderPageEntity(
          id: _uuid.v4(),
          name: parentName,
          showInBottomNav: false,
          showInDrawer: true,
          isDeleted: false,
          isDrawerParentContainer: true,
        );
        await _savePage(parent);
        parentPageId = parent.id;
        drawerParentCandidates.insert(0, parent);
        allPages.insert(0, parent);
        selectedParentPageId.value = parent.id;
        createParentInline.value = false;
      }
      final BuilderPageEntity page = BuilderPageEntity(
        id: _uuid.v4(),
        name: nameController.text.trim(),
        showInBottomNav: showInBottomNav.value,
        showInDrawer: showInDrawer.value,
        isDeleted: false,
        parentPageId: showInDrawer.value ? parentPageId : null,
        iconName: pageIconKey.value,
      );
      await _savePage(page);
      BuilderPageEntity? secondPage;
      if (page.showInBottomNav && requiresSecondBottomPage.value) {
        secondPage = BuilderPageEntity(
          id: _uuid.v4(),
          name: secondBottomPageNameController.text.trim(),
          showInBottomNav: true,
          showInDrawer: false,
          isDeleted: false,
        );
        await _savePage(secondPage);
      }
      final NavigationConfigEntity? current = await _getNavigationConfig();
      if (page.showInDrawer) {
        final List<String> nextDrawer = <String>[
          ...(current?.drawerPageIds ?? const <String>[]),
        ];
        if (parentPageId != null && !nextDrawer.contains(parentPageId)) {
          nextDrawer.add(parentPageId);
        }
        nextDrawer.remove(page.id);
        nextDrawer.add(page.id);
        await _saveNavigationConfig(
          NavigationConfigEntity(
            bottomPageIds: current?.bottomPageIds ?? const <String>[],
            drawerPageIds: nextDrawer,
            activePageId: current?.activePageId,
            mainPageId: current?.mainPageId,
            bottomNavLayout:
                current?.bottomNavLayout ?? BottomNavLayoutType.standard,
            bottomNavCenterPageId: current?.bottomNavCenterPageId,
            bottomNavShowLabels: current?.bottomNavShowLabels ?? true,
            drawerNavLayout:
                current?.drawerNavLayout ?? DrawerNavLayoutType.softCard,
          ),
        );
      }
      if (page.showInBottomNav) {
        final List<String> nextBottom = <String>[
          ...(current?.bottomPageIds ?? const <String>[]),
        ];
        nextBottom.remove(page.id);
        nextBottom.add(page.id);
        if (secondPage != null) {
          nextBottom.remove(secondPage.id);
          nextBottom.add(secondPage.id);
        }
        await _saveNavigationConfig(
          NavigationConfigEntity(
            bottomPageIds: nextBottom,
            drawerPageIds: current?.drawerPageIds ?? const <String>[],
            activePageId: current?.activePageId ?? page.id,
            mainPageId: current?.mainPageId ?? page.id,
            bottomNavLayout:
                current?.bottomNavLayout ?? BottomNavLayoutType.standard,
            bottomNavCenterPageId: current?.bottomNavCenterPageId,
            bottomNavShowLabels: current?.bottomNavShowLabels ?? true,
            drawerNavLayout:
                current?.drawerNavLayout ?? DrawerNavLayoutType.softCard,
          ),
        );
      }
      Get.offAllNamed<void>(AppRoutes.home);
    } catch (e) {
      showAppSnackbar(
        'Save failed',
        '$e',
        duration: const Duration(seconds: 5),
      );
    } finally {
      isSaving.value = false;
    }
  }
}
