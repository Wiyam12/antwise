import 'package:antwise/core/app_snackbar.dart';
import 'package:antwise/domain/entities/builder_widget_entity.dart';
import 'package:antwise/domain/entities/product_display_mode.dart';
import 'package:antwise/domain/dropdown/dropdown_column_options.dart';
import 'package:antwise/domain/entities/table_column_dropdown_source.dart';
import 'package:antwise/domain/entities/table_column_entity.dart';
import 'package:antwise/domain/entities/table_column_type.dart';
import 'package:antwise/domain/entities/table_text_validation_kind.dart';
import 'package:antwise/domain/entities/table_data_loading_mode.dart';
import 'package:antwise/domain/entities/table_affecting_config.dart';
import 'package:antwise/domain/entities/table_kind.dart';
import 'package:antwise/domain/entities/table_layout_type.dart';
import 'package:antwise/domain/entities/table_list_design_layout.dart';
import 'package:antwise/domain/entities/table_mode.dart';
import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/domain/entities/table_summary_config.dart';
import 'package:antwise/domain/entities/table_validation_rule.dart';
import 'package:antwise/domain/usecases/get_all_table_schemas_usecase.dart';
import 'package:antwise/domain/usecases/get_builder_pages_usecase.dart';
import 'package:antwise/domain/usecases/get_table_rows_usecase.dart';
import 'package:antwise/domain/usecases/save_builder_widget_usecase.dart';
import 'package:antwise/domain/usecases/save_table_row_usecase.dart';
import 'package:antwise/domain/usecases/save_table_schema_usecase.dart';
import 'package:antwise/domain/entities/table_row_entity.dart';
import 'package:antwise/domain/formula/table_formula_evaluator.dart';
import 'package:antwise/domain/validation/table_formula_validator.dart';
import 'package:antwise/presentation/models/column_draft.dart';
import 'package:antwise/presentation/models/formula_input_mode.dart';
import 'package:antwise/presentation/models/guided_formula_draft_state.dart';
import 'package:antwise/presentation/models/guided_formula_host.dart';
import 'package:antwise/presentation/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

class CreateTableController extends GetxController
    implements GuidedFormulaHost {
  CreateTableController(
    this._getPages,
    this._saveTableSchema,
    this._saveWidget,
    this._getAllSchemas,
    this._saveTableRow,
    this._getTableRows,
  );

  final GetBuilderPagesUseCase _getPages;
  final SaveTableSchemaUseCase _saveTableSchema;
  final SaveBuilderWidgetUseCase _saveWidget;
  final GetAllTableSchemasUseCase _getAllSchemas;
  final SaveTableRowUseCase _saveTableRow;
  final GetTableRowsUseCase _getTableRows;

  static const String idContactAvatar = 'contact_avatar';
  static const String idContactName = 'contact_name';
  static const String idContactSubtitle1 = 'contact_subtitle1';
  static const String idContactSubtitle2 = 'contact_subtitle2';
  static const String idProductImage = 'product_image';
  static const String idProductName = 'product_name';
  static const String idProductPrice = 'product_price';

  /// Default list row on Standard Dynamic (layout 1): same shape as contact, own ids.
  static const String idStandardAvatar = 'standard_avatar';
  static const String idStandardName = 'standard_name';
  static const String idStandardSubtitle1 = 'standard_subtitle1';
  static const String idStandardSubtitle2 = 'standard_subtitle2';

  /// Visual template keys for Step 1 (image-only picker); map to PNG assets.
  static const String visualLayout1 = 'layout_1';
  static const String visualLayout2 = 'layout_2';
  static const String visualLayout3 = 'layout_3';

  static const String assetVisualLayout1 = 'assets/images/table_display_1.png';
  static const String assetVisualLayout2 = 'assets/images/table_display_2.png';
  static const String assetVisualLayout3 = 'assets/images/table_display_4.png';

  /// On-screen order: option 1 → [visualLayout1], etc. (see [designForVisualLayoutKey]).
  static const List<String> visualLayoutKeysOrdered = <String>[
    visualLayout1,
    visualLayout2,
    visualLayout3,
  ];

  static const Map<String, String> visualLayoutAssetByKey = <String, String>{
    visualLayout1: assetVisualLayout1,
    visualLayout2: assetVisualLayout2,
    visualLayout3: assetVisualLayout3,
  };

  /// Preview card shape as **width ÷ height** for [AspectRatio]. Lower ⇒ taller card.
  static const Map<String, double> visualLayoutCardAspectRatioByKey =
      <String, double>{
        visualLayout1: 1.50,
        visualLayout2: 1.20,
        visualLayout3: 1.50,
      };

  /// Maps picker keys to persisted [TableListDesignLayout] (assets: 1=contact, 2=product, 4=standard).
  static TableListDesignLayout designForVisualLayoutKey(String key) {
    return switch (key) {
      visualLayout1 => TableListDesignLayout.contact,
      visualLayout2 => TableListDesignLayout.product,
      visualLayout3 => TableListDesignLayout.standard,
      _ => TableListDesignLayout.standard,
    };
  }

  static String visualLayoutKeyForDesign(TableListDesignLayout layout) {
    return switch (layout) {
      TableListDesignLayout.standard => visualLayout3,
      TableListDesignLayout.product => visualLayout2,
      TableListDesignLayout.contact => visualLayout1,
    };
  }

  final TextEditingController tableNameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final RxnString selectedPageId = RxnString();
  final Rx<TableMode> mode = TableMode.crud.obs;
  final RxBool searchEnabled = false.obs;
  final Rx<TableDataLoadingMode> dataLoadingMode =
      TableDataLoadingMode.lazy.obs;
  final RxInt pageSize = 10.obs;
  final RxInt lazyInitialLoad = 5.obs;
  final Rx<TableKind> tableKind = TableKind.standard.obs;

  /// Summary table: source dataset and aggregation (IDs reference [existingTableSchemas]).
  final RxnString summarySourceTableId = RxnString();
  final RxnString summaryGroupByColumnId = RxnString();
  final RxnString summaryAggregateColumnId = RxnString();
  final RxList<SummaryColumnDraft> summaryColumns = <SummaryColumnDraft>[].obs;
  final RxList<TableValidationRuleDraft> validationRules =
      <TableValidationRuleDraft>[].obs;

  final RxInt currentStep = 0.obs;
  final Rxn<TableListDesignLayout> selectedDesign =
      Rxn<TableListDesignLayout>();

  /// Selected template key (`layout_1` … `layout_3`); see [visualLayoutKeysOrdered] for on-screen order.
  final RxnString selectedVisualLayoutKey = RxnString();
  final RxBool swipeToDelete = false.obs;
  final Rx<ProductDisplayMode> productDisplayMode = ProductDisplayMode.grid.obs;
  final RxList<ColumnDraft> columns = <ColumnDraft>[].obs;

  /// At most one column [ExpansionTile] expanded at a time; set when adding a column.
  final RxnString expandedColumnId = RxnString();
  final RxList<ReadOnlyRowDraft> readOnlyRows = <ReadOnlyRowDraft>[].obs;
  final Rx<ReadOnlyRowPopulationMode> readOnlyPopulationMode =
      ReadOnlyRowPopulationMode.manual.obs;
  final ReadOnlyPopulateMappingDraft readOnlyPopulateMapping =
      ReadOnlyPopulateMappingDraft();
  final RxList<Map<String, dynamic>> readOnlyGeneratedPreview =
      <Map<String, dynamic>>[].obs;
  final RxList<AffectingTableDraft> affectingTables =
      <AffectingTableDraft>[].obs;
  final RxMap<String, String> affectingFormulaErrors = <String, String>{}.obs;
  final RxBool isSaving = false.obs;
  final RxBool isLoadingPages = true.obs;
  final RxList<PageOption> pageOptions = <PageOption>[].obs;

  /// Inline validation messages under formula fields (column draft id → message).
  final RxMap<String, String> formulaFieldErrors = <String, String>{}.obs;

  /// Inline errors under dropdown configuration (column draft id → message).
  final RxMap<String, String> dropdownFieldErrors = <String, String>{}.obs;

  /// Guided builder field errors: `'$columnId|$fieldKey' → message`.
  final RxMap<String, String> formulaBuilderFieldErrors =
      <String, String>{}.obs;
  final RxInt formulaErrorsVersion = 0.obs;
  final RxInt formulaPreviewVersion = 0.obs;
  final RxList<TableSchemaEntity> existingTableSchemas =
      <TableSchemaEntity>[].obs;
  List<TableSchemaEntity> _existingSchemasCache = <TableSchemaEntity>[];
  final Uuid _uuid = const Uuid();

  static bool isContactFixedId(String id) =>
      id == idContactAvatar ||
      id == idContactName ||
      id == idContactSubtitle1 ||
      id == idContactSubtitle2;

  static bool isProductCoreId(String id) =>
      id == idProductImage || id == idProductName || id == idProductPrice;

  static bool isStandardCoreId(String id) =>
      id == idStandardAvatar ||
      id == idStandardName ||
      id == idStandardSubtitle1 ||
      id == idStandardSubtitle2;

  @override
  void onInit() {
    super.onInit();
    _loadPages();
    _loadExistingSchemas();
  }

  @override
  void onClose() {
    tableNameController.dispose();
    descriptionController.dispose();
    for (final ColumnDraft col in columns) {
      col.dispose();
    }
    for (final ReadOnlyRowDraft row in readOnlyRows) {
      row.dispose();
    }
    _disposeSummaryColumns();
    readOnlyPopulateMapping.dispose();
    clearAffectingTables();
    for (final TableValidationRuleDraft rule in validationRules) {
      rule.dispose();
    }
    validationRules.clear();
    super.onClose();
  }

  Future<void> _loadPages() async {
    isLoadingPages.value = true;
    try {
      final pages = await _getPages();
      final opts = pages
          .where((p) => !p.isDeleted && !p.isDrawerParentContainer)
          .map((p) => PageOption(id: p.id, name: p.name))
          .toList(growable: false);
      pageOptions.assignAll(opts);
    } finally {
      isLoadingPages.value = false;
    }
  }

  Future<void> _loadExistingSchemas() async {
    try {
      final List<TableSchemaEntity> list = await _getAllSchemas();
      existingTableSchemas.assignAll(list);
      _existingSchemasCache = list;
    } catch (_) {
      existingTableSchemas.clear();
      _existingSchemasCache = <TableSchemaEntity>[];
    }
  }

  void setMode(TableMode value) {
    mode.value = TableMode.crud;
  }

  void setTableKind(TableKind value) {
    if (tableKind.value == value) {
      return;
    }
    _clearFormulaFieldErrors();
    tableKind.value = value;
    if (value == TableKind.summary) {
      mode.value = TableMode.crud;
      swipeToDelete.value = false;
      _disposeAllColumns();
      selectedDesign.value = TableListDesignLayout.standard;
      selectedVisualLayoutKey.value = visualLayoutKeyForDesign(
        TableListDesignLayout.standard,
      );
      summarySourceTableId.value = null;
      summaryGroupByColumnId.value = null;
      summaryAggregateColumnId.value = null;
      _resetSummaryColumns();
      searchEnabled.value = false;
      dataLoadingMode.value = TableDataLoadingMode.lazy;
      pageSize.value = 10;
      lazyInitialLoad.value = 5;
      clearValidationRules();
    } else {
      summarySourceTableId.value = null;
      summaryGroupByColumnId.value = null;
      summaryAggregateColumnId.value = null;
      _disposeSummaryColumns();
      selectedDesign.value = null;
      selectedVisualLayoutKey.value = null;
      _disposeAllColumns();
    }
    readOnlyPopulationMode.value = ReadOnlyRowPopulationMode.manual;
    readOnlyGeneratedPreview.clear();
    if (value != TableKind.standard) {
      clearAffectingTables();
    }
  }

  void setSearchEnabled(bool value) => searchEnabled.value = value;

  void setDataLoadingMode(TableDataLoadingMode value) {
    dataLoadingMode.value = value;
    if (value == TableDataLoadingMode.lazy) {
      lazyInitialLoad.value =
          lazyInitialLoad.value < 1 ? 5 : lazyInitialLoad.value;
      return;
    }
    pageSize.value = pageSize.value < 1 ? 10 : pageSize.value;
  }

  void setPageSize(int value) => pageSize.value = value.clamp(1, 200);

  void setLazyInitialLoad(int value) =>
      lazyInitialLoad.value = value.clamp(1, 200);

  List<TableSchemaEntity> get affectingTargetTableOptions {
    return existingTableSchemas
        .where(
          (TableSchemaEntity schema) => schema.tableKind == TableKind.standard,
        )
        .toList(growable: false);
  }

  void addAffectingTableRule() {
    affectingTables.add(
      AffectingTableDraft(
        id: _uuid.v4(),
        rules: <AffectingColumnRuleDraft>[
          AffectingColumnRuleDraft(id: _uuid.v4()),
        ],
      ),
    );
  }

  void removeAffectingTableRule(String id) {
    final int index = affectingTables.indexWhere(
      (AffectingTableDraft rule) => rule.id == id,
    );
    if (index < 0) {
      return;
    }
    final AffectingTableDraft removed = affectingTables.removeAt(index);
    removed.dispose();
    affectingFormulaErrors.removeWhere(
      (String key, String value) => key.startsWith('${removed.id}|'),
    );
    affectingFormulaErrors.refresh();
  }

  void addAffectingColumnRule(String affectingId) {
    final int index = affectingTables.indexWhere(
      (AffectingTableDraft rule) => rule.id == affectingId,
    );
    if (index < 0) {
      return;
    }
    affectingTables[index].rules.add(AffectingColumnRuleDraft(id: _uuid.v4()));
    affectingTables.refresh();
  }

  void removeAffectingColumnRule(String affectingId, String ruleId) {
    final int index = affectingTables.indexWhere(
      (AffectingTableDraft rule) => rule.id == affectingId,
    );
    if (index < 0) {
      return;
    }
    final AffectingTableDraft target = affectingTables[index];
    if (target.rules.length <= 1) {
      return;
    }
    final int ruleIndex = target.rules.indexWhere(
      (AffectingColumnRuleDraft rule) => rule.id == ruleId,
    );
    if (ruleIndex < 0) {
      return;
    }
    final AffectingColumnRuleDraft removed = target.rules.removeAt(ruleIndex);
    removed.dispose();
    affectingFormulaErrors.remove('$affectingId|$ruleId');
    affectingFormulaErrors.refresh();
    affectingTables.refresh();
  }

  void clearAffectingTables() {
    for (final AffectingTableDraft item in affectingTables) {
      item.dispose();
    }
    affectingTables.clear();
    affectingFormulaErrors.clear();
    affectingFormulaErrors.refresh();
  }

  void addValidationRule() {
    validationRules.add(
      TableValidationRuleDraft(
        id: _uuid.v4(),
        nameController: TextEditingController(
          text: 'Validation ${validationRules.length + 1}',
        ),
      ),
    );
  }

  void removeValidationRule(String id) {
    final int index = validationRules.indexWhere(
      (TableValidationRuleDraft draft) => draft.id == id,
    );
    if (index < 0) {
      return;
    }
    final TableValidationRuleDraft removed = validationRules.removeAt(index);
    removed.dispose();
  }

  void clearValidationRules() {
    for (final TableValidationRuleDraft rule in validationRules) {
      rule.dispose();
    }
    validationRules.clear();
  }

  List<TableSchemaEntity> get summarySourceTableOptions {
    return existingTableSchemas
        .where((TableSchemaEntity s) => s.tableKind != TableKind.summary)
        .toList(growable: false);
  }

  TableSchemaEntity? summarySourceSchema(String? id) {
    if (id == null || id.isEmpty) {
      return null;
    }
    for (final TableSchemaEntity s in existingTableSchemas) {
      if (s.id == id) {
        return s;
      }
    }
    for (final TableSchemaEntity s in _existingSchemasCache) {
      if (s.id == id) {
        return s;
      }
    }
    return null;
  }

  List<TableColumnEntity> summaryGroupByCandidates(TableSchemaEntity? source) {
    if (source == null) {
      return const <TableColumnEntity>[];
    }
    return source.columns
        .where(
          (TableColumnEntity c) =>
              c.type != TableColumnType.image && c.type != TableColumnType.file,
        )
        .toList(growable: false);
  }

  List<TableColumnEntity> summaryAggregateCandidates(
    TableSchemaEntity? source,
  ) {
    if (source == null) {
      return const <TableColumnEntity>[];
    }
    return source.columns
        .where(
          (TableColumnEntity c) =>
              c.type == TableColumnType.number,
        )
        .toList(growable: false);
  }

  void onSummarySourceTableChanged(String? id) {
    summarySourceTableId.value = id;
    summaryGroupByColumnId.value = null;
    summaryAggregateColumnId.value = null;
  }

  void _disposeSummaryColumns() {
    for (final SummaryColumnDraft draft in summaryColumns) {
      draft.dispose();
    }
    summaryColumns.clear();
  }

  void _resetSummaryColumns() {
    _disposeSummaryColumns();
    addSummaryColumn();
  }

  void addSummaryColumn() {
    summaryColumns.add(
      SummaryColumnDraft(
        id: _uuid.v4(),
        nameController: TextEditingController(
          text: 'Column ${summaryColumns.length + 1}',
        ),
      ),
    );
  }

  void removeSummaryColumn(String id) {
    if (summaryColumns.length <= 1) {
      return;
    }
    final int index = summaryColumns.indexWhere(
      (SummaryColumnDraft c) => c.id == id,
    );
    if (index < 0) {
      return;
    }
    final SummaryColumnDraft removed = summaryColumns.removeAt(index);
    removed.dispose();
  }

  void moveSummaryColumn(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= summaryColumns.length) {
      return;
    }
    int targetIndex = newIndex;
    if (targetIndex < 0) {
      targetIndex = 0;
    }
    if (targetIndex >= summaryColumns.length) {
      targetIndex = summaryColumns.length - 1;
    }
    if (oldIndex < targetIndex) {
      targetIndex -= 1;
    }
    final SummaryColumnDraft item = summaryColumns.removeAt(oldIndex);
    summaryColumns.insert(targetIndex, item);
  }

  List<TableColumnEntity> summarySourceColumns(String? sourceTableId) {
    final TableSchemaEntity? src = summarySourceSchema(sourceTableId);
    return src?.columns ?? const <TableColumnEntity>[];
  }

  void pickDesign(TableListDesignLayout layout) {
    final TableListDesignLayout? previous = selectedDesign.value;
    selectedVisualLayoutKey.value = visualLayoutKeyForDesign(layout);
    selectedDesign.value = layout;
    if (previous != layout) {
      _clearFormulaFieldErrors();
      _seedColumnsForDesign(layout);
    }
  }

  void pickVisualLayout(String layoutKey) {
    pickDesign(designForVisualLayoutKey(layoutKey));
    if (layoutKey == visualLayout2) {
      productDisplayMode.value = ProductDisplayMode.grid;
    }
  }

  void setSwipeToDelete(bool value) => swipeToDelete.value = value;

  void setProductDisplayMode(ProductDisplayMode value) =>
      productDisplayMode.value = value;

  void _disposeAllColumns() {
    for (final ColumnDraft col in columns) {
      col.dispose();
    }
    columns.clear();
    _syncReadOnlyRowsWithColumns();
  }

  void _clearFormulaFieldErrors() {
    formulaFieldErrors.clear();
    formulaBuilderFieldErrors.clear();
    formulaFieldErrors.refresh();
    formulaBuilderFieldErrors.refresh();
    formulaErrorsVersion.value++;
  }

  void onGuidedFormulaInteraction(String columnId) {
    formulaBuilderFieldErrors.removeWhere(
      (String k, String v) => k.startsWith('$columnId|'),
    );
    formulaFieldErrors.remove(columnId);
    if (columnId.startsWith('readonly:') || columnId.startsWith('map:')) {
      _applyLiveReadOnlyFormulaValidation(columnId);
    } else {
      _applyLiveFormulaValidationForColumn(columnId);
    }
    formulaBuilderFieldErrors.refresh();
    formulaFieldErrors.refresh();
    formulaPreviewVersion.value++;
    formulaErrorsVersion.value++;
  }

  /// Reacts to edits in the formula text editor (autocomplete or typing).
  void onFormulaTextEditorInteraction(String columnId) {
    formulaBuilderFieldErrors.removeWhere(
      (String k, String v) => k.startsWith('$columnId|'),
    );
    if (columnId.startsWith('readonly:') || columnId.startsWith('map:')) {
      _applyLiveReadOnlyFormulaValidation(columnId);
    } else {
      _applyLiveFormulaValidationForColumn(columnId);
    }
    formulaFieldErrors.refresh();
    formulaBuilderFieldErrors.refresh();
    formulaPreviewVersion.value++;
    formulaErrorsVersion.value++;
  }

  /// Reacts to switching between guided builder and text editor.
  void onFormulaInputModeChanged(String columnId) {
    if (columnId.startsWith('readonly:') || columnId.startsWith('map:')) {
      _applyLiveReadOnlyFormulaValidation(columnId);
    } else {
      _applyLiveFormulaValidationForColumn(columnId);
    }
    formulaFieldErrors.refresh();
    formulaBuilderFieldErrors.refresh();
    formulaPreviewVersion.value++;
    formulaErrorsVersion.value++;
  }

  String? _readOnlyFormulaCurrentColumnId(String cellKey) {
    if (cellKey.startsWith('map:')) {
      return cellKey.substring(4);
    }
    if (cellKey.startsWith('readonly:')) {
      final String rest = cellKey.substring('readonly:'.length);
      final int sep = rest.indexOf(':');
      if (sep < 0) {
        return null;
      }
      return rest.substring(sep + 1);
    }
    return null;
  }

  ReadOnlyCellDraft? _readOnlyCellByFormulaKey(String key) {
    if (key.startsWith('map:')) {
      return readOnlyPopulateMapping.cells[key.substring(4)];
    }
    if (!key.startsWith('readonly:')) {
      return null;
    }
    final String rest = key.substring('readonly:'.length);
    final int sep = rest.indexOf(':');
    if (sep < 0) {
      return null;
    }
    final String rowId = rest.substring(0, sep);
    final String colId = rest.substring(sep + 1);
    for (final ReadOnlyRowDraft r in readOnlyRows) {
      if (r.id == rowId) {
        return r.cells[colId];
      }
    }
    return null;
  }

  /// Composed expression for a read-only cell (text editor, guided, or legacy string).
  String? _readOnlyComposedFormula(
    ReadOnlyCellDraft cell,
    String forColumnId,
    List<TableSchemaEntity> allSchemas,
  ) {
    if (cell.source.value != ReadOnlyValueSource.formula) {
      return null;
    }
    if (cell.formulaInputMode.value == FormulaInputMode.textEditor) {
      return cell.formulaTextController.text.trim();
    }
    if (cell.guided.guidedFormulaKind.value != null) {
      return cell.guided
          .composeGuidedFormula(
            allSchemas,
            siblingColumnsExcluding(forColumnId),
            forColumnId,
            allColumnsAsNameDrafts(),
          )
          ?.trim();
    }
    return cell.formulaController.text.trim();
  }

  void _applyLiveReadOnlyFormulaValidation(String cellKey) {
    final ReadOnlyCellDraft? cell = _readOnlyCellByFormulaKey(cellKey);
    final String? currentColumnId = _readOnlyFormulaCurrentColumnId(cellKey);
    if (cell == null || currentColumnId == null) {
      return;
    }
    if (cell.source.value != ReadOnlyValueSource.formula) {
      return;
    }
    final List<TableSchemaEntity> schemas =
        existingTableSchemas.isNotEmpty
            ? existingTableSchemas.toList(growable: false)
            : _existingSchemasCache;
    final List<ColumnNameDraft> names = allColumnsAsNameDrafts();
    if (cell.formulaInputMode.value == FormulaInputMode.textEditor) {
      formulaBuilderFieldErrors.removeWhere(
        (String k, String v) => k.startsWith('$cellKey|'),
      );
      final String t = cell.formulaTextController.text.trim();
      if (t.isEmpty) {
        formulaFieldErrors[cellKey] = TableFormulaValidator.errRequired;
        return;
      }
      final String? msg = TableFormulaValidator.validate(
        formula: t,
        currentColumnId: currentColumnId,
        siblingColumns: names,
        existingTables: schemas,
      );
      if (msg != null) {
        formulaFieldErrors[cellKey] = msg;
      } else {
        formulaFieldErrors.remove(cellKey);
      }
      return;
    }
    if (cell.guided.guidedFormulaKind.value == null) {
      formulaFieldErrors.remove(cellKey);
      return;
    }
    final Map<String, String> guidedErrors = cell.guided.validateGuided(
      schemas,
      siblingColumnsExcluding(currentColumnId),
      currentColumnId,
      formulaColumnNames: names,
    );
    for (final MapEntry<String, String> e in guidedErrors.entries) {
      formulaBuilderFieldErrors['$cellKey|${e.key}'] = e.value;
    }
    if (guidedErrors.isEmpty) {
      final String? composed = cell.guided.composeGuidedFormula(
        schemas,
        siblingColumnsExcluding(currentColumnId),
        currentColumnId,
        names,
      );
      if (composed == null || composed.isEmpty) {
        formulaFieldErrors[cellKey] = TableFormulaValidator.errRequired;
      } else {
        final String? msg = TableFormulaValidator.validate(
          formula: composed,
          currentColumnId: currentColumnId,
          siblingColumns: names,
          existingTables: schemas,
        );
        if (msg != null) {
          formulaFieldErrors[cellKey] = msg;
        } else {
          formulaFieldErrors.remove(cellKey);
        }
      }
    } else {
      formulaFieldErrors.remove(cellKey);
    }
  }

  void _applyLiveFormulaValidationForColumn(String columnId) {
    final int ix = columns.indexWhere((ColumnDraft c) => c.id == columnId);
    if (ix < 0) {
      return;
    }
    final ColumnDraft col = columns[ix];
    if (_resolvedTypeForDraft(col) != TableColumnType.formula) {
      return;
    }
    final List<TableSchemaEntity> schemas =
        existingTableSchemas.isNotEmpty
            ? existingTableSchemas.toList(growable: false)
            : _existingSchemasCache;
    final List<ColumnDraft> snapshot = columns.toList(growable: false);
    final List<ColumnNameDraft> names = allColumnsAsNameDrafts();
    if (col.formulaInputMode.value == FormulaInputMode.textEditor) {
      formulaBuilderFieldErrors.removeWhere(
        (String k, String v) => k.startsWith('$columnId|'),
      );
      final String t = col.formulaTextController.text.trim();
      if (t.isEmpty) {
        formulaFieldErrors[columnId] = TableFormulaValidator.errRequired;
      } else {
        final String? msg = TableFormulaValidator.validate(
          formula: t,
          currentColumnId: columnId,
          siblingColumns: names,
          existingTables: schemas,
        );
        if (msg != null) {
          formulaFieldErrors[columnId] = msg;
        } else {
          formulaFieldErrors.remove(columnId);
        }
      }
      return;
    }
    if (col.guided.guidedFormulaKind.value == null) {
      formulaFieldErrors.remove(columnId);
      return;
    }
    final Map<String, String> guidedErrors = col.validateGuided(
      schemas,
      snapshot,
      names,
    );
    for (final MapEntry<String, String> e in guidedErrors.entries) {
      formulaBuilderFieldErrors['$columnId|${e.key}'] = e.value;
    }
    if (guidedErrors.isEmpty) {
      final String? composed = col.composeGuidedFormula(
        schemas,
        snapshot,
        names,
      );
      if (composed == null || composed.isEmpty) {
        formulaFieldErrors[columnId] = TableFormulaValidator.errRequired;
      } else {
        final String? msg = TableFormulaValidator.validate(
          formula: composed,
          currentColumnId: columnId,
          siblingColumns: names,
          existingTables: schemas,
        );
        if (msg != null) {
          formulaFieldErrors[columnId] = msg;
        } else {
          formulaFieldErrors.remove(columnId);
        }
      }
    } else {
      formulaFieldErrors.remove(columnId);
    }
  }

  void onColumnDataTypeChanged(
    String columnId,
    TableColumnType? previous,
    TableColumnType next,
  ) {
    formulaFieldErrors.remove(columnId);
    formulaBuilderFieldErrors.removeWhere(
      (String k, String v) => k.startsWith('$columnId|'),
    );
    formulaFieldErrors.refresh();
    formulaBuilderFieldErrors.refresh();
    formulaPreviewVersion.value++;
    formulaErrorsVersion.value++;
    final int ix = columns.indexWhere((ColumnDraft c) => c.id == columnId);
    if (ix < 0) {
      return;
    }
    if (previous != next &&
        (previous == TableColumnType.formula ||
            next == TableColumnType.formula)) {
      columns[ix].clearGuidedFormulaBuilder();
      columns[ix].formulaTextController.clear();
      columns[ix].formulaInputMode.value = FormulaInputMode.guided;
    }
    if (next == TableColumnType.formula) {
      columns[ix].formulaInputMode.value = FormulaInputMode.guided;
    }
    if (next != TableColumnType.dropdown) {
      columns[ix].resetDropdownConfiguration();
    }
    if (previous == TableColumnType.text && next != TableColumnType.text) {
      columns[ix].resetTextFieldConfiguration();
    }
    if (previous == TableColumnType.number && next != TableColumnType.number) {
      columns[ix].resetNumberFieldConfiguration();
    }
    dropdownFieldErrors.remove(columnId);
    dropdownFieldErrors.refresh();
  }

  String? formulaBuilderFieldError(String columnId, String fieldKey) {
    return formulaBuilderFieldErrors['$columnId|$fieldKey'];
  }

  /// Image + display name + two subtitle lines (contact list row shape).
  List<ColumnDraft> _imageNameTwoSubtitlesStarterDrafts({
    required String avatarId,
    required String nameId,
    required String subtitle1Id,
    required String subtitle2Id,
  }) {
    return <ColumnDraft>[
      ColumnDraft(
        avatarId,
        initialName: 'Image',
        initialType: TableColumnType.image,
      ),
      ColumnDraft(
        nameId,
        initialName: 'Name',
        initialType: TableColumnType.text,
      ),
      ColumnDraft(
        subtitle1Id,
        initialName: 'Subtitle 1',
        initialType: TableColumnType.text,
      ),
      ColumnDraft(
        subtitle2Id,
        initialName: 'Subtitle 2',
        initialType: TableColumnType.text,
      ),
    ];
  }

  void _seedColumnsForDesign(TableListDesignLayout layout) {
    _disposeAllColumns();
    switch (layout) {
      case TableListDesignLayout.contact:
        columns.addAll(
          _imageNameTwoSubtitlesStarterDrafts(
            avatarId: idContactAvatar,
            nameId: idContactName,
            subtitle1Id: idContactSubtitle1,
            subtitle2Id: idContactSubtitle2,
          ),
        );
        break;
      case TableListDesignLayout.standard:
        // Simple table (option 3): no preset columns — user adds via Add Column.
        break;
      case TableListDesignLayout.product:
        columns.addAll(<ColumnDraft>[
          ColumnDraft(
            idProductImage,
            initialName: 'Image',
            initialType: TableColumnType.image,
          ),
          ColumnDraft(
            idProductName,
            initialName: 'Product Name',
            initialType: TableColumnType.text,
          ),
          ColumnDraft(
            idProductPrice,
            initialName: 'Price',
            initialType: TableColumnType.number,
          ),
        ]);
        break;
    }
  }

  bool get showAddColumnButton {
    final TableListDesignLayout? d = selectedDesign.value;
    return d == TableListDesignLayout.standard ||
        d == TableListDesignLayout.product;
  }

  bool canRemoveColumn(ColumnDraft column) {
    final TableListDesignLayout? d = selectedDesign.value;
    if (d == TableListDesignLayout.contact) {
      return false;
    }
    if (d == TableListDesignLayout.standard && isStandardCoreId(column.id)) {
      return false;
    }
    if (d == TableListDesignLayout.product) {
      if (isProductCoreId(column.id)) {
        return false;
      }
      return true;
    }
    return columns.length > 1;
  }

  bool canEditColumnType(ColumnDraft column) {
    final TableListDesignLayout? d = selectedDesign.value;
    if (d == TableListDesignLayout.contact) {
      return false;
    }
    if (d == TableListDesignLayout.standard && column.id == idStandardAvatar) {
      return false;
    }
    if (d == TableListDesignLayout.product && isProductCoreId(column.id)) {
      return false;
    }
    return true;
  }

  void addColumn() {
    final ColumnDraft draft = ColumnDraft(_uuid.v4());
    columns.add(draft);
    expandedColumnId.value = draft.id;
    _syncReadOnlyRowsWithColumns();
  }

  void reorderColumns(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= columns.length ||
        newIndex < 0 ||
        newIndex >= columns.length) {
      return;
    }
    final ColumnDraft moved = columns.removeAt(oldIndex);
    columns.insert(newIndex, moved);
    _syncReadOnlyRowsWithColumns();
  }

  void removeColumn(String id) {
    final int index = columns.indexWhere((c) => c.id == id);
    if (index < 0) {
      return;
    }
    final ColumnDraft target = columns[index];
    if (!canRemoveColumn(target)) {
      showAppSnackbar('Validation', 'This column cannot be removed');
      return;
    }
    final ColumnDraft removed = columns.removeAt(index);
    if (expandedColumnId.value == removed.id) {
      expandedColumnId.value = null;
    }
    formulaFieldErrors.remove(removed.id);
    dropdownFieldErrors.remove(removed.id);
    formulaBuilderFieldErrors.removeWhere(
      (String k, String v) => k.startsWith('${removed.id}|'),
    );
    formulaFieldErrors.refresh();
    dropdownFieldErrors.refresh();
    formulaBuilderFieldErrors.refresh();
    formulaErrorsVersion.value++;
    removed.dispose();
    _syncReadOnlyRowsWithColumns();
  }

  bool get isCrudStandardTable =>
      tableKind.value == TableKind.standard && mode.value == TableMode.crud;

  int get lastStepIndex {
    if (tableKind.value == TableKind.summary) {
      return 4;
    }
    // Standard tables include Validation Rules before Review.
    return isCrudStandardTable ? 6 : 5;
  }

  void addReadOnlyRow() {
    final ReadOnlyRowDraft row = ReadOnlyRowDraft(id: _uuid.v4());
    for (final ColumnDraft column in columns) {
      row.cells[column.id] = ReadOnlyCellDraft();
    }
    readOnlyRows.add(row);
  }

  void removeReadOnlyRow(String rowId) {
    final int index = readOnlyRows.indexWhere(
      (ReadOnlyRowDraft r) => r.id == rowId,
    );
    if (index < 0) {
      return;
    }
    final ReadOnlyRowDraft removed = readOnlyRows.removeAt(index);
    removed.dispose();
  }

  void _syncReadOnlyRowsWithColumns() {
    final Set<String> colIds = columns.map((ColumnDraft c) => c.id).toSet();
    for (final ReadOnlyRowDraft row in readOnlyRows) {
      final List<String> stale = row.cells.keys
          .where((String id) => !colIds.contains(id))
          .toList(growable: false);
      for (final String id in stale) {
        row.cells.remove(id)?.dispose();
      }
      for (final ColumnDraft c in columns) {
        row.cells.putIfAbsent(c.id, () => ReadOnlyCellDraft());
      }
    }
    final List<String> staleMapKeys = readOnlyPopulateMapping.cells.keys
        .where((String id) => !colIds.contains(id))
        .toList(growable: false);
    for (final String id in staleMapKeys) {
      readOnlyPopulateMapping.cells.remove(id)?.dispose();
    }
    for (final ColumnDraft c in columns) {
      readOnlyPopulateMapping.cells.putIfAbsent(
        c.id,
        () => ReadOnlyCellDraft(),
      );
    }
  }

  void setReadOnlyPopulationMode(ReadOnlyRowPopulationMode mode) {
    readOnlyPopulationMode.value = mode;
    if (mode == ReadOnlyRowPopulationMode.manual) {
      readOnlyGeneratedPreview.clear();
    }
  }

  Future<void> regenerateReadOnlyPreview() async {
    readOnlyGeneratedPreview.assignAll(await _buildReadOnlyGeneratedRows());
  }

  String? _validateReadOnlyRows() {
    if (tableKind.value != TableKind.standard || mode.value != TableMode.crud) {
      return null;
    }
    if (readOnlyPopulationMode.value == ReadOnlyRowPopulationMode.sourceMap) {
      if (readOnlyPopulateMapping.uniqueKeyTableId.value == null ||
          readOnlyPopulateMapping.uniqueKeyColumnId.value == null) {
        return 'Select unique source table and unique key column.';
      }
      for (final ColumnDraft column in columns) {
        final ReadOnlyCellDraft? cell =
            readOnlyPopulateMapping.cells[column.id];
        if (cell == null) {
          return 'Mapping is incomplete.';
        }
        if (cell.source.value == ReadOnlyValueSource.manual &&
            cell.manualController.text.trim().isEmpty) {
          return 'Manual mapping value is required.';
        }
        if (cell.source.value == ReadOnlyValueSource.formula) {
          if (cell.formulaInputMode.value == FormulaInputMode.textEditor) {
            if (cell.formulaTextController.text.trim().isEmpty) {
              return 'Formula mapping is required.';
            }
          } else if (cell.guided.guidedFormulaKind.value == null &&
              cell.formulaController.text.trim().isEmpty) {
            return 'Formula mapping is required.';
          }
        }
        if (cell.source.value == ReadOnlyValueSource.auto &&
            (cell.sourceTableId.value == null ||
                cell.sourceColumnId.value == null)) {
          return 'Lookup mapping requires source table and source column.';
        }
      }
      return null;
    }
    if (readOnlyRows.isEmpty) {
      return 'Add at least one row for read-only table.';
    }
    for (final ReadOnlyRowDraft row in readOnlyRows) {
      for (final ColumnDraft column in columns) {
        final ReadOnlyCellDraft? cell = row.cells[column.id];
        if (cell == null) {
          return 'Row configuration is incomplete.';
        }
        switch (cell.source.value) {
          case ReadOnlyValueSource.manual:
            if (cell.manualController.text.trim().isEmpty) {
              return 'Manual value is required for ${column.nameController.text.trim().isEmpty ? 'a column' : column.nameController.text.trim()}.';
            }
            break;
          case ReadOnlyValueSource.formula:
            final String formulaKey = 'readonly:${row.id}:${column.id}';
            formulaFieldErrors.remove(formulaKey);
            formulaBuilderFieldErrors.removeWhere(
              (String k, String _) => k.startsWith('$formulaKey|'),
            );
            if (cell.formulaInputMode.value == FormulaInputMode.textEditor) {
              final String t = cell.formulaTextController.text.trim();
              if (t.isEmpty) {
                return 'Formula is required for ${column.nameController.text.trim().isEmpty ? 'a column' : column.nameController.text.trim()}.';
              }
              final String? textErr = TableFormulaValidator.validate(
                formula: t,
                currentColumnId: column.id,
                siblingColumns: allColumnsAsNameDrafts(),
                existingTables: _existingSchemasCache,
              );
              if (textErr != null) {
                return textErr;
              }
              break;
            }
            if (cell.guided.guidedFormulaKind.value == null) {
              if (cell.formulaController.text.trim().isEmpty) {
                return 'Formula is required for ${column.nameController.text.trim().isEmpty ? 'a column' : column.nameController.text.trim()}.';
              }
              final String? textFormulaError = TableFormulaValidator.validate(
                formula: cell.formulaController.text.trim(),
                currentColumnId: column.id,
                siblingColumns: allColumnsAsNameDrafts(),
                existingTables: _existingSchemasCache,
              );
              if (textFormulaError != null) {
                return textFormulaError;
              }
              break;
            }
            final Map<String, String> guidedErrors = cell.guided.validateGuided(
              _existingSchemasCache,
              siblingColumnsExcluding(column.id),
              column.id,
              formulaColumnNames: allColumnsAsNameDrafts(),
            );
            for (final MapEntry<String, String> e in guidedErrors.entries) {
              formulaBuilderFieldErrors['$formulaKey|${e.key}'] = e.value;
            }
            final String? composed = cell.guided.composeGuidedFormula(
              _existingSchemasCache,
              siblingColumnsExcluding(column.id),
              column.id,
              allColumnsAsNameDrafts(),
            );
            if (guidedErrors.isNotEmpty ||
                composed == null ||
                composed.isEmpty) {
              return 'Formula is required for ${column.nameController.text.trim().isEmpty ? 'a column' : column.nameController.text.trim()}.';
            }
            final String? composedError = TableFormulaValidator.validate(
              formula: composed,
              currentColumnId: column.id,
              siblingColumns: allColumnsAsNameDrafts(),
              existingTables: _existingSchemasCache,
            );
            if (composedError != null) {
              formulaFieldErrors[formulaKey] = composedError;
              return composedError;
            }
            break;
          case ReadOnlyValueSource.auto:
            if (cell.sourceTableId.value == null ||
                cell.sourceColumnId.value == null) {
              return 'Auto source table and column are required.';
            }
            break;
        }
      }
    }
    return null;
  }

  String? _validateColumns() {
    dropdownFieldErrors.clear();
    dropdownFieldErrors.refresh();
    if (columns.isEmpty) {
      return 'At least one column is required';
    }
    for (final ColumnDraft col in columns) {
      if (col.nameController.text.trim().isEmpty) {
        return 'Every column needs a name';
      }
    }
    for (final ColumnDraft col in columns) {
      if (canEditColumnType(col) && _resolvedTypeForDraft(col) == null) {
        return 'Select a data type for every column';
      }
    }
    final TableListDesignLayout? d = selectedDesign.value;
    if (d == TableListDesignLayout.contact) {
      if (columns.length != 4) {
        return 'Contact layout requires exactly four columns';
      }
    }
    if (d == TableListDesignLayout.product) {
      if (columns.length < 3) {
        return 'Product layout requires image, name, and price columns';
      }
    }
    for (final ColumnDraft col in columns) {
      if (_resolvedTypeForDraft(col) != TableColumnType.dropdown) {
        continue;
      }
      if (col.dropdownSourceKind.value ==
          TableColumnDropdownSourceKind.manual) {
        final List<String> opts =
            DropdownColumnOptions.manualOptionsFromMultiline(
              col.dropdownOptionsController.text,
            );
        if (opts.isEmpty) {
          dropdownFieldErrors[col.id] = 'At least one option is required.';
        }
      } else {
        final String? tid = col.dropdownSourceTableId.value;
        final String? cid = col.dropdownSourceColumnId.value;
        if (tid == null || tid.isEmpty) {
          dropdownFieldErrors[col.id] = 'Source table is required.';
        } else if (cid == null || cid.isEmpty) {
          dropdownFieldErrors[col.id] = 'Source column is required.';
        }
      }
    }
    dropdownFieldErrors.refresh();
    if (dropdownFieldErrors.isNotEmpty) {
      return dropdownFieldErrors.values.first;
    }
    for (final ColumnDraft col in columns) {
      if (_resolvedTypeForDraft(col) != TableColumnType.text) {
        continue;
      }
      if (col.textValidationKind.value == TableTextValidationKind.custom) {
        final String p = col.textCustomRegexController.text.trim();
        if (p.isEmpty) {
          return 'Enter a regular expression for column "${col.nameController.text}"';
        }
        try {
          RegExp(p);
        } catch (_) {
          return 'Invalid regular expression for column "${col.nameController.text}"';
        }
      }
    }
    return null;
  }

  String? _validateAffectingTables() {
    affectingFormulaErrors.clear();
    affectingFormulaErrors.refresh();
    if (!isCrudStandardTable) {
      return null;
    }
    final List<ColumnNameDraft> sourceColumns = allColumnsAsNameDrafts();
    for (final AffectingTableDraft affecting in affectingTables) {
      final String? targetTableId = affecting.targetTableId.value;
      if (targetTableId == null || targetTableId.isEmpty) {
        return 'Please select an affected table.';
      }
      final TableSchemaEntity? targetTable = summarySourceSchema(targetTableId);
      if (targetTable == null) {
        return 'Affected table is no longer available.';
      }
      if (affecting.matchTargetColumnId.value == null ||
          affecting.matchSourceColumnId.value == null) {
        return 'Please configure row matching.';
      }
      if (affecting.rules.isEmpty) {
        return 'Please add at least one column update rule.';
      }
      for (final AffectingColumnRuleDraft rule in affecting.rules) {
        if (rule.targetColumnId.value == null ||
            rule.targetColumnId.value!.isEmpty) {
          return 'Please select an affected column.';
        }
        final String formula = rule.formulaController.text.trim();
        if (formula.isEmpty) {
          return 'Formula is required.';
        }
        final String? error = TableFormulaValidator.validate(
          formula: formula,
          currentColumnId: '',
          siblingColumns: sourceColumns,
          existingTables:
              existingTableSchemas.isNotEmpty
                  ? existingTableSchemas.toList(growable: false)
                  : _existingSchemasCache,
        );
        if (error != null) {
          affectingFormulaErrors['${affecting.id}|${rule.id}'] = error;
          affectingFormulaErrors.refresh();
          return error;
        }
      }
    }
    return null;
  }

  String? _validateCustomValidationRules() {
    final List<ColumnNameDraft> sourceColumns = allColumnsAsNameDrafts();
    for (final TableValidationRuleDraft rule in validationRules) {
      final String condition = rule.conditionController.text.trim();
      final String errorMessage = rule.errorMessageController.text.trim();
      if (condition.isEmpty) {
        return 'Validation rule condition is required.';
      }
      if (errorMessage.isEmpty) {
        return 'Validation rule error message is required.';
      }
      final String? formulaError = TableFormulaValidator.validate(
        formula: condition,
        currentColumnId: '',
        siblingColumns: sourceColumns,
        existingTables:
            existingTableSchemas.isNotEmpty
                ? existingTableSchemas.toList(growable: false)
                : _existingSchemasCache,
      );
      if (formulaError != null) {
        return formulaError;
      }
    }
    return null;
  }

  String? validateForStep(int step) {
    switch (step) {
      case 0:
        if (tableKind.value == TableKind.summary) {
          if (summarySourceTableOptions.isEmpty) {
            return 'Create a standard table with data before adding a summary table';
          }
          if (summaryColumns.isEmpty) {
            return 'Add at least one summary column';
          }
          bool hasGroupBy = false;
          for (final SummaryColumnDraft column in summaryColumns) {
            if (column.nameController.text.trim().isEmpty) {
              return 'Every summary column needs a name';
            }
            if (column.sourceTableId.value == null ||
                column.sourceColumnId.value == null) {
              return 'Select source table and source column for each summary column';
            }
            if (column.groupBy.value) {
              hasGroupBy = true;
            }
            if (column.valueMode.value == SummaryValueMode.formula &&
                column.formulaController.text.trim().isEmpty) {
              return 'Formula is required for formula summary columns';
            }
          }
          if (!hasGroupBy) {
            return 'Mark at least one summary column as Group By';
          }
          return null;
        }
        if (selectedDesign.value == null) {
          return 'Select a table design layout';
        }
        return null;
      case 1:
        if (tableNameController.text.trim().isEmpty) {
          return 'Table name is required';
        }
        if (selectedPageId.value == null) {
          return 'Assign page is required';
        }
        return null;
      case 2:
        return null;
      case 3:
        if (tableKind.value == TableKind.summary) {
          return null;
        }
        return _validateColumns();
      case 4:
        if (tableKind.value == TableKind.summary) {
          return (tableNameController.text.trim().isEmpty
                  ? 'Table name is required'
                  : null) ??
              (selectedPageId.value == null ? 'Assign page is required' : null);
        }
        return _validateCustomValidationRules();
      case 5:
        if (isCrudStandardTable) {
          return _validateAffectingTables();
        }
        return _validateColumns() ??
            (tableNameController.text.trim().isEmpty
                ? 'Table name is required'
                : null) ??
            (selectedPageId.value == null ? 'Assign page is required' : null) ??
            (selectedDesign.value == null ? 'Select a layout' : null);
      case 6:
        if (tableKind.value == TableKind.summary || isCrudStandardTable) {
          return (tableNameController.text.trim().isEmpty
                  ? 'Table name is required'
                  : null) ??
              (selectedPageId.value == null ? 'Assign page is required' : null);
        }
        return null;
      case 7:
        if (tableKind.value == TableKind.summary) {
          return (tableNameController.text.trim().isEmpty
                  ? 'Table name is required'
                  : null) ??
              (selectedPageId.value == null ? 'Assign page is required' : null);
        }
        return _validateColumns() ??
            (tableNameController.text.trim().isEmpty
                ? 'Table name is required'
                : null) ??
            (selectedPageId.value == null ? 'Assign page is required' : null) ??
            (selectedDesign.value == null ? 'Select a layout' : null);
      default:
        return null;
    }
  }

  List<TableAffectingConfig> _buildAffectingTablesConfig() {
    if (!isCrudStandardTable) {
      return const <TableAffectingConfig>[];
    }
    return affectingTables
        .where((AffectingTableDraft draft) => draft.targetTableId.value != null)
        .map((AffectingTableDraft draft) {
          return TableAffectingConfig(
            targetTableId: draft.targetTableId.value!,
            match: TableRowMatchConfig(
              targetColumnId: draft.matchTargetColumnId.value!,
              sourceColumnId: draft.matchSourceColumnId.value!,
            ),
            rules: draft.rules
                .where(
                  (AffectingColumnRuleDraft rule) =>
                      rule.targetColumnId.value != null,
                )
                .map(
                  (AffectingColumnRuleDraft rule) => TableAffectedColumnRule(
                    targetColumnId: rule.targetColumnId.value!,
                    formula: rule.formulaController.text.trim(),
                  ),
                )
                .toList(growable: false),
          );
        })
        .toList(growable: false);
  }

  Future<void> goNext() async {
    final int step = currentStep.value;
    if (step == 3 && tableKind.value != TableKind.summary) {
      final bool formulasOk = await validateFormulaColumnsInline();
      if (!formulasOk) {
        return;
      }
    }
    final String? error = validateForStep(step);
    if (error != null) {
      showAppSnackbar('Validation', error);
      return;
    }
    if (step >= lastStepIndex) {
      return;
    }
    currentStep.value++;
  }

  void goBack() {
    if (currentStep.value > 0) {
      currentStep.value--;
    } else {
      Get.back<void>();
    }
  }

  TableColumnType? _resolvedTypeForDraft(ColumnDraft c) {
    final TableListDesignLayout? d = selectedDesign.value;
    if (d == TableListDesignLayout.contact) {
      if (c.id == idContactAvatar) {
        return TableColumnType.image;
      }
      return TableColumnType.text;
    }
    if (d == TableListDesignLayout.product) {
      if (c.id == idProductImage) {
        return TableColumnType.image;
      }
      if (c.id == idProductPrice) {
        return TableColumnType.number;
      }
      if (c.id == idProductName) {
        return TableColumnType.text;
      }
    }
    if (d == TableListDesignLayout.standard && c.id == idStandardAvatar) {
      return TableColumnType.image;
    }
    return c.type.value;
  }

  List<TableColumnEntity> _buildSummarySchemaColumns() {
    return summaryColumns
        .map((SummaryColumnDraft draft) {
          final String colName = draft.nameController.text.trim();
          final TableColumnType colType =
              draft.valueMode.value == SummaryValueMode.aggregation
                  ? TableColumnType.number
                  : TableColumnType.text;
          return TableColumnEntity(
            id: draft.id,
            name: colName.isEmpty ? 'Column' : colName,
            type: colType,
            includeInCreateForm: false,
            includeInEditForm: false,
            isRequired: false,
            pattern: null,
            formula: null,
            formulaDefinition: null,
            dropdownOptions: const <String>[],
            dropdownSourceKind: TableColumnDropdownSourceKind.manual,
            dropdownSourceTableId: null,
            dropdownSourceColumnId: null,
            textFieldHint: null,
            textPrefixIconKey: null,
            textSuffixIconKey: null,
            textValidationKind: TableTextValidationKind.none,
            textCustomRegex: null,
          );
        })
        .toList(growable: false);
  }

  List<TableColumnEntity> _buildSchemaColumns() {
    final List<ColumnDraft> colList = columns.toList(growable: false);
    final List<ColumnNameDraft> nameDrafts = colList
        .map(
          (ColumnDraft c) =>
              ColumnNameDraft(id: c.id, name: c.nameController.text),
        )
        .toList(growable: false);
    return colList
        .map((ColumnDraft c) {
          final TableColumnType resolved = _resolvedTypeForDraft(c)!;
          return TableColumnEntity(
            id: c.id,
            name: c.nameController.text.trim(),
            type: resolved,
            includeInCreateForm:
                mode.value == TableMode.crud ? c.includeInCreate.value : false,
            includeInEditForm:
                mode.value == TableMode.crud ? c.includeInEdit.value : false,
            isRequired: c.isRequired.value,
            isUnique: c.isUnique.value,
            pattern:
                c.patternController.text.trim().isEmpty
                    ? null
                    : c.patternController.text.trim(),
            formula:
                resolved == TableColumnType.formula
                    ? (c.formulaInputMode.value == FormulaInputMode.textEditor
                        ? c.formulaTextController.text.trim()
                        : c.composeGuidedFormula(
                          existingTableSchemas.isNotEmpty
                              ? existingTableSchemas.toList(growable: false)
                              : _existingSchemasCache,
                          colList,
                          nameDrafts,
                        ))
                    : null,
            formulaDefinition:
                resolved == TableColumnType.formula &&
                        c.formulaInputMode.value == FormulaInputMode.guided
                    ? c.guided.exportDefinitionTree()
                    : null,
            dropdownOptions: _dropdownOptionsForDraft(c, resolved),
            dropdownSourceKind:
                resolved == TableColumnType.dropdown
                    ? c.dropdownSourceKind.value
                    : TableColumnDropdownSourceKind.manual,
            dropdownSourceTableId:
                resolved == TableColumnType.dropdown &&
                        c.dropdownSourceKind.value ==
                            TableColumnDropdownSourceKind.table
                    ? c.dropdownSourceTableId.value
                    : null,
            dropdownSourceColumnId:
                resolved == TableColumnType.dropdown &&
                        c.dropdownSourceKind.value ==
                            TableColumnDropdownSourceKind.table
                    ? c.dropdownSourceColumnId.value
                    : null,
            textFieldHint:
                resolved == TableColumnType.text
                    ? (c.textHintController.text.trim().isEmpty
                        ? null
                        : c.textHintController.text.trim())
                    : null,
            textPrefixIconKey:
                resolved == TableColumnType.text
                    ? c.textPrefixIconKey.value
                    : null,
            textSuffixIconKey:
                resolved == TableColumnType.text
                    ? c.textSuffixIconKey.value
                    : null,
            textValidationKind:
                resolved == TableColumnType.text
                    ? c.textValidationKind.value
                    : TableTextValidationKind.none,
            textCustomRegex:
                resolved == TableColumnType.text &&
                        c.textValidationKind.value ==
                            TableTextValidationKind.custom
                    ? (c.textCustomRegexController.text.trim().isEmpty
                        ? null
                        : c.textCustomRegexController.text.trim())
                    : null,
            dateDefaultToday:
                resolved == TableColumnType.date ? c.dateDefaultToday.value : false,
            numberFieldHint:
                resolved == TableColumnType.number
                    ? (c.numberHintController.text.trim().isEmpty
                        ? null
                        : c.numberHintController.text.trim())
                    : null,
            numberPrefixText:
                resolved == TableColumnType.number
                    ? (c.numberPrefixUseIcon.value
                        ? null
                        : (c.numberPrefixController.text.trim().isEmpty
                            ? null
                            : c.numberPrefixController.text.trim()))
                    : null,
            numberSuffixText:
                resolved == TableColumnType.number
                    ? (c.numberSuffixUseIcon.value
                        ? null
                        : (c.numberSuffixController.text.trim().isEmpty
                            ? null
                            : c.numberSuffixController.text.trim()))
                    : null,
            numberPrefixIconKey:
                resolved == TableColumnType.number && c.numberPrefixUseIcon.value
                    ? c.numberPrefixIconKey.value
                    : null,
            numberSuffixIconKey:
                resolved == TableColumnType.number && c.numberSuffixUseIcon.value
                    ? c.numberSuffixIconKey.value
                    : null,
            numberMinValue:
                resolved == TableColumnType.number
                    ? double.tryParse(c.numberMinController.text.trim())
                    : null,
            numberMaxValue:
                resolved == TableColumnType.number
                    ? double.tryParse(c.numberMaxController.text.trim())
                    : null,
            numberAllowDecimals:
                resolved == TableColumnType.number
                    ? c.numberAllowDecimals.value
                    : true,
            numberIntegerOnly:
                resolved == TableColumnType.number
                    ? c.numberIntegerOnly.value
                    : false,
            numberPositiveOnly:
                resolved == TableColumnType.number
                    ? c.numberPositiveOnly.value
                    : false,
            numberShowStepper:
                resolved == TableColumnType.number
                    ? c.numberShowStepper.value
                    : false,
            numberStepValue:
                resolved == TableColumnType.number
                    ? (double.tryParse(c.numberStepController.text.trim()) ?? 1)
                    : 1,
          );
        })
        .toList(growable: false);
  }

  List<String> _dropdownOptionsForDraft(
    ColumnDraft c,
    TableColumnType resolved,
  ) {
    if (resolved != TableColumnType.dropdown) {
      return const <String>[];
    }
    if (c.dropdownSourceKind.value == TableColumnDropdownSourceKind.table) {
      return const <String>[];
    }
    return DropdownColumnOptions.manualOptionsFromMultiline(
      c.dropdownOptionsController.text,
    );
  }

  String layoutDisplayName(TableListDesignLayout layout) => switch (layout) {
    TableListDesignLayout.contact => 'Contact List',
    TableListDesignLayout.product => 'Product List',
    TableListDesignLayout.standard => 'Standard Dynamic',
  };

  Future<void> submit() async {
    // Settle focused editor keyboard events before save/navigation.
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(Duration.zero);
    if (tableKind.value != TableKind.summary) {
      if (!await validateFormulaColumnsInline()) {
        currentStep.value = 3;
        return;
      }
    }
    final String? error = validateForStep(lastStepIndex);
    if (error != null) {
      showAppSnackbar('Validation', error);
      return;
    }
    final TableListDesignLayout design =
        selectedDesign.value ?? TableListDesignLayout.standard;
    isSaving.value = true;
    try {
      await _loadExistingSchemas();
      final String tableId = _uuid.v4();
      final String? pageId = selectedPageId.value;
      if (pageId == null) {
        showAppSnackbar('Validation', 'Assign page is required');
        return;
      }
      final List<TableColumnEntity> schemaColumns;
      final TableKind savedKind = tableKind.value;
      final TableSummaryConfig? summaryCfg;
      final TableMode savedMode;
      final bool swipe;
      final TableListDesignLayout savedDesign;
      final List<TableAffectingConfig> affectingCfg;
      final List<TableValidationRule> validationRulesCfg;
      if (savedKind == TableKind.summary) {
        if (summaryColumns.isEmpty) {
          showAppSnackbar('Validation', 'Invalid summary configuration');
          return;
        }
        final List<SummaryColumnConfig> summaryColumnConfigs =
            <SummaryColumnConfig>[];
        for (final SummaryColumnDraft draft in summaryColumns) {
          final String? sourceTableId = draft.sourceTableId.value;
          final String? sourceColumnId = draft.sourceColumnId.value;
          if (sourceTableId == null || sourceColumnId == null) {
            showAppSnackbar('Validation', 'Summary column source is required');
            return;
          }
          summaryColumnConfigs.add(
            SummaryColumnConfig(
              id: draft.id,
              name:
                  draft.nameController.text.trim().isEmpty
                      ? 'Column'
                      : draft.nameController.text.trim(),
              sourceTableId: sourceTableId,
              sourceColumnId: sourceColumnId,
              groupBy: draft.groupBy.value,
              valueMode: draft.valueMode.value,
              aggregation: draft.aggregation.value,
              formula:
                  draft.formulaController.text.trim().isEmpty
                      ? null
                      : draft.formulaController.text.trim(),
            ),
          );
        }
        final SummaryColumnConfig primary = summaryColumnConfigs.firstWhere(
          (SummaryColumnConfig c) => c.groupBy,
          orElse: () => summaryColumnConfigs.first,
        );
        if (primary.sourceTableId == null || primary.sourceColumnId == null) {
          showAppSnackbar('Validation', 'Primary grouping column is invalid');
          return;
        }
        summaryCfg = TableSummaryConfig(
          sourceTableId: primary.sourceTableId!,
          groupByColumnId: primary.sourceColumnId!,
          aggregateSourceColumnId: primary.sourceColumnId!,
          operation: primary.aggregation,
          columns: summaryColumnConfigs,
        );
        schemaColumns = _buildSummarySchemaColumns();
        savedMode = TableMode.crud;
        swipe = false;
        savedDesign = TableListDesignLayout.standard;
        affectingCfg = const <TableAffectingConfig>[];
        validationRulesCfg = const <TableValidationRule>[];
      } else {
        summaryCfg = null;
        schemaColumns = _buildSchemaColumns();
        savedMode = mode.value;
        swipe = swipeToDelete.value;
        savedDesign = design;
        affectingCfg = _buildAffectingTablesConfig();
        validationRulesCfg = validationRules
            .map((TableValidationRuleDraft draft) => draft.toEntity())
            .toList(growable: false);
      }
      await _saveTableSchema(
        TableSchemaEntity(
          id: tableId,
          pageId: pageId,
          name: tableNameController.text.trim(),
          description: descriptionController.text.trim(),
          mode: savedMode,
          layoutType: swipe ? TableLayoutType.swipe : TableLayoutType.vertical,
          listDesignLayout: savedDesign,
          swipeToDelete: swipe,
          productDisplayMode: productDisplayMode.value,
          tableKind: savedKind,
          summaryConfig: summaryCfg,
          affectingTables: affectingCfg,
          validationRules: validationRulesCfg,
          searchEnabled:
              savedKind == TableKind.summary ? false : searchEnabled.value,
          dataLoadingMode:
              savedKind == TableKind.summary
                  ? TableDataLoadingMode.lazy
                  : dataLoadingMode.value,
          pageSize: pageSize.value,
          lazyInitialLoad: lazyInitialLoad.value,
          columns: schemaColumns,
        ),
      );
      await _saveWidget(
        BuilderWidgetEntity(
          id: _uuid.v4(),
          pageId: pageId,
          type: 'table',
          config: <String, dynamic>{'tableId': tableId},
        ),
      );
      showAppSnackbar('Table', 'Table created');
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

  Future<void> _saveReadOnlyRows(
    String tableId,
    List<TableColumnEntity> schemaColumns,
  ) async {
    if (readOnlyPopulationMode.value == ReadOnlyRowPopulationMode.sourceMap) {
      final List<Map<String, dynamic>> generated =
          await _buildReadOnlyGeneratedRows();
      for (final Map<String, dynamic> values in generated) {
        await _saveTableRow(
          TableRowEntity(id: _uuid.v4(), tableId: tableId, values: values),
        );
      }
      return;
    }
    final Map<String, List<TableRowEntity>> rowsByTable =
        <String, List<TableRowEntity>>{};
    for (final TableSchemaEntity s in _existingSchemasCache) {
      rowsByTable[s.id] = await _getTableRows(s.id);
    }
    for (final ReadOnlyRowDraft draft in readOnlyRows) {
      final Map<String, dynamic> values = <String, dynamic>{};
      for (final TableColumnEntity column in schemaColumns) {
        final ReadOnlyCellDraft cell = draft.cells[column.id]!;
        switch (cell.source.value) {
          case ReadOnlyValueSource.manual:
            values[column.id] = <String, dynamic>{
              'type': 'manual',
              'value': cell.manualController.text.trim(),
            };
            break;
          case ReadOnlyValueSource.formula:
            final String formulaToPersist =
                _readOnlyComposedFormula(
                  cell,
                  column.id,
                  _existingSchemasCache,
                ) ??
                '';
            values[column.id] = <String, dynamic>{
              'type': 'formula',
              'expression': formulaToPersist,
            };
            break;
          case ReadOnlyValueSource.auto:
            final String? srcTableId = cell.sourceTableId.value;
            final String? srcColId = cell.sourceColumnId.value;
            values[column.id] = <String, dynamic>{
              'type': 'lookup',
              'sourceTableId': srcTableId,
              'sourceColumnId': srcColId,
            };
            break;
        }
      }
      await _saveTableRow(
        TableRowEntity(id: _uuid.v4(), tableId: tableId, values: values),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _buildReadOnlyGeneratedRows() async {
    final String? keyTableId = readOnlyPopulateMapping.uniqueKeyTableId.value;
    final String? keyColumnId = readOnlyPopulateMapping.uniqueKeyColumnId.value;
    if (keyTableId == null || keyColumnId == null) {
      return const <Map<String, dynamic>>[];
    }
    final List<TableSchemaEntity> schemas = _existingSchemasCache;
    final Map<String, TableSchemaEntity> schemaById =
        <String, TableSchemaEntity>{
          for (final TableSchemaEntity s in schemas) s.id: s,
        };
    final Map<String, List<TableRowEntity>> rowsByTable =
        <String, List<TableRowEntity>>{};
    for (final TableSchemaEntity s in schemas) {
      rowsByTable[s.id] = await _getTableRows(s.id);
    }
    final TableSchemaEntity? keySchema = schemaById[keyTableId];
    if (keySchema == null) {
      return const <Map<String, dynamic>>[];
    }
    final List<TableRowEntity> keyRows =
        rowsByTable[keyTableId] ?? const <TableRowEntity>[];
    final TableSchemaEntity generatedSchema = TableSchemaEntity(
      id: '__generated_readonly__',
      pageId: '',
      name: '__generated_readonly__',
      description: '',
      mode: TableMode.crud,
      columns: columns
          .map(
            (ColumnDraft c) => TableColumnEntity(
              id: c.id,
              name: c.nameController.text.trim(),
              type: TableColumnType.text,
            ),
          )
          .toList(growable: false),
    );
    final Set<String> seenKeys = <String>{};
    final List<Map<String, dynamic>> generated = <Map<String, dynamic>>[];

    for (final TableRowEntity sourceRow in keyRows) {
      final Map<String, dynamic> resolvedKey =
          TableFormulaEvaluator.resolveRowValues(
            schema: keySchema,
            row: sourceRow,
            allSchemas: schemas,
            rowsByTableId: rowsByTable,
          );
      final String keyValue =
          (resolvedKey[keyColumnId] ?? sourceRow.values[keyColumnId] ?? '')
              .toString()
              .trim();
      if (keyValue.isEmpty || seenKeys.contains(keyValue)) {
        continue;
      }
      seenKeys.add(keyValue);
      final Map<String, dynamic> rowValues = <String, dynamic>{};
      final Map<String, dynamic> generatedWorkingRow = <String, dynamic>{};
      final Map<String, List<TableRowEntity>> rowScopedRowsByTable =
          <String, List<TableRowEntity>>{
            ...rowsByTable,
            keyTableId: <TableRowEntity>[sourceRow],
          };
      for (final ColumnDraft targetColumn in columns) {
        final ReadOnlyCellDraft? mappingCell =
            readOnlyPopulateMapping.cells[targetColumn.id];
        if (mappingCell == null) {
          continue;
        }
        switch (mappingCell.source.value) {
          case ReadOnlyValueSource.manual:
            final String manualValue = mappingCell.manualController.text.trim();
            generatedWorkingRow[targetColumn.id] = manualValue;
            rowValues[targetColumn.id] = <String, dynamic>{
              'type': 'manual',
              'value': manualValue,
            };
            break;
          case ReadOnlyValueSource.formula:
            final String formulaToPersist =
                _readOnlyComposedFormula(
                  mappingCell,
                  targetColumn.id,
                  schemas,
                ) ??
                '';
            final String computed = TableFormulaEvaluator.evaluate(
              formula: formulaToPersist,
              currentSchema: generatedSchema,
              workingRowByColId: generatedWorkingRow,
              allSchemas: schemas,
              rowsByTableId: rowScopedRowsByTable,
            );
            generatedWorkingRow[targetColumn.id] = computed;
            rowValues[targetColumn.id] = <String, dynamic>{
              'type': 'manual',
              'value': computed,
            };
            break;
          case ReadOnlyValueSource.auto:
            final String? srcTableId = mappingCell.sourceTableId.value;
            final String? srcColId = mappingCell.sourceColumnId.value;
            String resolvedValue = '';
            if (srcTableId != null &&
                srcColId != null &&
                srcTableId.isNotEmpty &&
                srcColId.isNotEmpty) {
              if (srcTableId == keyTableId) {
                resolvedValue =
                    (resolvedKey[srcColId] ?? sourceRow.values[srcColId] ?? '')
                        .toString();
              } else {
                final TableSchemaEntity? srcSchema = schemaById[srcTableId];
                final List<TableRowEntity> srcRows =
                    rowsByTable[srcTableId] ?? const <TableRowEntity>[];
                if (srcSchema != null && srcRows.isNotEmpty) {
                  final Map<String, dynamic> resolvedSource =
                      TableFormulaEvaluator.resolveRowValues(
                        schema: srcSchema,
                        row: srcRows.first,
                        allSchemas: schemas,
                        rowsByTableId: rowsByTable,
                      );
                  resolvedValue =
                      (resolvedSource[srcColId] ??
                              srcRows.first.values[srcColId] ??
                              '')
                          .toString();
                }
              }
            }
            generatedWorkingRow[targetColumn.id] = resolvedValue;
            rowValues[targetColumn.id] = <String, dynamic>{
              'type': 'manual',
              'value': resolvedValue,
            };
            break;
        }
      }
      generated.add(rowValues);
    }
    return generated;
  }

  Future<bool> validateFormulaColumnsInline() async {
    try {
      _existingSchemasCache = await _getAllSchemas();
      existingTableSchemas.assignAll(_existingSchemasCache);
    } catch (_) {
      _existingSchemasCache = <TableSchemaEntity>[];
      existingTableSchemas.clear();
    }
    formulaFieldErrors.clear();
    for (final ColumnDraft col in columns) {
      if (_resolvedTypeForDraft(col) != TableColumnType.formula) {
        continue;
      }
      formulaBuilderFieldErrors.removeWhere(
        (String k, String v) => k.startsWith('${col.id}|'),
      );
    }
    formulaFieldErrors.refresh();
    formulaBuilderFieldErrors.refresh();
    bool ok = true;
    final List<ColumnNameDraft> siblings = columns
        .map(
          (ColumnDraft c) =>
              ColumnNameDraft(id: c.id, name: c.nameController.text),
        )
        .toList(growable: false);
    final List<ColumnDraft> colSnapshot = columns.toList(growable: false);
    for (final ColumnDraft col in colSnapshot) {
      if (_resolvedTypeForDraft(col) != TableColumnType.formula) {
        continue;
      }
      if (col.formulaInputMode.value == FormulaInputMode.textEditor) {
        final String t = col.formulaTextController.text.trim();
        if (t.isEmpty) {
          formulaFieldErrors[col.id] = TableFormulaValidator.errRequired;
          ok = false;
          continue;
        }
        final String? msg = TableFormulaValidator.validate(
          formula: t,
          currentColumnId: col.id,
          siblingColumns: siblings,
          existingTables: _existingSchemasCache,
        );
        if (msg != null) {
          formulaFieldErrors[col.id] = msg;
          ok = false;
        }
        continue;
      }
      final Map<String, String> guidedErrors = col.validateGuided(
        _existingSchemasCache,
        colSnapshot,
        siblings,
      );
      if (guidedErrors.isNotEmpty) {
        for (final MapEntry<String, String> e in guidedErrors.entries) {
          formulaBuilderFieldErrors['${col.id}|${e.key}'] = e.value;
        }
        ok = false;
        continue;
      }
      final String? composed = col.composeGuidedFormula(
        _existingSchemasCache,
        colSnapshot,
        siblings,
      );
      if (composed == null || composed.isEmpty) {
        formulaFieldErrors[col.id] = TableFormulaValidator.errRequired;
        ok = false;
        continue;
      }
      final String? compMsg = TableFormulaValidator.validate(
        formula: composed,
        currentColumnId: col.id,
        siblingColumns: siblings,
        existingTables: _existingSchemasCache,
      );
      if (compMsg != null) {
        formulaFieldErrors[col.id] = compMsg;
        ok = false;
      }
    }
    formulaFieldErrors.refresh();
    formulaBuilderFieldErrors.refresh();
    formulaErrorsVersion.value++;
    formulaPreviewVersion.value++;
    return ok;
  }

  @override
  List<GuidedFormulaColumnLike> siblingColumnsExcluding(String columnId) {
    return <GuidedFormulaColumnLike>[
      for (final ColumnDraft c in columns)
        if (c.id != columnId) c,
    ];
  }

  @override
  List<ColumnNameDraft> allColumnsAsNameDrafts() {
    return columns
        .map(
          (ColumnDraft c) =>
              ColumnNameDraft(id: c.id, name: c.nameController.text),
        )
        .toList(growable: false);
  }

  @override
  String tableDisplayLabel(TableSchemaEntity schema) {
    String pageName = schema.pageId;
    for (final PageOption p in pageOptions) {
      if (p.id == schema.pageId) {
        pageName = p.name.trim().isEmpty ? schema.pageId : p.name.trim();
        break;
      }
    }
    return '${schema.name} ($pageName)';
  }
}

class PageOption {
  const PageOption({required this.id, required this.name});

  final String id;
  final String name;
}

class SummaryColumnDraft {
  SummaryColumnDraft({required this.id, TextEditingController? nameController})
    : nameController = nameController ?? TextEditingController();

  final String id;
  final TextEditingController nameController;
  final RxnString sourceTableId = RxnString();
  final RxnString sourceColumnId = RxnString();
  final RxBool groupBy = false.obs;
  final Rx<SummaryValueMode> valueMode = SummaryValueMode.uniqueValue.obs;
  final Rx<SummaryAggregationOperation> aggregation =
      SummaryAggregationOperation.sum.obs;
  final TextEditingController formulaController = TextEditingController();

  void dispose() {
    nameController.dispose();
    formulaController.dispose();
  }
}

enum ReadOnlyValueSource { manual, formula, auto }

enum ReadOnlyRowPopulationMode { manual, sourceMap }

class ReadOnlyCellDraft {
  final Rx<ReadOnlyValueSource> source = ReadOnlyValueSource.manual.obs;
  final TextEditingController manualController = TextEditingController();
  final TextEditingController formulaController = TextEditingController();
  final TextEditingController formulaTextController = TextEditingController();
  final Rx<FormulaInputMode> formulaInputMode = FormulaInputMode.guided.obs;
  final GuidedFormulaDraftState guided = GuidedFormulaDraftState();
  final RxnString sourceTableId = RxnString();
  final RxnString sourceColumnId = RxnString();

  void dispose() {
    manualController.dispose();
    formulaController.dispose();
    formulaTextController.dispose();
    guided.dispose();
  }
}

class ReadOnlyRowDraft {
  ReadOnlyRowDraft({required this.id});

  final String id;
  final Map<String, ReadOnlyCellDraft> cells = <String, ReadOnlyCellDraft>{};

  void dispose() {
    for (final ReadOnlyCellDraft cell in cells.values) {
      cell.dispose();
    }
  }
}

class ReadOnlyPopulateMappingDraft {
  final Map<String, ReadOnlyCellDraft> cells = <String, ReadOnlyCellDraft>{};
  final RxnString uniqueKeyTableId = RxnString();
  final RxnString uniqueKeyColumnId = RxnString();

  void dispose() {
    for (final ReadOnlyCellDraft cell in cells.values) {
      cell.dispose();
    }
  }
}

class AffectingColumnRuleDraft {
  AffectingColumnRuleDraft({required this.id});

  final String id;
  final RxnString targetColumnId = RxnString();
  final TextEditingController formulaController = TextEditingController();

  void dispose() {
    formulaController.dispose();
  }
}

class AffectingTableDraft {
  AffectingTableDraft({required this.id, List<AffectingColumnRuleDraft>? rules})
    : rules = rules ?? <AffectingColumnRuleDraft>[];

  final String id;
  final RxnString targetTableId = RxnString();
  final RxnString matchTargetColumnId = RxnString();
  final RxnString matchSourceColumnId = RxnString();
  final List<AffectingColumnRuleDraft> rules;

  void dispose() {
    for (final AffectingColumnRuleDraft rule in rules) {
      rule.dispose();
    }
  }
}

class TableValidationRuleDraft {
  TableValidationRuleDraft({required this.id, TextEditingController? nameController})
    : nameController = nameController ?? TextEditingController();

  final String id;
  final TextEditingController nameController;
  final TextEditingController conditionController = TextEditingController();
  final TextEditingController errorMessageController = TextEditingController();
  final RxBool enabled = true.obs;

  TableValidationRule toEntity() {
    return TableValidationRule(
      id: id,
      name: nameController.text.trim().isEmpty
          ? 'Validation rule'
          : nameController.text.trim(),
      conditionFormula: conditionController.text.trim(),
      errorMessage: errorMessageController.text.trim(),
      enabled: enabled.value,
    );
  }

  void dispose() {
    nameController.dispose();
    conditionController.dispose();
    errorMessageController.dispose();
  }
}
