import 'package:antwise/core/app_snackbar.dart';
import 'package:antwise/domain/entities/builder_page_entity.dart';
import 'package:antwise/domain/usecases/get_builder_pages_usecase.dart';
import 'package:antwise/domain/usecases/save_builder_page_usecase.dart';
import 'package:antwise/presentation/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

class CreateNewPageController extends GetxController {
  CreateNewPageController(this._savePage, this._getPages);

  final SaveBuilderPageUseCase _savePage;
  final GetBuilderPagesUseCase _getPages;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController secondBottomPageNameController =
      TextEditingController();
  final TextEditingController newParentPageNameController =
      TextEditingController();
  final RxBool showInBottomNav = false.obs;
  final RxBool showInDrawer = false.obs;
  final RxBool isSaving = false.obs;
  final RxBool requiresSecondBottomPage = false.obs;
  final RxnString selectedParentPageId = RxnString();
  final RxBool createParentInline = false.obs;
  final RxList<BuilderPageEntity> drawerParentCandidates =
      <BuilderPageEntity>[].obs;

  final Uuid _uuid = Uuid();

  @override
  void onClose() {
    nameController.dispose();
    secondBottomPageNameController.dispose();
    newParentPageNameController.dispose();
    super.onClose();
  }

  @override
  void onInit() {
    super.onInit();
    setPlacementBottomNav();
    _loadBottomNavRequirement();
  }

  Future<void> _loadBottomNavRequirement() async {
    final List<BuilderPageEntity> existing = await _getPages();
    final int bottomCount =
        existing.where((BuilderPageEntity p) => p.showInBottomNav).length;
    requiresSecondBottomPage.value = bottomCount == 0;
    final Set<String> parentIdsWithChildren = existing
        .map((BuilderPageEntity p) => p.parentPageId)
        .whereType<String>()
        .toSet();
    drawerParentCandidates.assignAll(
      existing
          .where(
            (BuilderPageEntity p) =>
                p.showInDrawer &&
                !p.isDeleted &&
                parentIdsWithChildren.contains(p.id),
          )
          .toList(growable: false),
    );
  }

  void setPlacementBottomNav() {
    showInBottomNav.value = true;
    showInDrawer.value = false;
    selectedParentPageId.value = null;
    createParentInline.value = false;
    newParentPageNameController.clear();
  }

  void setPlacementDrawer() {
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
      !showInBottomNav.value ||
      showInDrawer.value;

  Future<bool> validate() async {
    final String name = nameController.text.trim();
    if (name.isEmpty) {
      showAppSnackbar('Page name', 'Enter a page name');
      return false;
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
      String? parentPageId = selectedParentPageId.value;
      if (showInDrawer.value && createParentInline.value) {
        final String parentName = newParentPageNameController.text.trim();
        final BuilderPageEntity parent = BuilderPageEntity(
          id: _uuid.v4(),
          name: parentName,
          showInBottomNav: false,
          showInDrawer: true,
          isDeleted: false,
        );
        await _savePage(parent);
        parentPageId = parent.id;
        drawerParentCandidates.insert(0, parent);
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
      );
      await _savePage(page);
      if (page.showInBottomNav && requiresSecondBottomPage.value) {
        final BuilderPageEntity secondPage = BuilderPageEntity(
          id: _uuid.v4(),
          name: secondBottomPageNameController.text.trim(),
          showInBottomNav: true,
          showInDrawer: false,
          isDeleted: false,
        );
        await _savePage(secondPage);
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
