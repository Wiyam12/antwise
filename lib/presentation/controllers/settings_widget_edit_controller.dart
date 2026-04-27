import 'package:antwise/core/app_snackbar.dart';
import 'package:antwise/domain/entities/builder_page_entity.dart';
import 'package:antwise/domain/entities/builder_widget_entity.dart';
import 'package:antwise/domain/entities/card_widget_layout.dart';
import 'package:antwise/domain/entities/table_column_entity.dart';
import 'package:antwise/domain/entities/table_column_type.dart';
import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/domain/usecases/get_all_builder_widgets_usecase.dart';
import 'package:antwise/domain/usecases/get_all_table_schemas_usecase.dart';
import 'package:antwise/domain/usecases/get_builder_pages_usecase.dart';
import 'package:antwise/domain/usecases/save_builder_widget_usecase.dart';
import 'package:antwise/domain/validation/table_formula_validator.dart';
import 'package:antwise/presentation/controllers/home_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum SettingsChartWidgetType { bar, line, pie }

class SettingsWidgetEditController extends GetxController {
  SettingsWidgetEditController(
    this._getWidgets,
    this._getSchemas,
    this._getPages,
    this._saveWidget,
  );

  static const String syntheticFormulaColumnId = '_card_metric';

  final GetAllBuilderWidgetsUseCase _getWidgets;
  final GetAllTableSchemasUseCase _getSchemas;
  final GetBuilderPagesUseCase _getPages;
  final SaveBuilderWidgetUseCase _saveWidget;

  final RxBool isLoading = true.obs;
  final RxBool isSaving = false.obs;
  final Rxn<BuilderWidgetEntity> widget = Rxn<BuilderWidgetEntity>();
  final RxList<TableSchemaEntity> allSchemas = <TableSchemaEntity>[].obs;
  final RxList<BuilderPageEntity> pages = <BuilderPageEntity>[].obs;

  final TextEditingController titleController = TextEditingController();
  final TextEditingController formulaController = TextEditingController();

  final Rxn<CardWidgetLayout> selectedLayout = Rxn<CardWidgetLayout>();
  final Rxn<SettingsChartWidgetType> selectedChartType =
      Rxn<SettingsChartWidgetType>();
  final RxnString selectedTableId = RxnString();
  final RxnString selectedXAxisColumnId = RxnString();
  final RxnString selectedYAxisColumnId = RxnString();
  final RxnString selectedColumnId = RxnString();

  final RxString layoutError = ''.obs;
  final RxString chartTypeError = ''.obs;
  final RxString tableError = ''.obs;
  final RxString xAxisError = ''.obs;
  final RxString yAxisError = ''.obs;
  final RxString columnError = ''.obs;
  final RxString formulaError = ''.obs;

  String? _widgetId;

  @override
  void onInit() {
    super.onInit();
    _widgetId = Get.arguments?.toString();
    load();
  }

  @override
  void onClose() {
    titleController.dispose();
    formulaController.dispose();
    super.onClose();
  }

  bool get isChartWidget => widget.value?.type == 'chart';
  bool get isCardWidget => widget.value?.type == 'card';

  Future<void> load() async {
    final String? widgetId = _widgetId;
    if (widgetId == null || widgetId.isEmpty) {
      isLoading.value = false;
      return;
    }
    isLoading.value = true;
    try {
      final List<BuilderWidgetEntity> allWidgets = await _getWidgets();
      final List<TableSchemaEntity> schemas = await _getSchemas();
      final List<BuilderPageEntity> pageList = await _getPages();
      BuilderWidgetEntity? target;
      for (final BuilderWidgetEntity item in allWidgets) {
        if (item.id == widgetId) {
          target = item;
          break;
        }
      }
      widget.value = target;
      allSchemas.assignAll(schemas);
      pages.assignAll(pageList.where((BuilderPageEntity p) => !p.isDeleted));
      if (target == null) {
        return;
      }
      titleController.text = target.config['title']?.toString() ?? '';
      formulaController.text = target.config['formula']?.toString() ?? '';
      selectedLayout.value = CardWidgetLayout.fromStorage(
        target.config['cardLayout']?.toString(),
      );
      selectedChartType.value = switch (target.config['chartType']?.toString()) {
        'line' => SettingsChartWidgetType.line,
        'pie' => SettingsChartWidgetType.pie,
        _ => SettingsChartWidgetType.bar,
      };
      selectedTableId.value = target.config['tableId']?.toString();
      selectedColumnId.value = target.config['columnId']?.toString();
      selectedXAxisColumnId.value = target.config['xColumnId']?.toString();
      selectedYAxisColumnId.value = target.config['yColumnId']?.toString();
    } finally {
      isLoading.value = false;
    }
  }

  TableSchemaEntity? get selectedTable {
    final String? tableId = selectedTableId.value;
    if (tableId == null || tableId.isEmpty) {
      return null;
    }
    for (final TableSchemaEntity schema in allSchemas) {
      if (schema.id == tableId) {
        return schema;
      }
    }
    return null;
  }

  List<TableColumnEntity> get selectedTableColumns {
    return selectedTable?.columns ?? const <TableColumnEntity>[];
  }

  String pageDisplayLabel(String pageId) {
    for (final BuilderPageEntity page in pages) {
      if (page.id == pageId) {
        return page.name;
      }
    }
    return pageId;
  }

  String tableDisplayLabel(TableSchemaEntity schema) {
    return '${schema.name} (${pageDisplayLabel(schema.pageId)})';
  }

  void pickLayout(CardWidgetLayout layout) {
    selectedLayout.value = layout;
    layoutError.value = '';
  }

  void onTableChanged(String? tableId) {
    selectedTableId.value = tableId;
    selectedColumnId.value = null;
    selectedXAxisColumnId.value = null;
    selectedYAxisColumnId.value = null;
    tableError.value = '';
    columnError.value = '';
    xAxisError.value = '';
    yAxisError.value = '';
  }

  void onColumnChanged(String? columnId) {
    selectedColumnId.value = columnId;
    columnError.value = '';
  }

  void onXAxisColumnChanged(String? columnId) {
    selectedXAxisColumnId.value = columnId;
    xAxisError.value = '';
  }

  void onYAxisColumnChanged(String? columnId) {
    selectedYAxisColumnId.value = columnId;
    yAxisError.value = '';
  }

  void pickChartType(SettingsChartWidgetType type) {
    selectedChartType.value = type;
    chartTypeError.value = '';
  }

  bool _validate() {
    layoutError.value = '';
    chartTypeError.value = '';
    tableError.value = '';
    xAxisError.value = '';
    yAxisError.value = '';
    columnError.value = '';
    formulaError.value = '';

    if (isCardWidget) {
      if (selectedLayout.value == null) {
        layoutError.value = 'Select a card layout';
        return false;
      }
    } else if (isChartWidget) {
      if (selectedChartType.value == null) {
        chartTypeError.value = 'Select a chart type';
        return false;
      }
    }
    final TableSchemaEntity? table = selectedTable;
    if (table == null) {
      tableError.value = 'Select a source table';
      return false;
    }

    if (isCardWidget) {
      final String? columnId = selectedColumnId.value;
      if (columnId == null || columnId.isEmpty) {
        columnError.value = 'Select a source column';
        return false;
      }
      bool columnExists = false;
      for (final TableColumnEntity col in table.columns) {
        if (col.id == columnId) {
          columnExists = true;
          break;
        }
      }
      if (!columnExists) {
        columnError.value = 'Column is no longer available';
        return false;
      }
    } else if (isChartWidget) {
      final String? xColId = selectedXAxisColumnId.value;
      final String? yColId = selectedYAxisColumnId.value;
      final String formula = formulaController.text.trim();
      if (xColId == null || xColId.isEmpty) {
        xAxisError.value = 'Select an X-axis column';
        return false;
      }
      if ((yColId == null || yColId.isEmpty) && formula.isEmpty) {
        yAxisError.value = 'Select a Y-axis column or provide a formula';
        return false;
      }
      bool xColExists = false;
      bool yColExists = yColId == null || yColId.isEmpty;
      TableColumnEntity? yColumn;
      for (final TableColumnEntity col in table.columns) {
        if (col.id == xColId) {
          xColExists = true;
        }
        if (col.id == yColId) {
          yColExists = true;
          yColumn = col;
        }
      }
      if (!xColExists) {
        xAxisError.value = 'X-axis column is no longer available';
        return false;
      }
      if (!yColExists) {
        yAxisError.value = 'Y-axis column is no longer available';
        return false;
      }
      if (yColumn != null &&
          yColumn.type != TableColumnType.number &&
          yColumn.type != TableColumnType.formula) {
        yAxisError.value = 'Y-axis column must be numeric';
        return false;
      }
    }

    final String formula = formulaController.text.trim();
    if (formula.isNotEmpty) {
      final String? error = TableFormulaValidator.validate(
        formula: formula,
        currentColumnId: syntheticFormulaColumnId,
        siblingColumns: const <ColumnNameDraft>[],
        existingTables: allSchemas,
      );
      if (error != null) {
        formulaError.value = error;
        return false;
      }
    }
    return true;
  }

  Future<void> save() async {
    final BuilderWidgetEntity? current = widget.value;
    if (current == null) {
      return;
    }
    if (!_validate()) {
      showAppSnackbar('Validation', 'Please fix the highlighted fields.');
      return;
    }

    isSaving.value = true;
    try {
      final Map<String, dynamic> nextConfig = <String, dynamic>{
        ...current.config,
        'tableId': selectedTableId.value!,
      };
      if (isCardWidget) {
        nextConfig['cardLayout'] = selectedLayout.value!.storageValue;
        nextConfig['columnId'] = selectedColumnId.value!;
        nextConfig.remove('chartType');
        nextConfig.remove('xColumnId');
        nextConfig.remove('yColumnId');
      } else if (isChartWidget) {
        nextConfig['chartType'] = selectedChartType.value?.name ?? 'bar';
        nextConfig['xColumnId'] = selectedXAxisColumnId.value!;
        final String? y = selectedYAxisColumnId.value;
        if (y == null || y.isEmpty) {
          nextConfig.remove('yColumnId');
        } else {
          nextConfig['yColumnId'] = y;
        }
        nextConfig.remove('cardLayout');
        nextConfig.remove('columnId');
      }
      final String title = titleController.text.trim();
      if (title.isEmpty) {
        nextConfig.remove('title');
      } else {
        nextConfig['title'] = title;
      }
      final String formula = formulaController.text.trim();
      if (formula.isEmpty) {
        nextConfig.remove('formula');
      } else {
        nextConfig['formula'] = formula;
      }
      await _saveWidget(
        BuilderWidgetEntity(
          id: current.id,
          pageId: current.pageId,
          type: current.type,
          config: nextConfig,
        ),
      );
      if (Get.isRegistered<HomeController>()) {
        Get.find<HomeController>().refreshBuilderPageContent();
      }
      Get.back(result: true);
    } finally {
      isSaving.value = false;
    }
  }
}
