import 'package:antwise/core/app_snackbar.dart';
import 'package:antwise/domain/entities/builder_page_entity.dart';
import 'package:antwise/domain/entities/builder_widget_entity.dart';
import 'package:antwise/domain/usecases/delete_builder_widget_usecase.dart';
import 'package:antwise/domain/usecases/get_all_builder_widgets_usecase.dart';
import 'package:antwise/domain/usecases/get_builder_pages_usecase.dart';
import 'package:antwise/presentation/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingsWidgetsController extends GetxController {
  SettingsWidgetsController(
    this._getPages,
    this._getWidgets,
    this._deleteWidget,
  );

  final GetBuilderPagesUseCase _getPages;
  final GetAllBuilderWidgetsUseCase _getWidgets;
  final DeleteBuilderWidgetUseCase _deleteWidget;

  final RxBool isLoading = true.obs;
  final RxList<BuilderPageEntity> pages = <BuilderPageEntity>[].obs;
  final RxList<BuilderWidgetEntity> widgets = <BuilderWidgetEntity>[].obs;
  final RxSet<String> expandedPages = <String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      final List<BuilderPageEntity> pageList = await _getPages();
      final List<BuilderWidgetEntity> widgetList = await _getWidgets();
      pages.assignAll(pageList.where((BuilderPageEntity p) => !p.isDeleted));
      widgets.assignAll(widgetList);
    } finally {
      isLoading.value = false;
    }
  }

  void toggleExpanded(String pageId) {
    if (expandedPages.contains(pageId)) {
      expandedPages.remove(pageId);
    } else {
      expandedPages.add(pageId);
    }
  }

  List<BuilderWidgetEntity> widgetsForPage(String pageId) {
    final List<BuilderWidgetEntity> out = widgets
        .where(
          (BuilderWidgetEntity w) =>
              w.pageId == pageId && _isManageableWidgetType(w.type),
        )
        .toList(growable: false);
    out.sort(
      (BuilderWidgetEntity a, BuilderWidgetEntity b) =>
          _widgetDisplayOrder(a).compareTo(_widgetDisplayOrder(b)),
    );
    return out;
  }

  String widgetDisplayName(BuilderWidgetEntity widget) {
    final String? customTitle = widget.config['title']?.toString().trim();
    if (customTitle != null && customTitle.isNotEmpty) {
      return customTitle;
    }
    final String type = widget.type.toLowerCase();
    if (type == 'card') {
      return 'Card Widget';
    }
    if (type == 'chart') {
      return 'Chart Widget';
    }
    return 'Widget';
  }

  static bool _isManageableWidgetType(String type) {
    final String normalized = type.trim().toLowerCase();
    return normalized == 'card' || normalized == 'chart';
  }

  void openEditWidget(String widgetId) {
    Get.toNamed<dynamic>(AppRoutes.settingsEditWidget, arguments: widgetId)?.then((
      dynamic result,
    ) {
      if (result == true) {
        showAppSnackbar('Widget', 'Updated');
      }
      load();
    });
  }

  Future<void> deleteWidget(BuilderWidgetEntity widget) async {
    final bool? confirm = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Delete this widget?'),
        content: Text('This will remove "${widgetDisplayName(widget)}".'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) {
      return;
    }
    await _deleteWidget(widget.id);
    showAppSnackbar('Widget', 'Deleted');
    await load();
  }

  static int _widgetDisplayOrder(BuilderWidgetEntity w) {
    final dynamic order = w.config['widgetOrder'] ?? w.config['tableOrder'];
    if (order is num) {
      return order.toInt();
    }
    return 1 << 20;
  }
}
