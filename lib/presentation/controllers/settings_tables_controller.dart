import 'package:antwise/core/app_snackbar.dart';
import 'package:antwise/domain/entities/builder_page_entity.dart';
import 'package:antwise/domain/entities/builder_widget_entity.dart';
import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/domain/usecases/delete_builder_widget_usecase.dart';
import 'package:antwise/domain/usecases/delete_rows_by_table_usecase.dart';
import 'package:antwise/domain/usecases/delete_table_schema_usecase.dart';
import 'package:antwise/domain/usecases/get_all_builder_widgets_usecase.dart';
import 'package:antwise/domain/usecases/get_all_table_schemas_usecase.dart';
import 'package:antwise/domain/usecases/get_builder_pages_usecase.dart';
import 'package:antwise/domain/usecases/get_table_rows_usecase.dart';
import 'package:antwise/domain/usecases/replace_builder_widgets_usecase.dart';
import 'package:antwise/presentation/controllers/edit_table_controller.dart';
import 'package:antwise/presentation/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingsTablesController extends GetxController {
  SettingsTablesController(
    this._getPages,
    this._getSchemas,
    this._getWidgets,
    this._getRows,
    this._replaceWidgets,
    this._deleteSchema,
    this._deleteRowsByTable,
    this._deleteWidget,
  );

  final GetBuilderPagesUseCase _getPages;
  final GetAllTableSchemasUseCase _getSchemas;
  final GetAllBuilderWidgetsUseCase _getWidgets;
  final GetTableRowsUseCase _getRows;
  final ReplaceBuilderWidgetsUseCase _replaceWidgets;
  final DeleteTableSchemaUseCase _deleteSchema;
  final DeleteRowsByTableUseCase _deleteRowsByTable;
  final DeleteBuilderWidgetUseCase _deleteWidget;

  final RxBool isLoading = true.obs;
  final RxList<BuilderPageEntity> pages = <BuilderPageEntity>[].obs;
  final RxList<TableSchemaEntity> schemas = <TableSchemaEntity>[].obs;
  final RxList<BuilderWidgetEntity> widgets = <BuilderWidgetEntity>[].obs;
  final RxMap<String, int> rowCountByTable = <String, int>{}.obs;
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
      final List<TableSchemaEntity> tableList = await _getSchemas();
      final List<BuilderWidgetEntity> widgetList = await _getWidgets();
      final Map<String, int> rowCounts = <String, int>{};
      for (final TableSchemaEntity schema in tableList) {
        rowCounts[schema.id] = (await _getRows(schema.id)).length;
      }
      pages.assignAll(pageList.where((BuilderPageEntity p) => !p.isDeleted));
      schemas.assignAll(tableList);
      widgets.assignAll(widgetList);
      rowCountByTable.assignAll(rowCounts);
    } finally {
      isLoading.value = false;
    }
  }

  List<TableSchemaEntity> tablesForPage(String pageId) {
    final List<TableSchemaEntity> pageTables = schemas
        .where((TableSchemaEntity s) => s.pageId == pageId)
        .toList(growable: false);
    final Map<String, int> orderByTableId = <String, int>{};
    int fallbackOrder = 100000;
    for (final BuilderWidgetEntity widget in widgets
        .where((BuilderWidgetEntity w) => w.pageId == pageId && w.type == 'table')
        .toList(growable: false)) {
      final String? tableId = widget.config['tableId']?.toString();
      if (tableId == null) {
        continue;
      }
      final int? explicitOrder = widget.config['tableOrder'] as int?;
      orderByTableId[tableId] = explicitOrder ?? fallbackOrder++;
    }
    pageTables.sort((TableSchemaEntity a, TableSchemaEntity b) {
      final int oa = orderByTableId[a.id] ?? 999999;
      final int ob = orderByTableId[b.id] ?? 999999;
      return oa.compareTo(ob);
    });
    return pageTables;
  }

  void toggleExpanded(String pageId) {
    if (expandedPages.contains(pageId)) {
      expandedPages.remove(pageId);
    } else {
      expandedPages.add(pageId);
    }
  }

  Future<void> reorderTablesInPage(
    String pageId,
    int oldIndex,
    int newIndex,
  ) async {
    final List<TableSchemaEntity> orderedTables = tablesForPage(pageId).toList();
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final TableSchemaEntity moved = orderedTables.removeAt(oldIndex);
    orderedTables.insert(newIndex, moved);

    final List<BuilderWidgetEntity> all = widgets.toList(growable: false);
    final Map<String, int> orderByTableId = <String, int>{
      for (int i = 0; i < orderedTables.length; i++) orderedTables[i].id: i,
    };
    final List<BuilderWidgetEntity> next = all.map((BuilderWidgetEntity widget) {
      if (widget.pageId != pageId || widget.type != 'table') {
        return widget;
      }
      final String? tableId = widget.config['tableId']?.toString();
      if (tableId == null || !orderByTableId.containsKey(tableId)) {
        return widget;
      }
      return BuilderWidgetEntity(
        id: widget.id,
        pageId: widget.pageId,
        type: widget.type,
        config: <String, dynamic>{
          ...widget.config,
          'tableOrder': orderByTableId[tableId],
        },
      );
    }).toList(growable: false);
    await _replaceWidgets(next);
    await load();
  }

  void openEditTable(String tableId) {
    Get.toNamed<void>(AppRoutes.settingsEditTable, arguments: tableId)?.then((_) {
      if (Get.isRegistered<EditTableController>()) {
        Get.delete<EditTableController>(force: true);
      }
      load();
    });
  }

  Future<void> deleteTable(TableSchemaEntity schema) async {
    final List<BuilderWidgetEntity> dependentWidgets = widgets
        .where(
          (BuilderWidgetEntity w) =>
              w.type == 'table' && w.config['tableId']?.toString() == schema.id,
        )
        .toList(growable: false);
    final int rowCount = rowCountByTable[schema.id] ?? 0;
    final List<String> affectedPageNames = dependentWidgets
        .map(
          (BuilderWidgetEntity w) =>
              _pageNameById(w.pageId) ?? w.pageId,
        )
        .toSet()
        .toList(growable: false);

    final bool? confirm = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Delete table?'),
        content: Text(
          'Table: ${schema.name}\n'
          'Rows affected: $rowCount\n'
          'Widgets affected: ${dependentWidgets.length}\n'
          'Pages: ${affectedPageNames.join(', ')}',
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Get.back(result: true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) {
      return;
    }

    await _deleteRowsByTable(schema.id);
    for (final BuilderWidgetEntity widget in dependentWidgets) {
      await _deleteWidget(widget.id);
    }
    await _deleteSchema(schema.id);
    showAppSnackbar('Table', 'Deleted ${schema.name}');
    await load();
  }

  String? _pageNameById(String pageId) {
    for (final BuilderPageEntity page in pages) {
      if (page.id == pageId) {
        return page.name;
      }
    }
    return null;
  }
}
