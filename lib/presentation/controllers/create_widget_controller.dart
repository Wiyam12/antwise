import 'package:antwise/core/app_snackbar.dart';
import 'package:antwise/domain/entities/builder_widget_entity.dart';
import 'package:antwise/domain/entities/card_widget_layout.dart';
import 'package:antwise/domain/entities/table_column_entity.dart';
import 'package:antwise/domain/entities/table_column_type.dart';
import 'package:antwise/domain/entities/table_row_entity.dart';
import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/domain/formula/table_formula_evaluator.dart';
import 'package:antwise/domain/usecases/get_all_table_schemas_usecase.dart';
import 'package:antwise/domain/usecases/get_all_builder_widgets_usecase.dart';
import 'package:antwise/domain/usecases/get_builder_pages_usecase.dart';
import 'package:antwise/domain/usecases/get_builder_widgets_by_page_usecase.dart';
import 'package:antwise/domain/usecases/get_table_rows_usecase.dart';
import 'package:antwise/domain/usecases/save_builder_widget_usecase.dart';
import 'package:antwise/domain/validation/table_formula_validator.dart';
import 'package:antwise/domain/widgets/compute_card_widget_value.dart';
import 'package:antwise/presentation/routes/app_routes.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

enum BuilderWidgetType { card, chart }
enum ChartWidgetType { bar, line, pie }
enum ChartDateGroupingFilter { daily, weekly, monthly, yearly }

class CreateWidgetController extends GetxController {
  CreateWidgetController(
    this._getPages,
    this._saveWidget,
    this._getAllSchemas,
    this._getWidgetsByPage,
    this._getAllWidgets,
    this._getTableRows,
  );

  final GetBuilderPagesUseCase _getPages;
  final SaveBuilderWidgetUseCase _saveWidget;
  final GetAllTableSchemasUseCase _getAllSchemas;
  final GetBuilderWidgetsByPageUseCase _getWidgetsByPage;
  final GetAllBuilderWidgetsUseCase _getAllWidgets;
  final GetTableRowsUseCase _getTableRows;

  static const String syntheticFormulaColumnId = '_card_metric';

  final RxInt currentStep = 0.obs;
  final RxBool isSaving = false.obs;
  final RxBool isLoadingPages = true.obs;
  final RxList<WidgetPageOption> pageOptions = <WidgetPageOption>[].obs;
  final RxList<TableSchemaEntity> allTableSchemas =
      <TableSchemaEntity>[].obs;

  final TextEditingController titleController = TextEditingController();
  final TextEditingController formulaController = TextEditingController();
  final TextEditingController customTemplateNameController =
      TextEditingController();

  final Rxn<BuilderWidgetType> selectedWidgetType = Rxn<BuilderWidgetType>();
  final RxnString selectedPageId = RxnString();
  final RxString tableSearchQuery = ''.obs;
  final Rxn<CardWidgetLayout> selectedLayout = Rxn<CardWidgetLayout>();
  final Rxn<ChartWidgetType> selectedChartType = Rxn<ChartWidgetType>();
  final RxnString selectedTableId = RxnString();
  final RxnString selectedXAxisColumnId = RxnString();
  final RxnString selectedYAxisColumnId = RxnString();
  final RxnString selectedColumnId = RxnString();
  final RxSet<ChartDateGroupingFilter> selectedDateGroupingFilters =
      <ChartDateGroupingFilter>{}.obs;
  final RxBool useSavedCustomTemplate = false.obs;
  final RxList<CustomCardTemplateOption> customTemplateOptions =
      <CustomCardTemplateOption>[].obs;
  final RxnString selectedCustomTemplateId = RxnString();
  final RxBool customShowIcon = true.obs;
  final RxBool customFilledBackground = true.obs;
  final RxBool customShowBorder = false.obs;
  final RxDouble customCornerRadius = 16.0.obs;
  final RxDouble customPadding = 16.0.obs;
  final RxDouble customValueFontSize = 30.0.obs;
  final RxString customAccentStyle = 'none'.obs;
  final TextEditingController heroCardNameController = TextEditingController();
  final TextEditingController heroLabelController = TextEditingController();
  final TextEditingController heroPrefixTextController = TextEditingController();
  final RxString heroCardNameValue = ''.obs;
  final RxString heroLabelValue = ''.obs;
  final RxString heroBackgroundHex = '#4F46E5'.obs;
  final RxnString heroBackgroundImagePath = RxnString();
  final RxString heroPrefixType = 'none'.obs;
  final RxnString heroPrefixIconKey = RxnString();
  final TextEditingController percentCardNameController = TextEditingController();
  final TextEditingController percentLabelController = TextEditingController();
  final TextEditingController percentNumeratorFormulaController =
      TextEditingController();
  final TextEditingController percentDenominatorFormulaController =
      TextEditingController();
  final RxString percentCardNameValue = ''.obs;
  final RxString percentLabelValue = ''.obs;
  final RxString percentNumeratorFormulaValue = ''.obs;
  final RxString percentDenominatorFormulaValue = ''.obs;
  final RxString percentCombinedFormulaPreview = ''.obs;
  final RxString percentBackgroundHex = '#2F80ED'.obs;
  final RxnString percentBackgroundImagePath = RxnString();
  final RxnString percentIconKey = RxnString();

  final RxString widgetTypeError = ''.obs;
  final RxString layoutError = ''.obs;
  final RxString chartTypeError = ''.obs;
  final RxString pageError = ''.obs;
  final RxString tableError = ''.obs;
  final RxString xAxisError = ''.obs;
  final RxString yAxisError = ''.obs;
  final RxString columnError = ''.obs;
  final RxString formulaError = ''.obs;
  final RxString chartNameError = ''.obs;
  final RxString customTemplateError = ''.obs;
  final RxString heroLayoutError = ''.obs;
  final RxString percentLayoutError = ''.obs;

  final Uuid _uuid = const Uuid();
  List<TableSchemaEntity> _schemaCache = <TableSchemaEntity>[];
  List<BuilderWidgetEntity> _allWidgetsCache = <BuilderWidgetEntity>[];
  final Map<String, List<TableRowEntity>> _rowsByTableIdPreview =
      <String, List<TableRowEntity>>{};

  @override
  void onInit() {
    super.onInit();
    percentNumeratorFormulaController.addListener(
      _onPercentNumeratorFormulaChanged,
    );
    percentDenominatorFormulaController.addListener(
      _onPercentDenominatorFormulaChanged,
    );
    _loadPages();
    _loadSchemas();
    _loadCustomTemplates();
  }

  @override
  void onClose() {
    percentNumeratorFormulaController.removeListener(
      _onPercentNumeratorFormulaChanged,
    );
    percentDenominatorFormulaController.removeListener(
      _onPercentDenominatorFormulaChanged,
    );
    titleController.dispose();
    formulaController.dispose();
    customTemplateNameController.dispose();
    heroCardNameController.dispose();
    heroLabelController.dispose();
    heroPrefixTextController.dispose();
    percentCardNameController.dispose();
    percentLabelController.dispose();
    percentNumeratorFormulaController.dispose();
    percentDenominatorFormulaController.dispose();
    super.onClose();
  }

  void _onPercentNumeratorFormulaChanged() {
    final String value = percentNumeratorFormulaController.text;
    if (percentNumeratorFormulaValue.value != value) {
      percentNumeratorFormulaValue.value = value;
    }
    _refreshPercentCombinedFormula();
  }

  void _onPercentDenominatorFormulaChanged() {
    final String value = percentDenominatorFormulaController.text;
    if (percentDenominatorFormulaValue.value != value) {
      percentDenominatorFormulaValue.value = value;
    }
    _refreshPercentCombinedFormula();
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
      await _loadRowsForPreview(list);
    } catch (_) {
      _schemaCache = <TableSchemaEntity>[];
      allTableSchemas.clear();
      _rowsByTableIdPreview.clear();
    }
  }

  Future<void> _loadRowsForPreview(List<TableSchemaEntity> schemas) async {
    _rowsByTableIdPreview.clear();
    for (final TableSchemaEntity schema in schemas) {
      try {
        final List<TableRowEntity> rows = await _getTableRows(schema.id);
        _rowsByTableIdPreview[schema.id] = rows;
      } catch (_) {
        _rowsByTableIdPreview[schema.id] = const <TableRowEntity>[];
      }
    }
  }

  double previewPercentFromFormula(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return 35;
    }
    final double? direct = double.tryParse(trimmed);
    if (direct != null) {
      return direct.clamp(0, 100);
    }
    final double? evaluated = _evaluatePercentFormulaWithRows(trimmed);
    if (evaluated != null) {
      return evaluated.clamp(0, 100);
    }
    final String normalized = _normalizePercentPreviewExpression(trimmed);
    final RegExp numericExpression = RegExp(r'^[0-9+\-*/().\s]+$');
    if (!numericExpression.hasMatch(normalized)) {
      return 35;
    }
    final double? simple = _tryEvalSimpleExpression(normalized);
    if (simple == null) {
      return 35;
    }
    return simple.clamp(0, 100);
  }

  double? _evaluatePercentFormulaWithRows(String formula) {
    if (_schemaCache.isEmpty) {
      return null;
    }
    final TableSchemaEntity current =
        _pickPreviewSchema(formula) ?? _schemaCache.first;
    final String evaluated = TableFormulaEvaluator.evaluate(
      formula: formula,
      currentSchema: current,
      workingRowByColId: const <String, dynamic>{},
      allSchemas: _schemaCache,
      rowsByTableId: _rowsByTableIdPreview,
      forColumnId: syntheticFormulaColumnId,
    ).trim();
    if (evaluated.isEmpty) {
      return null;
    }
    return double.tryParse(evaluated);
  }

  TableSchemaEntity? _pickPreviewSchema(String formula) {
    final RegExp qualifiedRef = RegExp(
      r'(?:"([^"]+)"|([A-Za-z_]\w*))\s*\.\s*(?:"([^"]+)"|([A-Za-z_]\w*))',
    );
    final RegExpMatch? match = qualifiedRef.firstMatch(formula);
    if (match == null) {
      return null;
    }
    final String tableName = (match.group(1) ?? match.group(2) ?? '').trim();
    if (tableName.isEmpty) {
      return null;
    }
    for (final TableSchemaEntity schema in _schemaCache) {
      if (schema.name.trim() == tableName) {
        return schema;
      }
    }
    return null;
  }

  String _normalizePercentPreviewExpression(String expression) {
    String normalized = expression;
    normalized = normalized.replaceAll(RegExp(r'"([^"\\]|\\.)*"'), '1');
    normalized = normalized.replaceAll(
      RegExp(r'\b(?:SUM|AVG|MIN|MAX|COUNT)\s*\(', caseSensitive: false),
      '(',
    );
    normalized = normalized.replaceAll(
      RegExp(r'\b[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)+\b'),
      '1',
    );
    normalized = normalized.replaceAll(RegExp(r'\b[A-Za-z_]\w*\b'), '1');
    normalized = normalized.replaceAll(',', '+');
    return normalized;
  }

  double? _tryEvalSimpleExpression(String expression) {
    final List<String> tokens = <String>[];
    final RegExp tokenRegex = RegExp(r'\d+(?:\.\d+)?|[()+\-*/]');
    for (final Match match in tokenRegex.allMatches(
      expression.replaceAll(' ', ''),
    )) {
      tokens.add(match.group(0)!);
    }
    if (tokens.isEmpty) {
      return null;
    }
    final List<String> output = <String>[];
    final List<String> ops = <String>[];
    int idx = 0;
    while (idx < tokens.length) {
      final String t = tokens[idx];
      final double? numVal = double.tryParse(t);
      if (numVal != null) {
        output.add(t);
      } else if (t == '(') {
        ops.add(t);
      } else if (t == ')') {
        while (ops.isNotEmpty && ops.last != '(') {
          output.add(ops.removeLast());
        }
        if (ops.isEmpty) {
          return null;
        }
        ops.removeLast();
      } else {
        while (ops.isNotEmpty &&
            ops.last != '(' &&
            _precedenceOf(ops.last) >= _precedenceOf(t)) {
          output.add(ops.removeLast());
        }
        ops.add(t);
      }
      idx++;
    }
    while (ops.isNotEmpty) {
      final String op = ops.removeLast();
      if (op == '(' || op == ')') {
        return null;
      }
      output.add(op);
    }
    final List<double> stack = <double>[];
    for (final String token in output) {
      final double? n = double.tryParse(token);
      if (n != null) {
        stack.add(n);
        continue;
      }
      if (stack.length < 2) {
        return null;
      }
      final double b = stack.removeLast();
      final double a = stack.removeLast();
      switch (token) {
        case '+':
          stack.add(a + b);
        case '-':
          stack.add(a - b);
        case '*':
          stack.add(a * b);
        case '/':
          if (b == 0) {
            return null;
          }
          stack.add(a / b);
        default:
          return null;
      }
    }
    if (stack.length != 1) {
      return null;
    }
    return stack.single;
  }

  int _precedenceOf(String op) {
    return switch (op) {
      '+' || '-' => 1,
      '*' || '/' => 2,
      _ => 0,
    };
  }

  Future<void> _loadCustomTemplates() async {
    try {
      final List<BuilderWidgetEntity> allWidgets = await _getAllWidgets();
      _allWidgetsCache = allWidgets;
      final Map<String, CustomCardTemplateOption> byId =
          <String, CustomCardTemplateOption>{};
      for (final BuilderWidgetEntity widget in allWidgets) {
        if (widget.type != 'card') {
          continue;
        }
        final CardWidgetLayout layout = CardWidgetLayout.fromStorage(
          widget.config['cardLayout']?.toString(),
        );
        if (layout != CardWidgetLayout.customizable) {
          continue;
        }
        final String templateId =
            widget.config['customCardTemplateId']?.toString().trim() ?? '';
        final String templateName =
            widget.config['customCardTemplateName']?.toString().trim() ?? '';
        final Map<String, dynamic> templateConfig =
            (widget.config['customCardTemplate'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
        if (templateId.isEmpty || templateName.isEmpty) {
          continue;
        }
        byId[templateId] = CustomCardTemplateOption(
          id: templateId,
          name: templateName,
          config: templateConfig,
        );
      }
      customTemplateOptions.assignAll(byId.values);
    } catch (_) {
      _allWidgetsCache = <BuilderWidgetEntity>[];
      customTemplateOptions.clear();
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
    selectedDateGroupingFilters.clear();
    columnError.value = '';
  }

  void onColumnSelected(String? id) {
    selectedColumnId.value = id;
    columnError.value = '';
  }

  void onXAxisColumnSelected(String? id) {
    selectedXAxisColumnId.value = id;
    xAxisError.value = '';
    if (isDateXAxisSelectedForChart && selectedDateGroupingFilters.isEmpty) {
      selectedDateGroupingFilters.addAll(ChartDateGroupingFilter.values);
    }
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
      _loadCustomTemplates();
    } else {
      selectedLayout.value = null;
      selectedColumnId.value = null;
    }
  }

  void pickLayout(CardWidgetLayout layout) {
    selectedLayout.value = layout;
    layoutError.value = '';
    customTemplateError.value = '';
    if (layout != CardWidgetLayout.customizable) {
      useSavedCustomTemplate.value = false;
      selectedCustomTemplateId.value = null;
    }
    heroLayoutError.value = '';
    percentLayoutError.value = '';
    if (layout != CardWidgetLayout.hero) {
      heroBackgroundImagePath.value = null;
    }
    if (layout != CardWidgetLayout.percent) {
      percentBackgroundImagePath.value = null;
    }
    if (layout == CardWidgetLayout.percent &&
        percentNumeratorFormulaController.text.trim().isEmpty) {
      const String defaultFormula =
          'SUM(Transactions.CompletedAmount) / SUM(Transactions.TotalAmount) * 100';
      percentNumeratorFormulaController.text = defaultFormula;
      percentNumeratorFormulaValue.value = defaultFormula;
      _refreshPercentCombinedFormula();
    }
  }

  Future<void> pickHeroBackgroundImage() async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    final String? path = result?.files.single.path;
    if (path != null && path.trim().isNotEmpty) {
      heroBackgroundImagePath.value = path.trim();
    }
  }

  void clearHeroBackgroundImage() {
    heroBackgroundImagePath.value = null;
  }

  void setHeroBackgroundHex(String value) {
    heroBackgroundHex.value = value;
  }

  void setHeroCardName(String value) {
    heroCardNameValue.value = value;
  }

  void setHeroLabel(String value) {
    heroLabelValue.value = value;
  }

  void setHeroPrefixType(String type) {
    heroPrefixType.value = type;
  }

  void setHeroPrefixIconKey(String? iconKey) {
    heroPrefixIconKey.value = iconKey;
  }

  Future<void> pickPercentBackgroundImage() async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    final String? path = result?.files.single.path;
    if (path != null && path.trim().isNotEmpty) {
      percentBackgroundImagePath.value = path.trim();
    }
  }

  void clearPercentBackgroundImage() {
    percentBackgroundImagePath.value = null;
  }

  void setPercentBackgroundHex(String value) {
    percentBackgroundHex.value = value;
  }

  void setPercentCardName(String value) {
    percentCardNameValue.value = value;
  }

  void setPercentLabel(String value) {
    percentLabelValue.value = value;
  }

  void setPercentNumeratorFormula(String value) {
    percentNumeratorFormulaValue.value = value;
    _refreshPercentCombinedFormula();
  }

  void setPercentDenominatorFormula(String value) {
    percentDenominatorFormulaValue.value = value;
    _refreshPercentCombinedFormula();
  }

  String buildPercentCombinedFormula() {
    return percentNumeratorFormulaController.text.trim();
  }

  void _refreshPercentCombinedFormula() {
    percentCombinedFormulaPreview.value = buildPercentCombinedFormula();
  }

  void setPercentIconKey(String? iconKey) {
    percentIconKey.value = iconKey;
  }

  void toggleCustomTemplateMode(bool useSaved) {
    useSavedCustomTemplate.value = useSaved;
    customTemplateError.value = '';
    heroLayoutError.value = '';
    percentLayoutError.value = '';
  }

  void pickCustomTemplate(String? templateId) {
    selectedCustomTemplateId.value = templateId;
    customTemplateError.value = '';
    if (templateId == null || templateId.isEmpty) {
      return;
    }
    for (final CustomCardTemplateOption option in customTemplateOptions) {
      if (option.id == templateId) {
        _applyCustomTemplate(option);
        break;
      }
    }
  }

  void _applyCustomTemplate(CustomCardTemplateOption option) {
    customTemplateNameController.text = option.name;
    final Map<String, dynamic> c = option.config;
    customShowIcon.value = (c['showIcon'] as bool?) ?? true;
    customFilledBackground.value = (c['filledBackground'] as bool?) ?? true;
    customShowBorder.value = (c['showBorder'] as bool?) ?? false;
    customCornerRadius.value = ((c['cornerRadius'] as num?) ?? 16).toDouble();
    customPadding.value = ((c['padding'] as num?) ?? 16).toDouble();
    customValueFontSize.value = ((c['valueFontSize'] as num?) ?? 30).toDouble();
    customAccentStyle.value = c['accentStyle']?.toString() ?? 'none';
  }

  Map<String, dynamic> buildCustomTemplateConfig() {
    return <String, dynamic>{
      'showIcon': customShowIcon.value,
      'filledBackground': customFilledBackground.value,
      'showBorder': customShowBorder.value,
      'cornerRadius': customCornerRadius.value,
      'padding': customPadding.value,
      'valueFontSize': customValueFontSize.value,
      'accentStyle': customAccentStyle.value,
    };
  }

  void pickChartType(ChartWidgetType chartType) {
    selectedChartType.value = chartType;
    chartTypeError.value = '';
    if (chartType != ChartWidgetType.line) {
      selectedDateGroupingFilters.clear();
    }
  }

  bool get isDateXAxisSelectedForChart {
    if (selectedWidgetType.value != BuilderWidgetType.chart) {
      return false;
    }
    final String? xId = selectedXAxisColumnId.value;
    if (xId == null || xId.isEmpty) {
      return false;
    }
    final TableSchemaEntity? t = schemaById(selectedTableId.value);
    if (t == null) {
      return false;
    }
    for (final TableColumnEntity c in t.columns) {
      if (c.id == xId) {
        return c.type == TableColumnType.date;
      }
    }
    return false;
  }

  void toggleDateGroupingFilter(ChartDateGroupingFilter filter, bool enabled) {
    if (enabled) {
      selectedDateGroupingFilters.add(filter);
    } else {
      selectedDateGroupingFilters.remove(filter);
    }
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
    chartNameError.value = '';
    customTemplateError.value = '';
    heroLayoutError.value = '';
    percentLayoutError.value = '';
  }

  bool _validateChartName() {
    chartNameError.value = '';
    if (selectedWidgetType.value != BuilderWidgetType.chart) {
      return true;
    }
    final String chartName = titleController.text.trim();
    if (chartName.isEmpty) {
      chartNameError.value = 'Chart name is required';
      return false;
    }
    final String? pageId = selectedPageId.value;
    if (pageId == null || pageId.isEmpty) {
      return true;
    }
    final String normalized = chartName.toLowerCase();
    for (final BuilderWidgetEntity widget in _allWidgetsCache) {
      if (widget.type != 'chart' || widget.pageId != pageId) {
        continue;
      }
      final String existing = (widget.config['title']?.toString() ?? '')
          .trim()
          .toLowerCase();
      if (existing.isNotEmpty && existing == normalized) {
        chartNameError.value = 'Chart name must be unique on this page';
        return false;
      }
    }
    return true;
  }

  bool _validateFormulaOptional() {
    formulaError.value = '';
    final String raw =
        selectedWidgetType.value == BuilderWidgetType.card &&
                selectedLayout.value == CardWidgetLayout.percent
            ? buildPercentCombinedFormula()
            : formulaController.text.trim();
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
          if (selectedLayout.value == CardWidgetLayout.customizable) {
            final String templateName = customTemplateNameController.text.trim();
            if (templateName.isEmpty) {
              customTemplateError.value = 'Provide a custom card name';
              return customTemplateError.value;
            }
            if (useSavedCustomTemplate.value) {
              final String? selectedTemplateId = selectedCustomTemplateId.value;
              if (selectedTemplateId == null || selectedTemplateId.isEmpty) {
                customTemplateError.value = 'Choose a saved custom card';
                return customTemplateError.value;
              }
            }
          }
          if (selectedLayout.value == CardWidgetLayout.hero) {
            if (heroCardNameController.text.trim().isEmpty) {
              heroLayoutError.value = 'Provide a card name';
              return heroLayoutError.value;
            }
            if (heroLabelController.text.trim().isEmpty) {
              heroLayoutError.value = 'Provide a card label';
              return heroLayoutError.value;
            }
          }
          if (selectedLayout.value == CardWidgetLayout.percent) {
            if (percentCardNameController.text.trim().isEmpty) {
              percentLayoutError.value = 'Provide a card name';
              return percentLayoutError.value;
            }
            if (percentLabelController.text.trim().isEmpty) {
              percentLayoutError.value = 'Provide a label';
              return percentLayoutError.value;
            }
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
        final bool isHeroCard = selectedLayout.value == CardWidgetLayout.hero;
        final bool isPercentCard =
            selectedLayout.value == CardWidgetLayout.percent;
        if (!isPercentCard &&
            !isHeroCard &&
            (selectedTableId.value == null || selectedTableId.value!.isEmpty)) {
          tableError.value = 'Select a source table';
          return tableError.value;
        }
        final BuilderWidgetType type =
            selectedWidgetType.value ?? BuilderWidgetType.card;
        if (type == BuilderWidgetType.card) {
          if (!isPercentCard &&
              !isHeroCard &&
              (selectedColumnId.value == null ||
                  selectedColumnId.value!.isEmpty)) {
            columnError.value = 'Select a column';
            return columnError.value;
          }
          if (selectedLayout.value == CardWidgetLayout.percent) {
            final String formula = percentNumeratorFormulaController.text.trim();
            if (formula.isEmpty) {
              percentLayoutError.value = 'Provide a percent formula';
              return percentLayoutError.value;
            }
            final String? msg = TableFormulaValidator.validate(
              formula: formula,
              currentColumnId: syntheticFormulaColumnId,
              siblingColumns: const <ColumnNameDraft>[],
              existingTables:
                  _schemaCache.isNotEmpty
                      ? _schemaCache
                      : allTableSchemas.toList(growable: false),
            );
            if (msg != null) {
              percentLayoutError.value = msg;
              return percentLayoutError.value;
            }
          }
        } else {
          if (!_validateChartName()) {
            return chartNameError.value;
          }
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
          if (selectedChartType.value == ChartWidgetType.line &&
              isDateXAxisSelectedForChart &&
              selectedDateGroupingFilters.isEmpty) {
            xAxisError.value = 'Select at least one date filter option';
            return xAxisError.value;
          }
        }
        if (!_validateFormulaOptional()) {
          return formulaError.value;
        }
        final TableSchemaEntity? t = schemaById(selectedTableId.value);
        if (!isPercentCard && !isHeroCard) {
          if (t == null) {
            tableError.value = 'Table is no longer available';
            return tableError.value;
          }
        }
        if (type == BuilderWidgetType.card && !isPercentCard && !isHeroCard) {
          bool colOk = false;
          for (final TableColumnEntity c in t!.columns) {
            if (c.id == selectedColumnId.value) {
              colOk = true;
              break;
            }
          }
          if (!colOk) {
            columnError.value = 'Column is no longer available';
            return columnError.value;
          }
        } else if (type != BuilderWidgetType.card) {
          bool xColOk = false;
          bool yColOk = selectedYAxisColumnId.value == null;
          for (final TableColumnEntity c in t!.columns) {
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
    final BuilderWidgetType widgetType =
        selectedWidgetType.value ?? BuilderWidgetType.card;
    final CardWidgetLayout layout = selectedLayout.value ?? CardWidgetLayout.simple;
    final bool isHeroCard =
        widgetType == BuilderWidgetType.card && layout == CardWidgetLayout.hero;
    final bool isPercentCard =
        widgetType == BuilderWidgetType.card && layout == CardWidgetLayout.percent;
    final TableSchemaEntity? table =
        (isPercentCard || isHeroCard) ? null : schemaById(selectedTableId.value);
    final ChartWidgetType chartType = selectedChartType.value ?? ChartWidgetType.bar;
    if (!isPercentCard && !isHeroCard && table == null) {
      return;
    }
    isSaving.value = true;
    try {
      await _loadSchemas();
      final TableSchemaEntity? fresh =
          (isPercentCard || isHeroCard) ? null : schemaById(table!.id);
      if (!isPercentCard && !isHeroCard && fresh == null) {
        showAppSnackbar('Validation', 'Table was removed');
        return;
      }
      TableColumnEntity? column;
      TableColumnEntity? xColumn;
      TableColumnEntity? yColumn;
      if (!isPercentCard && !isHeroCard) {
        for (final TableColumnEntity c in fresh!.columns) {
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
      }
      if (widgetType == BuilderWidgetType.card && !isPercentCard && !isHeroCard) {
        if (column == null) {
          showAppSnackbar('Validation', 'Column was removed');
          return;
        }
      } else if (widgetType != BuilderWidgetType.card && xColumn == null) {
        showAppSnackbar('Validation', 'X-axis column was removed');
        return;
      }
      if (!_validateFormulaOptional()) {
        return;
      }
      if (widgetType == BuilderWidgetType.chart && !_validateChartName()) {
        showAppSnackbar('Validation', chartNameError.value);
        return;
      }
      final String formulaTrim = formulaController.text.trim();
      final String percentFormulaTrim = buildPercentCombinedFormula();
      final String effectiveFormula =
          widgetType == BuilderWidgetType.card &&
                  layout == CardWidgetLayout.hero &&
                  formulaTrim.isEmpty
              ? ''
              : widgetType == BuilderWidgetType.card &&
                      layout == CardWidgetLayout.percent
              ? percentFormulaTrim
              : formulaTrim;
      if (widgetType == BuilderWidgetType.card && !isPercentCard && !isHeroCard) {
        final String preview = cardEffectiveDisplayFormula(
          table: fresh!,
          column: column!,
          userFormula: effectiveFormula.isEmpty ? null : effectiveFormula,
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
        'widgetOrder': order,
      };
      if (!isPercentCard && !isHeroCard) {
        config['tableId'] = fresh!.id;
      }
      if (widgetType == BuilderWidgetType.card) {
        config['cardLayout'] = layout.storageValue;
        if (!isPercentCard && !isHeroCard) {
          config['columnId'] = column!.id;
        }
        if (layout == CardWidgetLayout.customizable) {
          final String selectedTemplateId =
              selectedCustomTemplateId.value?.trim() ?? '';
          final String templateId =
              selectedTemplateId.isNotEmpty ? selectedTemplateId : _uuid.v4();
          config['customCardTemplateId'] = templateId;
          config['customCardTemplateName'] =
              customTemplateNameController.text.trim();
          config['customCardTemplate'] = buildCustomTemplateConfig();
        }
        if (layout == CardWidgetLayout.hero) {
          config['heroCardName'] = heroCardNameController.text.trim();
          config['heroLabel'] = heroLabelController.text.trim();
          config['heroBackgroundHex'] = heroBackgroundHex.value.trim();
          config['heroPrefixType'] = heroPrefixType.value;
          final String prefixText = heroPrefixTextController.text.trim();
          if (prefixText.isNotEmpty) {
            config['heroPrefixText'] = prefixText;
          }
          final String? prefixIcon = heroPrefixIconKey.value?.trim();
          if (prefixIcon != null && prefixIcon.isNotEmpty) {
            config['heroPrefixIconKey'] = prefixIcon;
          }
          final String? imagePath = heroBackgroundImagePath.value?.trim();
          if (imagePath != null && imagePath.isNotEmpty) {
            config['heroBackgroundImagePath'] = imagePath;
          }
          if (titleController.text.trim().isEmpty) {
            config['title'] = heroCardNameController.text.trim();
          }
        }
        if (layout == CardWidgetLayout.percent) {
          config['percentCardName'] = percentCardNameController.text.trim();
          config['percentLabel'] = percentLabelController.text.trim();
          config['percentBackgroundHex'] = percentBackgroundHex.value.trim();
          config['percentNumeratorFormula'] =
              percentNumeratorFormulaController.text.trim();
          config['percentFormula'] = buildPercentCombinedFormula();
          config['formula'] = buildPercentCombinedFormula();
          final String? iconKey = percentIconKey.value?.trim();
          if (iconKey != null && iconKey.isNotEmpty) {
            config['percentIconKey'] = iconKey;
          }
          final String? imagePath = percentBackgroundImagePath.value?.trim();
          if (imagePath != null && imagePath.isNotEmpty) {
            config['percentBackgroundImagePath'] = imagePath;
          }
          if (titleController.text.trim().isEmpty) {
            config['title'] = percentCardNameController.text.trim();
          }
        }
      } else {
        config['title'] = titleController.text.trim();
        config['chartType'] = chartType.name;
        config['xColumnId'] = xColumn!.id;
        if (yColumn != null) {
          config['yColumnId'] = yColumn.id;
        }
        if (chartType == ChartWidgetType.line &&
            xColumn.type == TableColumnType.date) {
          config['enabledDateFilters'] = selectedDateGroupingFilters
              .map((ChartDateGroupingFilter f) => f.name)
              .toList(growable: false);
        } else {
          config.remove('enabledDateFilters');
        }
      }
      if (effectiveFormula.isNotEmpty) {
        config['formula'] = effectiveFormula;
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

class CustomCardTemplateOption {
  const CustomCardTemplateOption({
    required this.id,
    required this.name,
    required this.config,
  });

  final String id;
  final String name;
  final Map<String, dynamic> config;
}

class WidgetPageOption {
  const WidgetPageOption({required this.id, required this.name});

  final String id;
  final String name;
}
