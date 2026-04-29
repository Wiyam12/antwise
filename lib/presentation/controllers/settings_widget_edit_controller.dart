import 'package:antwise/core/app_snackbar.dart';
import 'package:antwise/domain/entities/card_widget_layout.dart';
import 'package:antwise/domain/entities/builder_page_entity.dart';
import 'package:antwise/domain/entities/builder_widget_entity.dart';
import 'package:antwise/domain/entities/table_column_entity.dart';
import 'package:antwise/domain/entities/table_column_type.dart';
import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/domain/usecases/get_all_builder_widgets_usecase.dart';
import 'package:antwise/domain/usecases/get_all_table_schemas_usecase.dart';
import 'package:antwise/domain/usecases/get_builder_pages_usecase.dart';
import 'package:antwise/domain/usecases/save_builder_widget_usecase.dart';
import 'package:antwise/domain/validation/table_formula_validator.dart';
import 'package:file_picker/file_picker.dart';
import 'package:antwise/presentation/controllers/home_controller.dart';
import 'package:antwise/presentation/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum SettingsChartWidgetType { bar, line, pie }
enum SettingsChartDateGroupingFilter { daily, weekly, monthly, yearly }

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
  final RxInt currentStep = 0.obs;
  final Rxn<BuilderWidgetEntity> widget = Rxn<BuilderWidgetEntity>();
  final RxList<TableSchemaEntity> allSchemas = <TableSchemaEntity>[].obs;
  final RxList<BuilderPageEntity> pages = <BuilderPageEntity>[].obs;

  final TextEditingController titleController = TextEditingController();
  final TextEditingController formulaController = TextEditingController();
  final TextEditingController heroCardNameController = TextEditingController();
  final TextEditingController heroLabelController = TextEditingController();
  final TextEditingController heroPrefixTextController = TextEditingController();
  final TextEditingController percentCardNameController = TextEditingController();
  final TextEditingController percentLabelController = TextEditingController();

  final Rxn<CardWidgetLayout> selectedLayout = Rxn<CardWidgetLayout>();
  final Rxn<SettingsChartWidgetType> selectedChartType =
      Rxn<SettingsChartWidgetType>();
  final RxnString selectedTableId = RxnString();
  final RxnString selectedPageId = RxnString();
  final RxnString selectedXAxisColumnId = RxnString();
  final RxnString selectedYAxisColumnId = RxnString();
  final RxnString selectedColumnId = RxnString();
  final RxSet<SettingsChartDateGroupingFilter> selectedDateGroupingFilters =
      <SettingsChartDateGroupingFilter>{}.obs;

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
  final RxString heroLayoutError = ''.obs;
  final RxString percentLayoutError = ''.obs;
  final RxString heroCardNameValue = ''.obs;
  final RxString heroLabelValue = ''.obs;
  final RxString heroBackgroundHex = '#4F46E5'.obs;
  final RxnString heroBackgroundImagePath = RxnString();
  final RxString heroPrefixType = 'none'.obs;
  final RxnString heroPrefixIconKey = RxnString();
  final RxString percentCardNameValue = ''.obs;
  final RxString percentLabelValue = ''.obs;
  final RxString percentBackgroundHex = '#2F80ED'.obs;
  final RxnString percentBackgroundImagePath = RxnString();
  final RxnString percentIconKey = RxnString();

  String? _widgetId;
  List<BuilderWidgetEntity> _allWidgetsCache = <BuilderWidgetEntity>[];

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
    heroCardNameController.dispose();
    heroLabelController.dispose();
    heroPrefixTextController.dispose();
    percentCardNameController.dispose();
    percentLabelController.dispose();
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
      _allWidgetsCache = allWidgets;
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
      selectedChartType.value = switch (target.config['chartType']
          ?.toString()) {
        'line' => SettingsChartWidgetType.line,
        'pie' => SettingsChartWidgetType.pie,
        _ => SettingsChartWidgetType.bar,
      };
      selectedTableId.value = target.config['tableId']?.toString();
      selectedPageId.value = target.pageId;
      selectedColumnId.value = target.config['columnId']?.toString();
      selectedXAxisColumnId.value = target.config['xColumnId']?.toString();
      selectedYAxisColumnId.value = target.config['yColumnId']?.toString();
      selectedDateGroupingFilters.clear();
      final List<dynamic> rawDateFilters =
          (target.config['enabledDateFilters'] as List<dynamic>?) ??
          const <dynamic>[];
      for (final dynamic item in rawDateFilters) {
        final String token = item.toString().trim().toLowerCase();
        SettingsChartDateGroupingFilter? parsed;
        for (final SettingsChartDateGroupingFilter option
            in SettingsChartDateGroupingFilter.values) {
          if (option.name == token) {
            parsed = option;
            break;
          }
        }
        if (parsed != null) {
          selectedDateGroupingFilters.add(parsed);
        }
      }
      heroCardNameController.text =
          target.config['heroCardName']?.toString() ?? '';
      heroLabelController.text = target.config['heroLabel']?.toString() ?? '';
      heroPrefixTextController.text =
          target.config['heroPrefixText']?.toString() ?? '';
      heroCardNameValue.value = heroCardNameController.text;
      heroLabelValue.value = heroLabelController.text;
      heroBackgroundHex.value =
          target.config['heroBackgroundHex']?.toString() ?? '#4F46E5';
      heroBackgroundImagePath.value =
          target.config['heroBackgroundImagePath']?.toString();
      heroPrefixType.value =
          target.config['heroPrefixType']?.toString() ?? 'none';
      heroPrefixIconKey.value = target.config['heroPrefixIconKey']?.toString();
      percentCardNameController.text =
          target.config['percentCardName']?.toString() ?? '';
      percentLabelController.text =
          target.config['percentLabel']?.toString() ?? '';
      percentCardNameValue.value = percentCardNameController.text;
      percentLabelValue.value = percentLabelController.text;
      percentBackgroundHex.value =
          target.config['percentBackgroundHex']?.toString() ?? '#2F80ED';
      percentBackgroundImagePath.value =
          target.config['percentBackgroundImagePath']?.toString();
      percentIconKey.value = target.config['percentIconKey']?.toString();
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
    heroLayoutError.value = '';
    percentLayoutError.value = '';
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

  void setPercentIconKey(String? iconKey) {
    percentIconKey.value = iconKey;
  }

  double previewPercentFromFormula(String raw) {
    final double? parsed = double.tryParse(raw.trim());
    if (parsed == null) {
      return 35;
    }
    return parsed.clamp(0, 100);
  }

  void onPageChanged(String? pageId) {
    selectedPageId.value = pageId;
    pageError.value = '';
  }

  void onTableChanged(String? tableId) {
    selectedTableId.value = tableId;
    selectedColumnId.value = null;
    selectedXAxisColumnId.value = null;
    selectedYAxisColumnId.value = null;
    selectedDateGroupingFilters.clear();
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
    if (isDateXAxisSelectedForChart && selectedDateGroupingFilters.isEmpty) {
      selectedDateGroupingFilters.addAll(SettingsChartDateGroupingFilter.values);
    }
  }

  void onYAxisColumnChanged(String? columnId) {
    selectedYAxisColumnId.value = columnId;
    yAxisError.value = '';
  }

  void pickChartType(SettingsChartWidgetType type) {
    selectedChartType.value = type;
    chartTypeError.value = '';
    if (type != SettingsChartWidgetType.line) {
      selectedDateGroupingFilters.clear();
    }
  }

  bool get isDateXAxisSelectedForChart {
    if (!isChartWidget) {
      return false;
    }
    final String? xId = selectedXAxisColumnId.value;
    if (xId == null || xId.isEmpty) {
      return false;
    }
    final TableSchemaEntity? t = selectedTable;
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

  void toggleDateGroupingFilter(
    SettingsChartDateGroupingFilter filter,
    bool enabled,
  ) {
    if (enabled) {
      selectedDateGroupingFilters.add(filter);
    } else {
      selectedDateGroupingFilters.remove(filter);
    }
  }

  bool _validate() {
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

    final String? pageId = selectedPageId.value;
    if (pageId == null || pageId.isEmpty) {
      pageError.value = 'Assign a page';
      return false;
    }
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
      final String chartName = titleController.text.trim();
      if (chartName.isEmpty) {
        chartNameError.value = 'Chart name is required';
        return false;
      }
      final String? pageId = selectedPageId.value;
      if (pageId != null && pageId.isNotEmpty) {
        final String normalized = chartName.toLowerCase();
        final String currentId = widget.value?.id ?? '';
        for (final BuilderWidgetEntity item in _allWidgetsCache) {
          if (item.id == currentId ||
              item.type != 'chart' ||
              item.pageId != pageId) {
            continue;
          }
          final String existing = (item.config['title']?.toString() ?? '')
              .trim()
              .toLowerCase();
          if (existing.isNotEmpty && existing == normalized) {
            chartNameError.value = 'Chart name must be unique on this page';
            return false;
          }
        }
      }
      if (selectedChartType.value == SettingsChartWidgetType.line &&
          isDateXAxisSelectedForChart &&
          selectedDateGroupingFilters.isEmpty) {
        xAxisError.value = 'Select at least one date filter option';
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

  String? validateForStep(int step) {
    switch (step) {
      case 0:
        if (widget.value == null) {
          widgetTypeError.value = 'Widget not found';
          return widgetTypeError.value;
        }
        return null;
      case 1:
        if (isCardWidget && selectedLayout.value == null) {
          layoutError.value = 'Card layout is required';
          return layoutError.value;
        }
        if (isChartWidget && selectedChartType.value == null) {
          chartTypeError.value = 'Chart type is required';
          return chartTypeError.value;
        }
        return null;
      case 2:
        if (!_validate()) {
          return 'Please fix the highlighted fields.';
        }
        return null;
      case 3:
        return null;
      default:
        return null;
    }
  }

  Future<void> goNext() async {
    final String? error = validateForStep(currentStep.value);
    if (error != null) {
      showAppSnackbar('Validation', error);
      return;
    }
    if (currentStep.value >= 2) {
      return;
    }
    currentStep.value++;
  }

  void goBack() {
    if (currentStep.value > 0) {
      currentStep.value--;
      return;
    }
    Get.back<void>();
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
      final String? resolvedTableId =
          selectedTableId.value ?? current.config['tableId']?.toString();
      final Map<String, dynamic> nextConfig = <String, dynamic>{
        ...current.config,
      };
      if (resolvedTableId != null && resolvedTableId.isNotEmpty) {
        nextConfig['tableId'] = resolvedTableId;
      }
      if (isCardWidget) {
        final CardWidgetLayout? layout = selectedLayout.value;
        if (layout != null) {
          nextConfig['cardLayout'] = layout.storageValue;
        }
        final String? resolvedColumnId =
            selectedColumnId.value ?? current.config['columnId']?.toString();
        if (resolvedColumnId != null && resolvedColumnId.isNotEmpty) {
          nextConfig['columnId'] = resolvedColumnId;
        }
        nextConfig.remove('chartType');
        nextConfig.remove('xColumnId');
        nextConfig.remove('yColumnId');
        if (layout == CardWidgetLayout.hero) {
          nextConfig['heroCardName'] = heroCardNameController.text.trim();
          nextConfig['heroLabel'] = heroLabelController.text.trim();
          nextConfig['heroBackgroundHex'] = heroBackgroundHex.value.trim();
          nextConfig['heroPrefixType'] = heroPrefixType.value;
          final String prefixText = heroPrefixTextController.text.trim();
          if (prefixText.isEmpty) {
            nextConfig.remove('heroPrefixText');
          } else {
            nextConfig['heroPrefixText'] = prefixText;
          }
          final String? prefixIcon = heroPrefixIconKey.value?.trim();
          if (prefixIcon == null || prefixIcon.isEmpty) {
            nextConfig.remove('heroPrefixIconKey');
          } else {
            nextConfig['heroPrefixIconKey'] = prefixIcon;
          }
          final String? imagePath = heroBackgroundImagePath.value?.trim();
          if (imagePath == null || imagePath.isEmpty) {
            nextConfig.remove('heroBackgroundImagePath');
          } else {
            nextConfig['heroBackgroundImagePath'] = imagePath;
          }
        }
        if (layout == CardWidgetLayout.percent) {
          nextConfig['percentCardName'] = percentCardNameController.text.trim();
          nextConfig['percentLabel'] = percentLabelController.text.trim();
          nextConfig['percentBackgroundHex'] = percentBackgroundHex.value.trim();
          final String? iconKey = percentIconKey.value?.trim();
          if (iconKey == null || iconKey.isEmpty) {
            nextConfig.remove('percentIconKey');
          } else {
            nextConfig['percentIconKey'] = iconKey;
          }
          final String? imagePath = percentBackgroundImagePath.value?.trim();
          if (imagePath == null || imagePath.isEmpty) {
            nextConfig.remove('percentBackgroundImagePath');
          } else {
            nextConfig['percentBackgroundImagePath'] = imagePath;
          }
        }
      } else if (isChartWidget) {
        nextConfig['chartType'] = selectedChartType.value?.name ?? 'bar';
        final String? resolvedXColumnId =
            selectedXAxisColumnId.value ??
            current.config['xColumnId']?.toString();
        if (resolvedXColumnId != null && resolvedXColumnId.isNotEmpty) {
          nextConfig['xColumnId'] = resolvedXColumnId;
        }
        final String? y = selectedYAxisColumnId.value;
        if (y == null || y.isEmpty) {
          nextConfig.remove('yColumnId');
        } else {
          nextConfig['yColumnId'] = y;
        }
        if (selectedChartType.value == SettingsChartWidgetType.line &&
            isDateXAxisSelectedForChart) {
          nextConfig['enabledDateFilters'] = selectedDateGroupingFilters
              .map((SettingsChartDateGroupingFilter f) => f.name)
              .toList(growable: false);
        } else {
          nextConfig.remove('enabledDateFilters');
        }
        nextConfig.remove('cardLayout');
        nextConfig.remove('columnId');
      }
      final String title = titleController.text.trim();
      if (title.isEmpty) {
        if (isChartWidget) {
          nextConfig['title'] = title;
        } else {
          nextConfig.remove('title');
        }
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
          pageId: selectedPageId.value ?? current.pageId,
          type: current.type,
          config: nextConfig,
        ),
      );
      if (Get.isRegistered<HomeController>()) {
        Get.find<HomeController>().refreshBuilderPageContent();
      }
      final String targetPageId = selectedPageId.value ?? current.pageId;
      final String snackbarTitle =
          titleController.text.trim().isNotEmpty
              ? titleController.text.trim()
              : current.config['title']?.toString().trim().isNotEmpty == true
              ? current.config['title'].toString().trim()
              : 'Widget';
      showAppSnackbar('$snackbarTitle Widget', 'Changes saved');
      Get.offAllNamed<void>(
        AppRoutes.home,
        arguments: <String, dynamic>{'selectedPageId': targetPageId},
      );
    } finally {
      isSaving.value = false;
    }
  }
}
