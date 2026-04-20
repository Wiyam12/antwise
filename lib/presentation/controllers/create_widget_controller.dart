import 'package:antwise/core/app_snackbar.dart';
import 'package:antwise/domain/entities/builder_widget_entity.dart';
import 'package:antwise/domain/entities/card_widget_layout.dart';
import 'package:antwise/domain/entities/table_column_entity.dart';
import 'package:antwise/domain/entities/table_column_type.dart';
import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/domain/usecases/get_all_table_schemas_usecase.dart';
import 'package:antwise/domain/usecases/get_builder_pages_usecase.dart';
import 'package:antwise/domain/usecases/get_builder_widgets_by_page_usecase.dart';
import 'package:antwise/domain/usecases/save_builder_widget_usecase.dart';
import 'package:antwise/domain/validation/table_formula_validator.dart';
import 'package:antwise/domain/widgets/compute_card_widget_value.dart';
import 'package:antwise/presentation/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

enum BuilderWidgetType { card, chart }
enum ChartWidgetType { bar, line, pie }

class CreateWidgetController extends GetxController {
  CreateWidgetController(
    this._getPages,
    this._saveWidget,
    this._getAllSchemas,
    this._getWidgetsByPage,
  );

  final GetBuilderPagesUseCase _getPages;
  final SaveBuilderWidgetUseCase _saveWidget;
  final GetAllTableSchemasUseCase _getAllSchemas;
  final GetBuilderWidgetsByPageUseCase _getWidgetsByPage;

  static const String syntheticFormulaColumnId = '_card_metric';

  final RxInt currentStep = 0.obs;
  final RxBool isSaving = false.obs;
  final RxBool isLoadingPages = true.obs;
  final RxList<WidgetPageOption> pageOptions = <WidgetPageOption>[].obs;
  final RxList<TableSchemaEntity> allTableSchemas =
      <TableSchemaEntity>[].obs;

  final TextEditingController titleController = TextEditingController();
  final TextEditingController formulaController = TextEditingController();

  final Rxn<BuilderWidgetType> selectedWidgetType = Rxn<BuilderWidgetType>();
  final RxnString selectedPageId = RxnString();
  final RxString tableSearchQuery = ''.obs;
  final Rxn<CardWidgetLayout> selectedLayout = Rxn<CardWidgetLayout>();
  final Rxn<ChartWidgetType> selectedChartType = Rxn<ChartWidgetType>();
  final RxnString selectedTableId = RxnString();
  final RxnString selectedXAxisColumnId = RxnString();
  final RxnString selectedYAxisColumnId = RxnString();
  final RxnString selectedColumnId = RxnString();

  final RxString widgetTypeError = ''.obs;
  final RxString layoutError = ''.obs;
  final RxString chartTypeError = ''.obs;
  final RxString pageError = ''.obs;
  final RxString tableError = ''.obs;
  final RxString xAxisError = ''.obs;
  final RxString yAxisError = ''.obs;
  final RxString columnError = ''.obs;
  final RxString formulaError = ''.obs;

  final Uuid _uuid = const Uuid();
  List<TableSchemaEntity> _schemaCache = <TableSchemaEntity>[];

  @override
  void onInit() {
    super.onInit();
    _loadPages();
    _loadSchemas();
  }

  @override
  void onClose() {
    titleController.dispose();
    formulaController.dispose();
    super.onClose();
  }

  Future<void> _loadPages() async {
    isLoadingPages.value = true;
    try {
      final pages = await _getPages();
      pageOptions.assignAll(
        pages
            .where((p) => !p.isDeleted)
            .map((p) => WidgetPageOption(id: p.id, name: p.name))
            .toList(growable: false),
      );
    } finally {
      isLoadingPages.value = false;
    }
  }

  Future<void> _loadSchemas() async {
    try {
      final List<TableSchemaEntity> list = await _getAllSchemas();
      _schemaCache = list;
      allTableSchemas.assignAll(list);
    } catch (_) {
      _schemaCache = <TableSchemaEntity>[];
      allTableSchemas.clear();
    }
  }

  List<TableSchemaEntity> get filteredTables {
    final String q = tableSearchQuery.value.trim().toLowerCase();
    if (q.isEmpty) {
      return allTableSchemas.toList(growable: false);
    }
    return allTableSchemas
        .where((TableSchemaEntity s) => s.name.toLowerCase().contains(q))
        .toList(growable: false);
  }

  TableSchemaEntity? schemaById(String? id) {
    if (id == null || id.isEmpty) {
      return null;
    }
    for (final TableSchemaEntity s in _schemaCache) {
      if (s.id == id) {
        return s;
      }
    }
    return null;
  }

  void onTableSelected(String? id) {
    selectedTableId.value = id;
    selectedXAxisColumnId.value = null;
    selectedYAxisColumnId.value = null;
    selectedColumnId.value = null;
    tableError.value = '';
    xAxisError.value = '';
    yAxisError.value = '';
    columnError.value = '';
  }

  void onColumnSelected(String? id) {
    selectedColumnId.value = id;
    columnError.value = '';
  }

  void onXAxisColumnSelected(String? id) {
    selectedXAxisColumnId.value = id;
    xAxisError.value = '';
  }

  void onYAxisColumnSelected(String? id) {
    selectedYAxisColumnId.value = id;
    yAxisError.value = '';
  }

  void pickWidgetType(BuilderWidgetType type) {
    if (selectedWidgetType.value == type) {
      return;
    }
    selectedWidgetType.value = type;
    widgetTypeError.value = '';
    layoutError.value = '';
    chartTypeError.value = '';
    if (type == BuilderWidgetType.card) {
      selectedChartType.value = null;
      selectedXAxisColumnId.value = null;
      selectedYAxisColumnId.value = null;
    } else {
      selectedLayout.value = null;
      selectedColumnId.value = null;
    }
  }

  void pickLayout(CardWidgetLayout layout) {
    selectedLayout.value = layout;
    layoutError.value = '';
  }

  void pickChartType(ChartWidgetType chartType) {
    selectedChartType.value = chartType;
    chartTypeError.value = '';
  }

  void clearStepErrors() {
    widgetTypeError.value = '';
    layoutError.value = '';
    chartTypeError.value = '';
    pageError.value = '';
    tableError.value = '';
    xAxisError.value = '';
    yAxisError.value = '';
    columnError.value = '';
    formulaError.value = '';
  }

  bool _validateFormulaOptional() {
    formulaError.value = '';
    final String raw = formulaController.text.trim();
    if (raw.isEmpty) {
      return true;
    }
    final String? msg = TableFormulaValidator.validate(
      formula: raw,
      currentColumnId: syntheticFormulaColumnId,
      siblingColumns: const <ColumnNameDraft>[],
      existingTables:
          _schemaCache.isNotEmpty
              ? _schemaCache
              : allTableSchemas.toList(growable: false),
    );
    if (msg != null) {
      formulaError.value = msg;
      return false;
    }
    return true;
  }

  String? validateForStep(int step) {
    clearStepErrors();
    switch (step) {
      case 0:
        if (selectedWidgetType.value == null) {
          widgetTypeError.value = 'Select a widget type';
          return widgetTypeError.value;
        }
        return null;
      case 1:
        if (selectedWidgetType.value == BuilderWidgetType.card) {
          if (selectedLayout.value == null) {
            layoutError.value = 'Select a card layout';
            return layoutError.value;
          }
          return null;
        }
        if (selectedChartType.value == null) {
          chartTypeError.value = 'Select a chart type';
          return chartTypeError.value;
        }
        return null;
      case 2:
        if (selectedPageId.value == null || selectedPageId.value!.isEmpty) {
          pageError.value = 'Assign a page';
          return pageError.value;
        }
        if (selectedTableId.value == null || selectedTableId.value!.isEmpty) {
          tableError.value = 'Select a source table';
          return tableError.value;
        }
        final BuilderWidgetType type =
            selectedWidgetType.value ?? BuilderWidgetType.card;
        if (type == BuilderWidgetType.card) {
          if (selectedColumnId.value == null ||
              selectedColumnId.value!.isEmpty) {
            columnError.value = 'Select a column';
            return columnError.value;
          }
        } else {
          if (selectedXAxisColumnId.value == null ||
              selectedXAxisColumnId.value!.isEmpty) {
            xAxisError.value = 'Select an X-axis column';
            return xAxisError.value;
          }
          if ((selectedYAxisColumnId.value == null ||
                  selectedYAxisColumnId.value!.isEmpty) &&
              formulaController.text.trim().isEmpty) {
            yAxisError.value = 'Select a Y-axis column or add a formula';
            return yAxisError.value;
          }
        }
        if (!_validateFormulaOptional()) {
          return formulaError.value;
        }
        final TableSchemaEntity? t = schemaById(selectedTableId.value);
        if (t == null) {
          tableError.value = 'Table is no longer available';
          return tableError.value;
        }
        if (type == BuilderWidgetType.card) {
          bool colOk = false;
          for (final TableColumnEntity c in t.columns) {
            if (c.id == selectedColumnId.value) {
              colOk = true;
              break;
            }
          }
          if (!colOk) {
            columnError.value = 'Column is no longer available';
            return columnError.value;
          }
        } else {
          bool xColOk = false;
          bool yColOk = selectedYAxisColumnId.value == null;
          for (final TableColumnEntity c in t.columns) {
            if (c.id == selectedXAxisColumnId.value) {
              xColOk = true;
            }
            if (c.id == selectedYAxisColumnId.value) {
              yColOk = true;
            }
          }
          if (!xColOk) {
            xAxisError.value = 'X-axis column is no longer available';
            return xAxisError.value;
          }
          if (!yColOk) {
            yAxisError.value = 'Y-axis column is no longer available';
            return yAxisError.value;
          }
          if (selectedYAxisColumnId.value != null &&
              selectedYAxisColumnId.value!.isNotEmpty) {
            TableColumnEntity? yColumn;
            for (final TableColumnEntity c in t.columns) {
              if (c.id == selectedYAxisColumnId.value) {
                yColumn = c;
                break;
              }
            }
            if (yColumn != null &&
                yColumn.type != TableColumnType.number &&
                yColumn.type != TableColumnType.currency &&
                yColumn.type != TableColumnType.formula) {
              yAxisError.value = 'Y-axis column must be numeric';
              return yAxisError.value;
            }
          }
        }
        return null;
      default:
        return null;
    }
  }

  Future<void> goNext() async {
    final int step = currentStep.value;
    final String? err = validateForStep(step);
    if (err != null) {
      showAppSnackbar('Validation', err);
      return;
    }
    if (step >= 2) {
      return;
    }
    currentStep.value++;
  }

  void goBack() {
    clearStepErrors();
    if (currentStep.value > 0) {
      currentStep.value--;
    } else {
      Get.back<void>();
    }
  }

  Future<int> _nextDisplayOrder(String pageId) async {
    try {
      final List<BuilderWidgetEntity> existing =
          await _getWidgetsByPage(pageId);
      int maxOrder = 0;
      for (final BuilderWidgetEntity w in existing) {
        final int? o =
            (w.config['widgetOrder'] as num?)?.toInt() ??
            (w.config['tableOrder'] as num?)?.toInt();
        if (o != null && o > maxOrder) {
          maxOrder = o;
        }
      }
      return maxOrder + 1;
    } catch (_) {
      return 1;
    }
  }

  Future<void> submit() async {
    final String? err = validateForStep(2);
    if (err != null) {
      showAppSnackbar('Validation', err);
      currentStep.value = 2;
      return;
    }
    final String? pageId = selectedPageId.value;
    if (pageId == null) {
      pageError.value = 'Assign a page';
      return;
    }
    final TableSchemaEntity? table = schemaById(selectedTableId.value);
    final BuilderWidgetType widgetType =
        selectedWidgetType.value ?? BuilderWidgetType.card;
    final CardWidgetLayout layout = selectedLayout.value ?? CardWidgetLayout.simple;
    final ChartWidgetType chartType = selectedChartType.value ?? ChartWidgetType.bar;
    if (table == null) {
      return;
    }
    isSaving.value = true;
    try {
      await _loadSchemas();
      final TableSchemaEntity? fresh = schemaById(table.id);
      if (fresh == null) {
        showAppSnackbar('Validation', 'Table was removed');
        return;
      }
      TableColumnEntity? column;
      TableColumnEntity? xColumn;
      TableColumnEntity? yColumn;
      for (final TableColumnEntity c in fresh.columns) {
        if (c.id == selectedColumnId.value) {
          column = c;
        }
        if (c.id == selectedXAxisColumnId.value) {
          xColumn = c;
        }
        if (c.id == selectedYAxisColumnId.value) {
          yColumn = c;
        }
      }
      if (widgetType == BuilderWidgetType.card) {
        if (column == null) {
          showAppSnackbar('Validation', 'Column was removed');
          return;
        }
      } else if (xColumn == null) {
        showAppSnackbar('Validation', 'X-axis column was removed');
        return;
      }
      if (!_validateFormulaOptional()) {
        return;
      }
      final String formulaTrim = formulaController.text.trim();
      if (widgetType == BuilderWidgetType.card) {
        final String preview = cardEffectiveDisplayFormula(
          table: fresh,
          column: column!,
          userFormula: formulaTrim.isEmpty ? null : formulaTrim,
        );
        final String? syntaxCheck = TableFormulaValidator.validate(
          formula: preview,
          currentColumnId: syntheticFormulaColumnId,
          siblingColumns: const <ColumnNameDraft>[],
          existingTables: _schemaCache,
        );
        if (syntaxCheck != null) {
          formulaError.value = syntaxCheck;
          showAppSnackbar('Validation', syntaxCheck);
          return;
        }
      }

      final int order = await _nextDisplayOrder(pageId);
      final String widgetId = _uuid.v4();
      final Map<String, dynamic> config = <String, dynamic>{
        if (titleController.text.trim().isNotEmpty)
          'title': titleController.text.trim(),
        'tableId': fresh.id,
        'widgetOrder': order,
      };
      if (widgetType == BuilderWidgetType.card) {
        config['cardLayout'] = layout.storageValue;
        config['columnId'] = column!.id;
      } else {
        config['chartType'] = chartType.name;
        config['xColumnId'] = xColumn!.id;
        if (yColumn != null) {
          config['yColumnId'] = yColumn.id;
        }
      }
      if (formulaTrim.isNotEmpty) {
        config['formula'] = formulaTrim;
      }
      await _saveWidget(
        BuilderWidgetEntity(
          id: widgetId,
          pageId: pageId,
          type: widgetType == BuilderWidgetType.card ? 'card' : 'chart',
          config: config,
        ),
      );
      showAppSnackbar(
        'Widget',
        widgetType == BuilderWidgetType.card
            ? 'Card widget created'
            : 'Chart widget created',
      );
      Get.offAllNamed<void>(
        AppRoutes.home,
        arguments: <String, dynamic>{'selectedPageId': pageId},
      );
    } catch (e) {
      showAppSnackbar('Save failed', '$e');
    } finally {
      isSaving.value = false;
    }
  }
}

class WidgetPageOption {
  const WidgetPageOption({required this.id, required this.name});

  final String id;
  final String name;
}
