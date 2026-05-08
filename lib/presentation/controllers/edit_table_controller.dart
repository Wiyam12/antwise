import 'package:antwise/core/app_snackbar.dart';
import 'package:antwise/core/services/notification_runtime_service.dart';
import 'package:antwise/domain/dropdown/dropdown_column_options.dart';
import 'package:antwise/domain/entities/builder_page_entity.dart';
import 'package:antwise/domain/entities/product_display_mode.dart';
import 'package:antwise/domain/entities/table_affecting_config.dart';
import 'package:antwise/domain/entities/table_column_dropdown_source.dart';
import 'package:antwise/domain/entities/table_column_entity.dart';
import 'package:antwise/domain/entities/table_column_type.dart';
import 'package:antwise/domain/entities/table_text_validation_kind.dart';
import 'package:antwise/domain/entities/table_data_loading_mode.dart';
import 'package:antwise/domain/entities/table_inventory_deduction_config.dart';
import 'package:antwise/domain/entities/table_kind.dart';
import 'package:antwise/domain/entities/table_layout_type.dart';
import 'package:antwise/domain/entities/table_list_design_layout.dart';
import 'package:antwise/domain/entities/table_mode.dart';
import 'package:antwise/domain/entities/table_row_entity.dart';
import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/domain/entities/table_summary_config.dart';
import 'package:antwise/domain/entities/table_validation_rule.dart';
import 'package:antwise/domain/usecases/get_all_table_schemas_usecase.dart';
import 'package:antwise/domain/usecases/get_builder_pages_usecase.dart';
import 'package:antwise/domain/usecases/get_table_rows_usecase.dart';
import 'package:antwise/domain/usecases/get_table_schema_by_id_usecase.dart';
import 'package:antwise/domain/usecases/delete_table_row_usecase.dart';
import 'package:antwise/domain/usecases/save_table_row_usecase.dart';
import 'package:antwise/domain/usecases/save_table_schema_usecase.dart';
import 'package:antwise/domain/formula/table_formula_evaluator.dart';
import 'package:antwise/domain/validation/table_formula_validator.dart';
import 'package:antwise/presentation/controllers/create_table_controller.dart';
import 'package:antwise/presentation/controllers/home_controller.dart';
import 'package:antwise/presentation/models/formula_input_mode.dart';
import 'package:antwise/presentation/models/guided_formula_draft_state.dart';
import 'package:antwise/presentation/models/guided_formula_host.dart';
import 'package:antwise/presentation/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

class EditTableController extends GetxController implements GuidedFormulaHost {
  EditTableController(
    this._getById,
    this._save,
    this._getAllSchemas,
    this._getRows,
    this._saveRow,
    this._deleteRow,
    this._getPages,
  );

  final GetTableSchemaByIdUseCase _getById;
  final SaveTableSchemaUseCase _save;
  final GetAllTableSchemasUseCase _getAllSchemas;
  final GetTableRowsUseCase _getRows;
  final SaveTableRowUseCase _saveRow;
  final DeleteTableRowUseCase _deleteRow;
  final GetBuilderPagesUseCase _getPages;

  final TextEditingController tableNameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final RxnString selectedPageId = RxnString();
  final RxList<PageOption> pageOptions = <PageOption>[].obs;
  final RxList<EditColumnDraft> columns = <EditColumnDraft>[].obs;

  /// At most one column [ExpansionTile] expanded at a time; set when adding a column.
  final RxnString expandedColumnId = RxnString();
  final RxInt currentStep = 0.obs;
  final RxnString selectedVisualLayoutKey = RxnString();
  final Rxn<ProductDisplayMode> productDisplayMode = Rxn<ProductDisplayMode>();
  final RxList<AffectingTableDraft> affectingTables =
      <AffectingTableDraft>[].obs;
  final RxMap<String, String> affectingFormulaErrors = <String, String>{}.obs;
  final RxList<SummaryColumnDraft> summaryColumns = <SummaryColumnDraft>[].obs;
  final RxList<TableValidationRuleDraft> validationRules =
      <TableValidationRuleDraft>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool isSaving = false.obs;
  final RxBool isRowsLoading = false.obs;
  final RxBool swipeToDelete = false.obs;
  final Rx<TableMode> mode = TableMode.crud.obs;
  final RxBool searchEnabled = false.obs;
  final Rx<TableDataLoadingMode> dataLoadingMode =
      TableDataLoadingMode.lazy.obs;
  final RxInt pageSize = 10.obs;
  final RxInt lazyInitialLoad = 5.obs;
  final RxList<TableRowEntity> rows = <TableRowEntity>[].obs;
  final RxList<EditReadOnlyRowDraft> readOnlyRowsDrafts =
      <EditReadOnlyRowDraft>[].obs;
  final Rx<EditReadOnlyRowPopulationMode> readOnlyPopulationMode =
      EditReadOnlyRowPopulationMode.manual.obs;
  final EditReadOnlyPopulateMappingDraft readOnlyPopulateMapping =
      EditReadOnlyPopulateMappingDraft();
  final RxList<Map<String, dynamic>> readOnlyGeneratedPreview =
      <Map<String, dynamic>>[].obs;
  final Uuid _uuid = const Uuid();
  TableSchemaEntity? _schema;

  /// Id of the table being edited (excluded from "other table" dropdown sources).
  String? get editingTableId => _schema?.id;

  /// Exposed for the edit wizard (summary config, review).
  TableSchemaEntity? get editingSchema => _schema;
  bool get isSummaryTable => _schema?.tableKind == TableKind.summary;
  bool get isReadOnlyTable =>
      !isSummaryTable && mode.value == TableMode.readOnly;

  bool get isCrudStandardTable =>
      _schema?.tableKind == TableKind.standard && mode.value == TableMode.crud;

  int get lastStepIndex {
    if (_schema?.tableKind == TableKind.summary) {
      return 4;
    }
    return isCrudStandardTable ? 6 : 5;
  }

  TableListDesignLayout? get persistedListDesign => _schema?.listDesignLayout;

  List<TableSchemaEntity> get affectingTargetTableOptions {
    return existingTableSchemas
        .where(
          (TableSchemaEntity schema) => schema.tableKind == TableKind.standard,
        )
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
    for (final TableSchemaEntity s in _formulaSchemaCache) {
      if (s.id == id) {
        return s;
      }
    }
    return null;
  }

  final RxMap<String, String> formulaFieldErrors = <String, String>{}.obs;
  final RxMap<String, String> dropdownFieldErrors = <String, String>{}.obs;
  final RxMap<String, String> formulaBuilderFieldErrors =
      <String, String>{}.obs;
  final RxInt formulaErrorsVersion = 0.obs;
  final RxInt formulaPreviewVersion = 0.obs;
  final RxList<TableSchemaEntity> existingTableSchemas =
      <TableSchemaEntity>[].obs;
  List<TableSchemaEntity> _formulaSchemaCache = <TableSchemaEntity>[];

  /// Optional: decrement stock on another table when a **new** row is created here.
  final RxBool inventoryDeductionEnabled = false.obs;
  final RxnString invStockTableId = RxnString();
  final RxnString invStockMatchColumnId = RxnString();
  final RxnString invStockQuantityColumnId = RxnString();
  final RxnString invLineProductColumnId = RxnString();
  final RxnString invLineQuantityColumnId = RxnString();

  List<TableSchemaEntity> get inventoryStockTableOptions {
    return existingTableSchemas
        .where(
          (TableSchemaEntity s) =>
              s.id != editingTableId && s.tableKind != TableKind.summary,
        )
        .toList(growable: false);
  }

  TableSchemaEntity? _inventoryStockSchema() {
    final String? id = invStockTableId.value;
    if (id == null || id.isEmpty) {
      return null;
    }
    for (final TableSchemaEntity s in existingTableSchemas) {
      if (s.id == id) {
        return s;
      }
    }
    return null;
  }

  /// All columns on the selected stock table (for match + numeric pickers).
  List<TableColumnEntity> get inventoryStockTableColumns =>
      _inventoryStockSchema()?.columns ?? const <TableColumnEntity>[];

  List<TableColumnEntity> get inventoryStockNumericColumns {
    return inventoryStockTableColumns
        .where((TableColumnEntity c) => c.type == TableColumnType.number)
        .toList(growable: false);
  }

  List<EditColumnDraft> get inventoryLineProductCandidates {
    return columns
        .where(
          (EditColumnDraft c) =>
              c.type.value != TableColumnType.formula &&
              c.type.value != TableColumnType.image &&
              c.type.value != TableColumnType.file &&
              c.type.value != TableColumnType.boolean &&
              c.type.value != TableColumnType.date,
        )
        .toList(growable: false);
  }

  List<EditColumnDraft> get inventoryLineQuantityCandidates {
    return columns
        .where((EditColumnDraft c) => c.type.value == TableColumnType.number)
        .toList(growable: false);
  }

  String? get invStockTableFieldValue {
    final String? v = invStockTableId.value;
    if (v == null) {
      return null;
    }
    return inventoryStockTableOptions.any((TableSchemaEntity s) => s.id == v)
        ? v
        : null;
  }

  String? get invStockMatchColumnFieldValue {
    final String? v = invStockMatchColumnId.value;
    if (v == null) {
      return null;
    }
    return inventoryStockTableColumns.any((TableColumnEntity c) => c.id == v)
        ? v
        : null;
  }

  String? get invStockQuantityColumnFieldValue {
    final String? v = invStockQuantityColumnId.value;
    if (v == null) {
      return null;
    }
    return inventoryStockNumericColumns.any((TableColumnEntity c) => c.id == v)
        ? v
        : null;
  }

  String? get invLineProductFieldValue {
    final String? v = invLineProductColumnId.value;
    if (v == null) {
      return null;
    }
    return inventoryLineProductCandidates.any((EditColumnDraft c) => c.id == v)
        ? v
        : null;
  }

  String? get invLineQuantityFieldValue {
    final String? v = invLineQuantityColumnId.value;
    if (v == null) {
      return null;
    }
    return inventoryLineQuantityCandidates.any((EditColumnDraft c) => c.id == v)
        ? v
        : null;
  }

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  @override
  void onClose() {
    final List<EditReadOnlyRowDraft> readOnlyRows = readOnlyRowsDrafts.toList(
      growable: false,
    );
    readOnlyRowsDrafts.clear();
    final List<EditReadOnlyCellDraft> mappingCells = readOnlyPopulateMapping
        .cells
        .values
        .toList(growable: false);
    readOnlyPopulateMapping.cells.clear();
    _scheduleDisposeReadOnlyDraftControllers(
      rows: readOnlyRows,
      mappingCells: mappingCells,
    );
    clearAffectingTables();
    clearValidationRules();
    _disposeSummaryColumns();
    _scheduleDisposeFormControllers(
      tableName: tableNameController,
      description: descriptionController,
      drafts: List<EditColumnDraft>.from(columns),
    );
    super.onClose();
  }

  Future<void> _load() async {
    isLoading.value = true;
    final String tableId = (Get.arguments ?? '').toString();
    final TableSchemaEntity? schema = await _getById(tableId);
    _schema = schema;
    if (schema == null) {
      isLoading.value = false;
      return;
    }
    try {
      final List<BuilderPageEntity> pages = await _getPages();
      pageOptions.assignAll(
        pages
            .where((BuilderPageEntity p) => !p.isDeleted)
            .map((BuilderPageEntity p) => PageOption(id: p.id, name: p.name))
            .toList(growable: false),
      );
    } catch (_) {
      pageOptions.clear();
    }
    currentStep.value = 0;
    tableNameController.text = schema.name;
    descriptionController.text = schema.description;
    selectedPageId.value = schema.pageId;
    mode.value = schema.mode;
    swipeToDelete.value =
        schema.swipeToDelete || schema.layoutType == TableLayoutType.swipe;
    productDisplayMode.value = schema.productDisplayMode;
    selectedVisualLayoutKey.value =
        CreateTableController.visualLayoutKeyForDesign(schema.listDesignLayout);
    searchEnabled.value = schema.searchEnabled;
    dataLoadingMode.value = schema.dataLoadingMode;
    pageSize.value = schema.pageSize;
    lazyInitialLoad.value = schema.lazyInitialLoad;
    _hydrateAffectingFromSchema(schema.affectingTables);
    _hydrateValidationRulesFromSchema(schema.validationRules);
    _hydrateSummaryColumnsFromSchema(schema.summaryConfig, schema.columns);
    columns.assignAll(
      schema.columns
          .map((TableColumnEntity c) => EditColumnDraft.fromEntity(c))
          .toList(growable: false),
    );
    for (final TableColumnEntity col in schema.columns) {
      debugPrint(
        '[EditTable] loaded column: '
        'id=${col.id}, '
        'name=${col.name}, '
        'type=${col.type.storageValue}, '
        'formula=${(col.formula ?? '').trim().isNotEmpty}, '
        'formulaDefinition=${col.formulaDefinition != null && col.formulaDefinition!.isNotEmpty}',
      );
    }
    final TableInventoryDeductionConfig? inv = schema.inventoryDeduction;
    inventoryDeductionEnabled.value = inv != null;
    invStockTableId.value = inv?.stockTableId;
    invStockMatchColumnId.value = inv?.stockMatchColumnId;
    invStockQuantityColumnId.value = inv?.stockQuantityColumnId;
    invLineProductColumnId.value = inv?.lineProductColumnId;
    invLineQuantityColumnId.value = inv?.lineQuantityColumnId;
    await _refreshGuidedSchemas();
    await _loadRows();
    _bootstrapReadOnlyDraftsFromRows();
    isLoading.value = false;
  }

  Future<void> _loadRows() async {
    final TableSchemaEntity? schema = _schema;
    if (schema == null || schema.tableKind == TableKind.summary) {
      rows.clear();
      return;
    }
    isRowsLoading.value = true;
    try {
      final List<TableRowEntity> loaded = await _getRows(schema.id);
      rows.assignAll(loaded);
    } catch (_) {
      rows.clear();
    } finally {
      isRowsLoading.value = false;
    }
  }

  Future<void> _refreshGuidedSchemas() async {
    try {
      final List<TableSchemaEntity> list = await _getAllSchemas();
      _formulaSchemaCache = list;
      existingTableSchemas.assignAll(list);
    } catch (_) {
      _formulaSchemaCache = <TableSchemaEntity>[];
      existingTableSchemas.clear();
    }
  }

  void setSwipeToDelete(bool value) => swipeToDelete.value = value;

  void setMode(TableMode value) {
    mode.value = value;
    if (value == TableMode.readOnly) {
      _loadRows();
    }
  }

  void setSearchEnabled(bool value) => searchEnabled.value = value;
  void setDataLoadingMode(TableDataLoadingMode value) =>
      dataLoadingMode.value = value;
  void setPageSize(int value) => pageSize.value = value.clamp(1, 200);
  void setLazyInitialLoad(int value) =>
      lazyInitialLoad.value = value.clamp(1, 200);

  void _hydrateAffectingFromSchema(List<TableAffectingConfig> configs) {
    clearAffectingTables();
    for (final TableAffectingConfig cfg in configs) {
      final AffectingTableDraft draft = AffectingTableDraft(
        id: _uuid.v4(),
        rules: cfg.rules
            .map((TableAffectedColumnRule r) {
              final AffectingColumnRuleDraft rule = AffectingColumnRuleDraft(
                id: _uuid.v4(),
              );
              rule.targetColumnId.value = r.targetColumnId;
              rule.formulaController.text = r.formula;
              return rule;
            })
            .toList(growable: false),
      );
      draft.targetTableId.value = cfg.targetTableId;
      draft.matchTargetColumnId.value = cfg.match.targetColumnId;
      draft.matchSourceColumnId.value = cfg.match.sourceColumnId;
      affectingTables.add(draft);
    }
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

  void _hydrateValidationRulesFromSchema(List<TableValidationRule> rules) {
    clearValidationRules();
    for (final TableValidationRule rule in rules) {
      final TableValidationRuleDraft draft = TableValidationRuleDraft(
        id: rule.id,
        nameController: TextEditingController(text: rule.name),
      );
      draft.conditionController.text = rule.conditionFormula;
      draft.errorMessageController.text = rule.errorMessage;
      draft.enabled.value = rule.enabled;
      validationRules.add(draft);
    }
  }

  void _disposeSummaryColumns() {
    for (final SummaryColumnDraft draft in summaryColumns) {
      draft.dispose();
    }
    summaryColumns.clear();
  }

  void _hydrateSummaryColumnsFromSchema(
    TableSummaryConfig? config,
    List<TableColumnEntity> fallbackColumns,
  ) {
    _disposeSummaryColumns();
    final List<SummaryColumnConfig> configs =
        config?.columns ?? const <SummaryColumnConfig>[];
    if (configs.isNotEmpty) {
      summaryColumns.assignAll(
        configs.map((SummaryColumnConfig col) {
          final SummaryColumnDraft draft = SummaryColumnDraft(
            id: col.id,
            nameController: TextEditingController(text: col.name),
          );
          draft.sourceTableId.value = col.sourceTableId;
          draft.sourceColumnId.value = col.sourceColumnId;
          draft.groupBy.value = col.groupBy;
          draft.valueMode.value = col.valueMode;
          draft.aggregation.value = col.aggregation;
          draft.formulaController.text = col.formula ?? '';
          return draft;
        }).toList(growable: false),
      );
      return;
    }

    if (fallbackColumns.isEmpty) {
      addSummaryColumn();
      return;
    }
    summaryColumns.assignAll(
      fallbackColumns.map((TableColumnEntity col) {
        final SummaryColumnDraft draft = SummaryColumnDraft(
          id: col.id,
          nameController: TextEditingController(text: col.name),
        );
        if (config != null) {
          draft.sourceTableId.value = config.sourceTableId;
          draft.sourceColumnId.value = col.id;
          draft.groupBy.value = col.id == config.groupByColumnId;
          draft.valueMode.value =
              col.type == TableColumnType.number
                  ? SummaryValueMode.aggregation
                  : SummaryValueMode.uniqueValue;
          draft.aggregation.value = config.operation;
        }
        return draft;
      }).toList(growable: false),
    );
  }

  List<TableSchemaEntity> get summarySourceTableOptions {
    return existingTableSchemas
        .where((TableSchemaEntity s) => s.tableKind != TableKind.summary)
        .toList(growable: false);
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
    final int index = summaryColumns.indexWhere((SummaryColumnDraft c) => c.id == id);
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
  }

  void addAffectingColumnRule(String affectingId) {
    final int index = affectingTables.indexWhere(
      (AffectingTableDraft a) => a.id == affectingId,
    );
    if (index < 0) {
      return;
    }
    affectingTables[index].rules.add(AffectingColumnRuleDraft(id: _uuid.v4()));
  }

  void removeAffectingColumnRule(String affectingId, String ruleId) {
    final int index = affectingTables.indexWhere(
      (AffectingTableDraft a) => a.id == affectingId,
    );
    if (index < 0) {
      return;
    }
    final AffectingTableDraft target = affectingTables[index];
    final int ruleIndex = target.rules.indexWhere(
      (AffectingColumnRuleDraft rule) => rule.id == ruleId,
    );
    if (ruleIndex < 0) {
      return;
    }
    final AffectingColumnRuleDraft removed = target.rules.removeAt(ruleIndex);
    removed.dispose();
  }

  bool get showAddColumnButton {
    final TableListDesignLayout? d = persistedListDesign;
    return d == TableListDesignLayout.standard ||
        d == TableListDesignLayout.product;
  }

  bool canRemoveColumn(EditColumnDraft column) {
    final TableListDesignLayout? d = persistedListDesign;
    if (d == TableListDesignLayout.contact) {
      return false;
    }
    if (d == TableListDesignLayout.standard &&
        CreateTableController.isStandardCoreId(column.id)) {
      return false;
    }
    if (d == TableListDesignLayout.product) {
      if (CreateTableController.isProductCoreId(column.id)) {
        return false;
      }
      return true;
    }
    return columns.length > 1;
  }

  bool canEditColumnType(EditColumnDraft column) {
    final TableListDesignLayout? d = persistedListDesign;
    if (d == TableListDesignLayout.contact) {
      return false;
    }
    if (d == TableListDesignLayout.standard &&
        column.id == CreateTableController.idStandardAvatar) {
      return false;
    }
    if (d == TableListDesignLayout.product &&
        CreateTableController.isProductCoreId(column.id)) {
      return false;
    }
    return true;
  }

  void addColumn() {
    final EditColumnDraft draft = EditColumnDraft(id: _uuid.v4());
    columns.add(draft);
    expandedColumnId.value = draft.id;
    _syncReadOnlyDraftsWithColumns();
  }

  Future<void> refreshRows() => _loadRows();

  Future<void> saveRow({
    String? rowId,
    required Map<String, dynamic> values,
  }) async {
    final TableSchemaEntity? schema = _schema;
    if (schema == null) {
      return;
    }
    final String savedRowId = rowId ?? _uuid.v4();
    await _saveRow(
      TableRowEntity(
        id: savedRowId,
        tableId: schema.id,
        values: values,
      ),
    );
    await _evaluateNotificationRulesForRow(
      tableId: schema.id,
      rowId: savedRowId,
    );
    await _loadRows();
  }

  Future<void> deleteRowById(String rowId) async {
    await _deleteRow(rowId);
    await _loadRows();
  }

  static void _scheduleDisposeFormControllers({
    required TextEditingController tableName,
    required TextEditingController description,
    required List<EditColumnDraft> drafts,
  }) {
    void disposeAll() {
      try {
        tableName.dispose();
      } catch (_) {
        /* already disposed */
      }
      try {
        description.dispose();
      } catch (_) {
        /* already disposed */
      }
      for (final EditColumnDraft column in drafts) {
        try {
          column.dispose();
        } catch (_) {
          /* already disposed */
        }
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) => disposeAll());
    });
  }

  static void _scheduleDisposeReadOnlyDraftControllers({
    required List<EditReadOnlyRowDraft> rows,
    required List<EditReadOnlyCellDraft> mappingCells,
  }) {
    void disposeAll() {
      for (final EditReadOnlyRowDraft row in rows) {
        try {
          row.dispose();
        } catch (_) {
          /* already disposed */
        }
      }
      for (final EditReadOnlyCellDraft cell in mappingCells) {
        try {
          cell.dispose();
        } catch (_) {
          /* already disposed */
        }
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) => disposeAll());
    });
  }

  void reorderColumns(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= columns.length ||
        newIndex < 0 ||
        newIndex >= columns.length) {
      return;
    }
    final EditColumnDraft moved = columns.removeAt(oldIndex);
    columns.insert(newIndex, moved);
  }

  void removeColumn(String id) {
    final int index = columns.indexWhere((EditColumnDraft c) => c.id == id);
    if (index < 0) {
      return;
    }
    final EditColumnDraft target = columns[index];
    if (!canRemoveColumn(target)) {
      showAppSnackbar('Validation', 'This column cannot be removed');
      return;
    }
    final EditColumnDraft removed = columns.removeAt(index);
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
    _syncReadOnlyDraftsWithColumns();
  }

  void _bootstrapReadOnlyDraftsFromRows() {
    final List<EditReadOnlyRowDraft> previousRows = readOnlyRowsDrafts.toList(
      growable: false,
    );
    readOnlyRowsDrafts.clear();
    if (previousRows.isNotEmpty) {
      _scheduleDisposeReadOnlyRows(previousRows);
    }
    for (final TableRowEntity row in rows) {
      final EditReadOnlyRowDraft draft = EditReadOnlyRowDraft(id: row.id);
      for (final EditColumnDraft col in columns) {
        final EditReadOnlyCellDraft cell = EditReadOnlyCellDraft();
        _hydrateReadOnlyCellFromStoredValue(cell, col.id, row.values[col.id]);
        draft.cells[col.id] = cell;
      }
      readOnlyRowsDrafts.add(draft);
    }
    _syncReadOnlyDraftsWithColumns();
  }

  void _hydrateReadOnlyCellFromStoredValue(
    EditReadOnlyCellDraft cell,
    String columnId,
    dynamic rawStored,
  ) {
    if (rawStored is Map) {
      final Map<String, dynamic> map = rawStored.cast<String, dynamic>();
      final String type = (map['type'] ?? '').toString().trim().toLowerCase();
      if (type == 'formula') {
        final String expression = (map['expression'] ?? '').toString().trim();
        cell.source.value = EditReadOnlyValueSource.formula;
        cell.formulaInputMode.value = FormulaInputMode.textEditor;
        cell.formulaTextController.text = expression;
        cell.formulaController.text = expression;
        return;
      }
      if (type == 'lookup' || type == 'auto') {
        cell.source.value = EditReadOnlyValueSource.auto;
        cell.sourceTableId.value = map['sourceTableId']?.toString();
        cell.sourceColumnId.value = map['sourceColumnId']?.toString();
        return;
      }
      if (type == 'manual') {
        cell.source.value = EditReadOnlyValueSource.manual;
        cell.manualController.text = (map['value'] ?? '').toString();
        return;
      }
    }
    final String storedValue = (rawStored ?? '').toString();
    if (_isStoredReadOnlyFormulaExpression(storedValue, columnId)) {
      cell.source.value = EditReadOnlyValueSource.formula;
      cell.formulaInputMode.value = FormulaInputMode.textEditor;
      cell.formulaTextController.text = storedValue;
      cell.formulaController.text = storedValue;
      return;
    }
    cell.source.value = EditReadOnlyValueSource.manual;
    cell.manualController.text = storedValue;
  }

  bool _isStoredReadOnlyFormulaExpression(String rawValue, String columnId) {
    final String candidate = rawValue.trim();
    if (candidate.isEmpty) {
      return false;
    }
    if (!_looksLikeFormulaExpression(candidate)) {
      return false;
    }
    return TableFormulaValidator.validate(
          formula: candidate,
          currentColumnId: columnId,
          siblingColumns: allColumnsAsNameDrafts(),
          existingTables: _formulaSchemaCache,
        ) ==
        null;
  }

  bool _looksLikeFormulaExpression(String expression) {
    final String upper = expression.toUpperCase();
    if (upper.startsWith('IF(') ||
        upper.startsWith('LOOKUP(') ||
        upper.startsWith('SUM(') ||
        upper.startsWith('COUNT(') ||
        upper.startsWith('AVG(')) {
      return true;
    }
    return expression.contains('(') ||
        expression.contains(')') ||
        expression.contains('.') ||
        expression.contains('+') ||
        expression.contains('-') ||
        expression.contains('*') ||
        expression.contains('/') ||
        expression.contains('>') ||
        expression.contains('<') ||
        expression.contains('!=');
  }

  void _syncReadOnlyDraftsWithColumns() {
    final Set<String> colIds = columns.map((EditColumnDraft c) => c.id).toSet();
    for (final EditReadOnlyRowDraft row in readOnlyRowsDrafts) {
      final List<String> stale = row.cells.keys
          .where((String id) => !colIds.contains(id))
          .toList(growable: false);
      for (final String id in stale) {
        final EditReadOnlyCellDraft? removed = row.cells.remove(id);
        if (removed != null) {
          _disposeReadOnlyCellLater(removed);
        }
      }
      for (final EditColumnDraft c in columns) {
        row.cells.putIfAbsent(c.id, () => EditReadOnlyCellDraft());
      }
    }
    final List<String> staleMap = readOnlyPopulateMapping.cells.keys
        .where((String id) => !colIds.contains(id))
        .toList(growable: false);
    for (final String id in staleMap) {
      final EditReadOnlyCellDraft? removed = readOnlyPopulateMapping.cells
          .remove(id);
      if (removed != null) {
        _disposeReadOnlyCellLater(removed);
      }
    }
    for (final EditColumnDraft c in columns) {
      readOnlyPopulateMapping.cells.putIfAbsent(
        c.id,
        () => EditReadOnlyCellDraft(),
      );
    }
  }

  void addReadOnlyDraftRow() {
    final EditReadOnlyRowDraft row = EditReadOnlyRowDraft(id: _uuid.v4());
    for (final EditColumnDraft c in columns) {
      row.cells[c.id] = EditReadOnlyCellDraft();
    }
    readOnlyRowsDrafts.add(row);
  }

  void removeReadOnlyDraftRow(String rowId) {
    final int ix = readOnlyRowsDrafts.indexWhere((r) => r.id == rowId);
    if (ix < 0) return;
    final EditReadOnlyRowDraft removed = readOnlyRowsDrafts.removeAt(ix);
    _disposeReadOnlyRowLater(removed);
  }

  void _disposeReadOnlyCellLater(EditReadOnlyCellDraft cell) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          cell.dispose();
        } catch (_) {
          /* already disposed */
        }
      });
    });
  }

  void _disposeReadOnlyRowLater(EditReadOnlyRowDraft row) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          row.dispose();
        } catch (_) {
          /* already disposed */
        }
      });
    });
  }

  static void _scheduleDisposeReadOnlyRows(List<EditReadOnlyRowDraft> rows) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final EditReadOnlyRowDraft row in rows) {
          try {
            row.dispose();
          } catch (_) {
            /* already disposed */
          }
        }
      });
    });
  }

  void setReadOnlyPopulationMode(EditReadOnlyRowPopulationMode mode) {
    readOnlyPopulationMode.value = mode;
    if (mode == EditReadOnlyRowPopulationMode.manual) {
      readOnlyGeneratedPreview.clear();
    }
  }

  Future<void> regenerateReadOnlyPreview() async {
    readOnlyGeneratedPreview.assignAll(await _buildGeneratedRowsFromMapping());
  }

  Future<void> applyReadOnlyRowsData() async {
    await _persistReadOnlyRowsData(
      showSuccessMessage: true,
      rehydrateDrafts: true,
    );
  }

  Future<void> _persistReadOnlyRowsData({
    required bool showSuccessMessage,
    required bool rehydrateDrafts,
  }) async {
    // Avoid keyboard-state assertions when tearing down active text fields.
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(Duration.zero);
    final TableSchemaEntity? schema = _schema;
    if (schema == null) return;
    final List<Map<String, dynamic>> generated =
        readOnlyPopulationMode.value == EditReadOnlyRowPopulationMode.sourceMap
            ? await _buildGeneratedRowsFromMapping()
            : _manualRowsToValues();
    final List<TableRowEntity> currentRows = await _getRows(schema.id);
    for (final TableRowEntity r in currentRows) {
      await _deleteRow(r.id);
    }
    for (final Map<String, dynamic> values in generated) {
      final String generatedRowId = _uuid.v4();
      await _saveRow(
        TableRowEntity(id: generatedRowId, tableId: schema.id, values: values),
      );
      await _evaluateNotificationRulesForRow(
        tableId: schema.id,
        rowId: generatedRowId,
      );
    }
    await _loadRows();
    if (rehydrateDrafts) {
      _bootstrapReadOnlyDraftsFromRows();
    }
    if (showSuccessMessage) {
      showAppSnackbar('Rows', 'Read-only rows updated');
    }
  }

  Future<void> _evaluateNotificationRulesForRow({
    required String tableId,
    required String rowId,
  }) async {
    try {
      await NotificationRuntimeService.evaluateRulesForRowChange(
        tableId: tableId,
        rowId: rowId,
      );
    } catch (_) {
      // Best-effort only; row edits must never fail because notifications fail.
    }
  }

  List<Map<String, dynamic>> _manualRowsToValues() {
    final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];
    for (final EditReadOnlyRowDraft row in readOnlyRowsDrafts) {
      final Map<String, dynamic> values = <String, dynamic>{};
      for (final EditColumnDraft column in columns) {
        final EditReadOnlyCellDraft? cell = row.cells[column.id];
        if (cell == null) continue;
        switch (cell.source.value) {
          case EditReadOnlyValueSource.manual:
            values[column.id] = <String, dynamic>{
              'type': 'manual',
              'value': cell.manualController.text.trim(),
            };
            break;
          case EditReadOnlyValueSource.formula:
            final String formula = _composeCellFormula(cell, column.id);
            values[column.id] = <String, dynamic>{
              'type': 'formula',
              'expression': formula,
            };
            break;
          case EditReadOnlyValueSource.auto:
            values[column.id] = <String, dynamic>{
              'type': 'lookup',
              'sourceTableId': cell.sourceTableId.value,
              'sourceColumnId': cell.sourceColumnId.value,
            };
            break;
        }
      }
      out.add(values);
    }
    return out;
  }

  String _composeCellFormula(EditReadOnlyCellDraft cell, String columnId) {
    if (cell.formulaInputMode.value == FormulaInputMode.textEditor) {
      return cell.formulaTextController.text.trim();
    }
    if (cell.guided.guidedFormulaKind.value != null) {
      return cell.guided
              .composeGuidedFormula(
                _formulaSchemaCache,
                siblingColumnsExcluding(columnId),
                columnId,
                allColumnsAsNameDrafts(),
              )
              ?.trim() ??
          '';
    }
    return cell.formulaController.text.trim();
  }

  Future<List<Map<String, dynamic>>> _buildGeneratedRowsFromMapping() async {
    final String? keyTableId = readOnlyPopulateMapping.uniqueKeyTableId.value;
    final String? keyColumnId = readOnlyPopulateMapping.uniqueKeyColumnId.value;
    if (keyTableId == null || keyColumnId == null) {
      return const <Map<String, dynamic>>[];
    }
    final List<TableSchemaEntity> schemas = _formulaSchemaCache;
    final Map<String, TableSchemaEntity> schemaById =
        <String, TableSchemaEntity>{
          for (final TableSchemaEntity s in schemas) s.id: s,
        };
    final Map<String, List<TableRowEntity>> rowsByTable =
        <String, List<TableRowEntity>>{};
    for (final TableSchemaEntity s in schemas) {
      rowsByTable[s.id] = await _getRows(s.id);
    }
    final TableSchemaEntity? keySchema = schemaById[keyTableId];
    if (keySchema == null) return const <Map<String, dynamic>>[];
    final List<TableRowEntity> keyRows =
        rowsByTable[keyTableId] ?? const <TableRowEntity>[];
    final Set<String> seen = <String>{};
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
      if (keyValue.isEmpty || seen.contains(keyValue)) continue;
      seen.add(keyValue);
      final Map<String, dynamic> rowValues = <String, dynamic>{};
      for (final EditColumnDraft targetColumn in columns) {
        final EditReadOnlyCellDraft cell =
            readOnlyPopulateMapping.cells[targetColumn.id] ??
            EditReadOnlyCellDraft();
        switch (cell.source.value) {
          case EditReadOnlyValueSource.manual:
            rowValues[targetColumn.id] = <String, dynamic>{
              'type': 'manual',
              'value': cell.manualController.text.trim(),
            };
            break;
          case EditReadOnlyValueSource.formula:
            final String formula = _composeCellFormula(cell, targetColumn.id);
            rowValues[targetColumn.id] = <String, dynamic>{
              'type': 'formula',
              'expression': formula,
            };
            break;
          case EditReadOnlyValueSource.auto:
            final String? srcTableId = cell.sourceTableId.value;
            final String? srcColId = cell.sourceColumnId.value;
            rowValues[targetColumn.id] = <String, dynamic>{
              'type': 'lookup',
              'sourceTableId': srcTableId,
              'sourceColumnId': srcColId,
            };
            break;
        }
      }
      generated.add(rowValues);
    }
    return generated;
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

  void onFormulaTextEditorInteraction(String columnId) {
    formulaBuilderFieldErrors.removeWhere(
      (String k, String v) => k.startsWith('$columnId|'),
    );
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

  void onFormulaInputModeChanged(String columnId) {
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

  void clearFormulaErrorsForKey(String key) {
    formulaFieldErrors.remove(key);
    formulaBuilderFieldErrors.removeWhere(
      (String k, String v) => k.startsWith('$key|'),
    );
    formulaFieldErrors.refresh();
    formulaBuilderFieldErrors.refresh();
    formulaErrorsVersion.value++;
  }

  EditReadOnlyCellDraft? _readOnlyCellByFormulaKey(String key) {
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
    for (final EditReadOnlyRowDraft row in readOnlyRowsDrafts) {
      if (row.id == rowId) {
        return row.cells[colId];
      }
    }
    return null;
  }

  String? _readOnlyFormulaCurrentColumnId(String key) {
    if (key.startsWith('map:')) {
      return key.substring(4);
    }
    if (!key.startsWith('readonly:')) {
      return null;
    }
    final String rest = key.substring('readonly:'.length);
    final int sep = rest.indexOf(':');
    if (sep < 0) {
      return null;
    }
    return rest.substring(sep + 1);
  }

  void _applyLiveReadOnlyFormulaValidation(String formulaKey) {
    final EditReadOnlyCellDraft? cell = _readOnlyCellByFormulaKey(formulaKey);
    final String? currentColumnId = _readOnlyFormulaCurrentColumnId(formulaKey);
    if (cell == null || currentColumnId == null) {
      return;
    }
    if (cell.source.value != EditReadOnlyValueSource.formula) {
      clearFormulaErrorsForKey(formulaKey);
      return;
    }
    final List<ColumnNameDraft> names = allColumnsAsNameDrafts();
    if (cell.formulaInputMode.value == FormulaInputMode.textEditor) {
      formulaBuilderFieldErrors.removeWhere(
        (String k, String v) => k.startsWith('$formulaKey|'),
      );
      final String typed = cell.formulaTextController.text.trim();
      if (typed.isEmpty) {
        formulaFieldErrors[formulaKey] = TableFormulaValidator.errRequired;
        return;
      }
      final String? msg = TableFormulaValidator.validate(
        formula: typed,
        currentColumnId: currentColumnId,
        siblingColumns: names,
        existingTables: _formulaSchemaCache,
      );
      if (msg != null) {
        formulaFieldErrors[formulaKey] = msg;
      } else {
        formulaFieldErrors.remove(formulaKey);
      }
      return;
    }
    if (cell.guided.guidedFormulaKind.value == null) {
      formulaFieldErrors.remove(formulaKey);
      return;
    }
    final Map<String, String> guidedErrors = cell.guided.validateGuided(
      _formulaSchemaCache,
      siblingColumnsExcluding(currentColumnId),
      currentColumnId,
      formulaColumnNames: names,
    );
    for (final MapEntry<String, String> entry in guidedErrors.entries) {
      formulaBuilderFieldErrors['$formulaKey|${entry.key}'] = entry.value;
    }
    if (guidedErrors.isEmpty) {
      final String? composed = cell.guided.composeGuidedFormula(
        _formulaSchemaCache,
        siblingColumnsExcluding(currentColumnId),
        currentColumnId,
        names,
      );
      if (composed == null || composed.isEmpty) {
        formulaFieldErrors[formulaKey] = TableFormulaValidator.errRequired;
      } else {
        final String? msg = TableFormulaValidator.validate(
          formula: composed,
          currentColumnId: currentColumnId,
          siblingColumns: names,
          existingTables: _formulaSchemaCache,
        );
        if (msg != null) {
          formulaFieldErrors[formulaKey] = msg;
        } else {
          formulaFieldErrors.remove(formulaKey);
        }
      }
    } else {
      formulaFieldErrors.remove(formulaKey);
    }
  }

  void _applyLiveFormulaValidationForColumn(String columnId) {
    final int ix = columns.indexWhere((EditColumnDraft c) => c.id == columnId);
    if (ix < 0) {
      return;
    }
    final EditColumnDraft col = columns[ix];
    if (col.type.value != TableColumnType.formula) {
      return;
    }
    final List<ColumnNameDraft> names = allColumnsAsNameDrafts();
    if (col.formulaInputMode.value == FormulaInputMode.textEditor) {
      formulaBuilderFieldErrors.removeWhere(
        (String k, String v) => k.startsWith('$columnId|'),
      );
      final String typed = col.formulaTextController.text.trim();
      if (typed.isEmpty) {
        formulaFieldErrors[columnId] = TableFormulaValidator.errRequired;
      } else {
        final String? msg = TableFormulaValidator.validate(
          formula: typed,
          currentColumnId: columnId,
          siblingColumns: names,
          existingTables: _formulaSchemaCache,
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
    final List<GuidedFormulaColumnLike> sibs = siblingColumnsExcluding(
      columnId,
    );
    final Map<String, String> guidedErrors = col.guided.validateGuided(
      _formulaSchemaCache,
      sibs,
      col.id,
      formulaColumnNames: names,
    );
    for (final MapEntry<String, String> e in guidedErrors.entries) {
      formulaBuilderFieldErrors['$columnId|${e.key}'] = e.value;
    }
    if (guidedErrors.isEmpty) {
      final String? composed = col.guided.composeGuidedFormula(
        _formulaSchemaCache,
        sibs,
        col.id,
        names,
      );
      if (composed == null || composed.isEmpty) {
        formulaFieldErrors[columnId] = TableFormulaValidator.errRequired;
      } else {
        final String? msg = TableFormulaValidator.validate(
          formula: composed,
          currentColumnId: columnId,
          siblingColumns: names,
          existingTables: _formulaSchemaCache,
        );
        if (msg != null) {
          formulaFieldErrors[columnId] = msg;
        } else {
          formulaFieldErrors.remove(columnId);
        }
      }
      return;
    }
    formulaFieldErrors.remove(columnId);
  }

  void onColumnDataTypeChanged(
    String columnId,
    TableColumnType previous,
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
    final int ix = columns.indexWhere((EditColumnDraft c) => c.id == columnId);
    if (ix < 0) {
      return;
    }
    if (previous != next &&
        (previous == TableColumnType.formula ||
            next == TableColumnType.formula)) {
      columns[ix].guided.clearGuidedFormulaBuilder();
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

  @override
  List<GuidedFormulaColumnLike> siblingColumnsExcluding(String columnId) {
    return <GuidedFormulaColumnLike>[
      for (final EditColumnDraft c in columns)
        if (c.id != columnId) c,
    ];
  }

  @override
  List<ColumnNameDraft> allColumnsAsNameDrafts() {
    return columns
        .map(
          (EditColumnDraft c) =>
              ColumnNameDraft(id: c.id, name: c.nameController.text),
        )
        .toList(growable: false);
  }

  @override
  String tableDisplayLabel(TableSchemaEntity schema) {
    String pageName = schema.pageId;
    for (final PageOption p in pageOptions) {
      if (p.id == schema.pageId) {
        final String n = p.name.trim();
        pageName = n.isEmpty ? schema.pageId : n;
        break;
      }
    }
    if (pageName == schema.pageId && Get.isRegistered<HomeController>()) {
      final HomeController home = Get.find<HomeController>();
      for (final page in home.pages) {
        if (page.id == schema.pageId) {
          final String n = page.name.trim();
          pageName = n.isEmpty ? schema.pageId : n;
          break;
        }
      }
    }
    return '${schema.name} ($pageName)';
  }

  void _syncGuidedFormulasToControllers() {
    final List<ColumnNameDraft> nameDrafts = allColumnsAsNameDrafts();
    for (final EditColumnDraft c in columns) {
      if (c.type.value != TableColumnType.formula) {
        continue;
      }
      if (c.formulaInputMode.value != FormulaInputMode.guided ||
          c.guided.guidedFormulaKind.value == null) {
        continue;
      }
      final List<GuidedFormulaColumnLike> sibs = siblingColumnsExcluding(c.id);
      final String? composed = c.guided.composeGuidedFormula(
        _formulaSchemaCache,
        sibs,
        c.id,
        nameDrafts,
      );
      if (composed != null && composed.isNotEmpty) {
        c.formulaController.text = composed;
      }
    }
  }

  Future<bool> _validateFormulaColumnsForSave() async {
    await _refreshGuidedSchemas();
    formulaFieldErrors.clear();
    for (final EditColumnDraft col in columns) {
      if (col.type.value != TableColumnType.formula) {
        continue;
      }
      formulaBuilderFieldErrors.removeWhere(
        (String k, String v) => k.startsWith('${col.id}|'),
      );
    }
    formulaFieldErrors.refresh();
    formulaBuilderFieldErrors.refresh();
    bool ok = true;
    final List<ColumnNameDraft> nameSiblings = columns
        .map(
          (EditColumnDraft c) =>
              ColumnNameDraft(id: c.id, name: c.nameController.text),
        )
        .toList(growable: false);
    for (final EditColumnDraft col in columns.toList(growable: false)) {
      if (col.type.value != TableColumnType.formula) {
        continue;
      }
      if (col.formulaInputMode.value == FormulaInputMode.textEditor) {
        final String typed = col.formulaTextController.text.trim();
        if (typed.isEmpty) {
          formulaFieldErrors[col.id] = TableFormulaValidator.errRequired;
          ok = false;
          continue;
        }
        final String? msg = TableFormulaValidator.validate(
          formula: typed,
          currentColumnId: col.id,
          siblingColumns: nameSiblings,
          existingTables: _formulaSchemaCache,
        );
        if (msg != null) {
          formulaFieldErrors[col.id] = msg;
          ok = false;
        }
        continue;
      }
      final List<GuidedFormulaColumnLike> sibs = siblingColumnsExcluding(
        col.id,
      );
      if (col.guided.guidedFormulaKind.value != null) {
        final Map<String, String> guidedErrors = col.guided.validateGuided(
          _formulaSchemaCache,
          sibs,
          col.id,
          formulaColumnNames: nameSiblings,
        );
        if (guidedErrors.isNotEmpty) {
          for (final MapEntry<String, String> e in guidedErrors.entries) {
            formulaBuilderFieldErrors['${col.id}|${e.key}'] = e.value;
          }
          ok = false;
          continue;
        }
        final String? composed = col.guided.composeGuidedFormula(
          _formulaSchemaCache,
          sibs,
          col.id,
          nameSiblings,
        );
        if (composed == null || composed.isEmpty) {
          formulaFieldErrors[col.id] = TableFormulaValidator.errRequired;
          ok = false;
          continue;
        }
        final String? msg = TableFormulaValidator.validate(
          formula: composed,
          currentColumnId: col.id,
          siblingColumns: nameSiblings,
          existingTables: _formulaSchemaCache,
        );
        if (msg != null) {
          formulaFieldErrors[col.id] = msg;
          ok = false;
        }
      } else {
        final String trimmed = col.formulaController.text.trim();
        if (trimmed.isEmpty) {
          formulaFieldErrors[col.id] = TableFormulaValidator.errRequired;
          ok = false;
          continue;
        }
        final String? msg = TableFormulaValidator.validate(
          formula: trimmed,
          currentColumnId: col.id,
          siblingColumns: nameSiblings,
          existingTables: _formulaSchemaCache,
        );
        if (msg != null) {
          formulaFieldErrors[col.id] = msg;
          ok = false;
        }
      }
    }
    formulaFieldErrors.refresh();
    formulaBuilderFieldErrors.refresh();
    formulaErrorsVersion.value++;
    formulaPreviewVersion.value++;
    return ok;
  }

  Future<bool> _validateReadOnlyRowFormulasForSave() async {
    if (!isReadOnlyTable) {
      return true;
    }
    formulaFieldErrors.removeWhere(
      (String key, String _) =>
          key.startsWith('readonly:') || key.startsWith('map:'),
    );
    formulaBuilderFieldErrors.removeWhere(
      (String key, String _) =>
          key.startsWith('readonly:') || key.startsWith('map:'),
    );
    bool ok = true;
    final List<ColumnNameDraft> names = allColumnsAsNameDrafts();
    final Map<String, EditColumnDraft> colsById = <String, EditColumnDraft>{
      for (final EditColumnDraft c in columns) c.id: c,
    };

    bool validateCell({
      required EditReadOnlyCellDraft cell,
      required String formulaKey,
      required String columnId,
    }) {
      if (cell.source.value != EditReadOnlyValueSource.formula) {
        return true;
      }
      formulaBuilderFieldErrors.removeWhere(
        (String key, String _) => key.startsWith('$formulaKey|'),
      );
      if (cell.formulaInputMode.value == FormulaInputMode.textEditor) {
        final String text = cell.formulaTextController.text.trim();
        if (text.isEmpty) {
          formulaFieldErrors[formulaKey] = TableFormulaValidator.errRequired;
          return false;
        }
        final String? msg = TableFormulaValidator.validate(
          formula: text,
          currentColumnId: columnId,
          siblingColumns: names,
          existingTables: _formulaSchemaCache,
        );
        if (msg != null) {
          formulaFieldErrors[formulaKey] = msg;
          return false;
        }
        return true;
      }
      if (cell.guided.guidedFormulaKind.value == null) {
        final String text = cell.formulaController.text.trim();
        if (text.isEmpty) {
          formulaFieldErrors[formulaKey] = TableFormulaValidator.errRequired;
          return false;
        }
        final String? msg = TableFormulaValidator.validate(
          formula: text,
          currentColumnId: columnId,
          siblingColumns: names,
          existingTables: _formulaSchemaCache,
        );
        if (msg != null) {
          formulaFieldErrors[formulaKey] = msg;
          return false;
        }
        return true;
      }
      final Map<String, String> guidedErrors = cell.guided.validateGuided(
        _formulaSchemaCache,
        siblingColumnsExcluding(columnId),
        columnId,
        formulaColumnNames: names,
      );
      if (guidedErrors.isNotEmpty) {
        for (final MapEntry<String, String> entry in guidedErrors.entries) {
          formulaBuilderFieldErrors['$formulaKey|${entry.key}'] = entry.value;
        }
        return false;
      }
      final String? composed = cell.guided.composeGuidedFormula(
        _formulaSchemaCache,
        siblingColumnsExcluding(columnId),
        columnId,
        names,
      );
      if (composed == null || composed.isEmpty) {
        formulaFieldErrors[formulaKey] = TableFormulaValidator.errRequired;
        return false;
      }
      final String? msg = TableFormulaValidator.validate(
        formula: composed,
        currentColumnId: columnId,
        siblingColumns: names,
        existingTables: _formulaSchemaCache,
      );
      if (msg != null) {
        formulaFieldErrors[formulaKey] = msg;
        return false;
      }
      return true;
    }

    if (readOnlyPopulationMode.value == EditReadOnlyRowPopulationMode.manual) {
      for (final EditReadOnlyRowDraft row in readOnlyRowsDrafts) {
        for (final MapEntry<String, EditReadOnlyCellDraft> entry
            in row.cells.entries) {
          if (!colsById.containsKey(entry.key)) {
            continue;
          }
          final String formulaKey = 'readonly:${row.id}:${entry.key}';
          if (!validateCell(
            cell: entry.value,
            formulaKey: formulaKey,
            columnId: entry.key,
          )) {
            ok = false;
          }
        }
      }
    } else {
      for (final MapEntry<String, EditReadOnlyCellDraft> entry
          in readOnlyPopulateMapping.cells.entries) {
        if (!colsById.containsKey(entry.key)) {
          continue;
        }
        final String formulaKey = 'map:${entry.key}';
        if (!validateCell(
          cell: entry.value,
          formulaKey: formulaKey,
          columnId: entry.key,
        )) {
          ok = false;
        }
      }
    }

    formulaFieldErrors.refresh();
    formulaBuilderFieldErrors.refresh();
    formulaErrorsVersion.value++;
    formulaPreviewVersion.value++;
    return ok;
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
                  : _formulaSchemaCache,
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

  String? _validateEditColumns() {
    dropdownFieldErrors.clear();
    dropdownFieldErrors.refresh();
    if (columns.isEmpty) {
      return 'At least one column is required';
    }
    for (final EditColumnDraft col in columns) {
      if (col.nameController.text.trim().isEmpty) {
        return 'Every column needs a name';
      }
    }
    for (final EditColumnDraft col in columns) {
      if (canEditColumnType(col) == false) {
        continue;
      }
    }
    final TableListDesignLayout? d = persistedListDesign;
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
    for (final EditColumnDraft col in columns) {
      if (col.type.value != TableColumnType.dropdown) {
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
    for (final EditColumnDraft col in columns) {
      if (col.type.value != TableColumnType.text) {
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
                : _formulaSchemaCache,
      );
      if (formulaError != null) {
        return formulaError;
      }
    }
    return null;
  }

  String? validateForStep(int step) {
    if (_schema == null) {
      return null;
    }
    final bool isSummary = _schema!.tableKind == TableKind.summary;
    final bool crudStd = isCrudStandardTable;
    switch (step) {
      case 0:
        if (isSummary) {
          if (summarySourceTableOptions.isEmpty) {
            return 'Create a standard table with data before editing this summary table';
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
        if (isSummary) {
          return null;
        }
        return _validateEditColumns();
      case 4:
        if (isSummary) {
          return (tableNameController.text.trim().isEmpty
                  ? 'Table name is required'
                  : null) ??
              (selectedPageId.value == null ? 'Assign page is required' : null);
        }
        return _validateCustomValidationRules();
      case 5:
        if (crudStd) {
          return _validateAffectingTables();
        }
        return _validateEditColumns() ??
            (tableNameController.text.trim().isEmpty
                ? 'Table name is required'
                : null) ??
            (selectedPageId.value == null ? 'Assign page is required' : null) ??
            (persistedListDesign == null ? 'Table layout is missing' : null);
      case 6:
        if (isSummary || crudStd) {
          return (tableNameController.text.trim().isEmpty
                  ? 'Table name is required'
                  : null) ??
              (selectedPageId.value == null ? 'Assign page is required' : null);
        }
        return null;
      case 7:
        if (isSummary) {
          return (tableNameController.text.trim().isEmpty
                  ? 'Table name is required'
                  : null) ??
              (selectedPageId.value == null ? 'Assign page is required' : null);
        }
        return _validateEditColumns() ??
            (tableNameController.text.trim().isEmpty
                ? 'Table name is required'
                : null) ??
            (selectedPageId.value == null ? 'Assign page is required' : null) ??
            (persistedListDesign == null ? 'Table layout is missing' : null);
      default:
        return null;
    }
  }

  Future<void> goNext() async {
    final int step = currentStep.value;
    final bool isSummary = _schema?.tableKind == TableKind.summary;
    if (step == 3 && !isSummary) {
      final bool formulasOk = await _validateFormulaColumnsForSave();
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

  void jumpToStep(int step) {
    final int boundedStep = step.clamp(0, lastStepIndex);
    if (boundedStep == currentStep.value) {
      return;
    }
    currentStep.value = boundedStep;
  }

  Future<void> saveChanges() async {
    // Flush active key/focus events before mutating view state/navigation.
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(Duration.zero);
    final TableSchemaEntity? current = _schema;
    if (current == null) {
      return;
    }
    final String tableName = tableNameController.text.trim();
    if (tableName.isEmpty) {
      showAppSnackbar('Validation', 'Table name is required');
      return;
    }
    final bool isSummary = current.tableKind == TableKind.summary;
    if (!isSummary) {
      if (columns.isEmpty) {
        showAppSnackbar('Validation', 'At least one column is required');
        return;
      }
      for (final EditColumnDraft column in columns) {
        if (column.nameController.text.trim().isEmpty) {
          showAppSnackbar('Validation', 'Column name is required');
          return;
        }
      }
    }

    dropdownFieldErrors.clear();
    for (final EditColumnDraft col in isSummary ? const <EditColumnDraft>[] : columns) {
      if (col.type.value != TableColumnType.dropdown) {
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
      showAppSnackbar('Validation', dropdownFieldErrors.values.first);
      return;
    }
    for (final EditColumnDraft col in isSummary ? const <EditColumnDraft>[] : columns) {
      if (col.type.value != TableColumnType.text) {
        continue;
      }
      if (col.textValidationKind.value == TableTextValidationKind.custom) {
        final String p = col.textCustomRegexController.text.trim();
        if (p.isEmpty) {
          showAppSnackbar(
            'Validation',
            'Enter a regular expression for column "${col.nameController.text}"',
          );
          return;
        }
        try {
          RegExp(p);
        } catch (_) {
          showAppSnackbar(
            'Validation',
            'Invalid regular expression for column "${col.nameController.text}"',
          );
          return;
        }
      }
    }

    if (!isSummary && !await _validateFormulaColumnsForSave()) {
      showAppSnackbar('Validation', 'Fix formula errors before saving');
      return;
    }
    if (!await _validateReadOnlyRowFormulasForSave()) {
      showAppSnackbar(
        'Validation',
        'Fix invalid row formulas before saving read-only rows',
      );
      return;
    }
    final String? affectingErr = _validateAffectingTables();
    if (affectingErr != null) {
      showAppSnackbar('Validation', affectingErr);
      return;
    }
    if (selectedPageId.value == null) {
      showAppSnackbar('Validation', 'Assign page is required');
      return;
    }

    TableInventoryDeductionConfig? invCfg;
    if (inventoryDeductionEnabled.value) {
      final String? st = invStockTableId.value;
      final String? sm = invStockMatchColumnId.value;
      final String? sq = invStockQuantityColumnId.value;
      final String? lp = invLineProductColumnId.value;
      final String? lq = invLineQuantityColumnId.value;
      if (st == null ||
          st.isEmpty ||
          sm == null ||
          sm.isEmpty ||
          sq == null ||
          sq.isEmpty ||
          lp == null ||
          lp.isEmpty ||
          lq == null ||
          lq.isEmpty) {
        showAppSnackbar(
          'Validation',
          'Stock deduction is on: fill all five fields or turn it off.',
        );
        return;
      }
      invCfg = TableInventoryDeductionConfig(
        stockTableId: st,
        stockMatchColumnId: sm,
        stockQuantityColumnId: sq,
        lineProductColumnId: lp,
        lineQuantityColumnId: lq,
      );
    }

    isSaving.value = true;
    try {
      _syncGuidedFormulasToControllers();
      final TableMode savedMode = mode.value;
      TableSummaryConfig? summaryCfg = current.summaryConfig;
      final List<TableColumnEntity> updatedColumns;
      if (isSummary) {
        if (summaryColumns.isEmpty) {
          showAppSnackbar('Validation', 'Add at least one summary column');
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
        updatedColumns = summaryColumns
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
      } else {
        updatedColumns = columns
            .map((EditColumnDraft c) => c.toEntityForMode(savedMode))
            .toList(growable: false);
      }
      final bool swipe = swipeToDelete.value;
      final String pageId = selectedPageId.value ?? current.pageId;
      final String desc = descriptionController.text.trim();
      final List<TableAffectingConfig> affectingCfg =
          _buildAffectingTablesConfig();
      final List<TableValidationRule> validationRulesCfg =
          isSummary
              ? const <TableValidationRule>[]
              : validationRules
                  .map((TableValidationRuleDraft draft) => draft.toEntity())
                  .toList(growable: false);
      await _save(
        TableSchemaEntity(
          id: current.id,
          pageId: pageId,
          name: tableName,
          description: desc,
          mode: savedMode,
          layoutType: swipe ? TableLayoutType.swipe : TableLayoutType.vertical,
          listDesignLayout: current.listDesignLayout,
          swipeToDelete: swipe,
          productDisplayMode: current.productDisplayMode,
          tableKind: current.tableKind,
          summaryConfig: summaryCfg,
          inventoryDeduction: invCfg,
          affectingTables: affectingCfg,
          validationRules: validationRulesCfg,
          searchEnabled: searchEnabled.value,
          dataLoadingMode: dataLoadingMode.value,
          pageSize: pageSize.value,
          lazyInitialLoad: lazyInitialLoad.value,
          columns: updatedColumns,
        ),
      );
      _schema = TableSchemaEntity(
        id: current.id,
        pageId: pageId,
        name: tableName,
        description: desc,
        mode: savedMode,
        layoutType: swipe ? TableLayoutType.swipe : TableLayoutType.vertical,
        listDesignLayout: current.listDesignLayout,
        swipeToDelete: swipe,
        productDisplayMode: current.productDisplayMode,
        tableKind: current.tableKind,
        summaryConfig: summaryCfg,
        inventoryDeduction: invCfg,
        affectingTables: affectingCfg,
        validationRules: validationRulesCfg,
        searchEnabled: searchEnabled.value,
        dataLoadingMode: dataLoadingMode.value,
        pageSize: pageSize.value,
        lazyInitialLoad: lazyInitialLoad.value,
        columns: updatedColumns,
      );
      if (savedMode == TableMode.readOnly &&
          current.tableKind != TableKind.summary) {
        await _persistReadOnlyRowsData(
          showSuccessMessage: false,
          rehydrateDrafts: false,
        );
      }
      isSaving.value = false;
      showAppSnackbar('$tableName Table', 'Changes saved');
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (isClosed) {
        return;
      }
      final String targetPageId = pageId;
      Get.until((Route route) => route.settings.name == AppRoutes.home);
      if (Get.isRegistered<HomeController>()) {
        final HomeController home = Get.find<HomeController>();
        await home.loadPages(preferredPageId: targetPageId);
        home.refreshBuilderPageContent();
      } else {
        await Get.offAllNamed<void>(
          AppRoutes.home,
          arguments: <String, dynamic>{'selectedPageId': targetPageId},
        );
      }
    } catch (e, _) {
      isSaving.value = false;
      showAppSnackbar(
        'Save failed',
        e.toString(),
        duration: const Duration(seconds: 5),
      );
    }
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

class EditColumnDraft implements GuidedFormulaColumnLike {
  EditColumnDraft({required this.id});

  factory EditColumnDraft.fromEntity(TableColumnEntity entity) {
    final EditColumnDraft draft = EditColumnDraft(id: entity.id);
    draft.nameController.text = entity.name;
    final bool hasFormulaPayload =
        (entity.formula ?? '').trim().isNotEmpty ||
        (entity.formulaDefinition != null &&
            entity.formulaDefinition!.isNotEmpty);
    draft.type.value =
        hasFormulaPayload ? TableColumnType.formula : entity.type;
    draft.includeInCreate.value = entity.includeInCreateForm;
    draft.includeInEdit.value = entity.includeInEditForm;
    draft.isRequired.value = entity.isRequired;
    draft.isUnique.value = entity.isUnique;
    draft.patternController.text = entity.pattern ?? '';
    draft.formulaController.text = entity.formula ?? '';
    draft.formulaTextController.text = entity.formula ?? '';
    draft.dropdownSourceKind.value = entity.dropdownSourceKind;
    draft.dropdownSourceTableId.value = entity.dropdownSourceTableId;
    draft.dropdownSourceColumnId.value = entity.dropdownSourceColumnId;
    draft.dropdownOptionsController.text =
        DropdownColumnOptions.manualOptionsToMultiline(entity.dropdownOptions);
    draft.textHintController.text = entity.textFieldHint ?? '';
    final String? pfx = entity.textPrefixIconKey;
    draft.textPrefixIconKey.value = pfx != null && pfx.isNotEmpty ? pfx : null;
    final String? sfx = entity.textSuffixIconKey;
    draft.textSuffixIconKey.value = sfx != null && sfx.isNotEmpty ? sfx : null;
    draft.textValidationKind.value = entity.textValidationKind;
    draft.textCustomRegexController.text = entity.textCustomRegex ?? '';
    draft.dateDefaultToday.value = entity.dateDefaultToday;
    draft.numberHintController.text = entity.numberFieldHint ?? '';
    draft.numberPrefixController.text = entity.numberPrefixText ?? '';
    draft.numberSuffixController.text = entity.numberSuffixText ?? '';
    draft.numberMinController.text =
        entity.numberMinValue == null ? '' : entity.numberMinValue.toString();
    draft.numberMaxController.text =
        entity.numberMaxValue == null ? '' : entity.numberMaxValue.toString();
    draft.numberAllowDecimals.value = entity.numberAllowDecimals;
    draft.numberIntegerOnly.value = entity.numberIntegerOnly;
    draft.numberPositiveOnly.value = entity.numberPositiveOnly;
    draft.numberShowStepper.value = entity.numberShowStepper;
    draft.numberStepController.text = entity.numberStepValue.toString();
    final String? numberPrefixIcon = entity.numberPrefixIconKey;
    final String? numberSuffixIcon = entity.numberSuffixIconKey;
    draft.numberPrefixIconKey.value =
        numberPrefixIcon != null && numberPrefixIcon.isNotEmpty
            ? numberPrefixIcon
            : null;
    draft.numberSuffixIconKey.value =
        numberSuffixIcon != null && numberSuffixIcon.isNotEmpty
            ? numberSuffixIcon
            : null;
    draft.numberPrefixUseIcon.value = draft.numberPrefixIconKey.value != null;
    draft.numberSuffixUseIcon.value = draft.numberSuffixIconKey.value != null;
    if (entity.type == TableColumnType.formula &&
        entity.formulaDefinition != null &&
        entity.formulaDefinition!.isNotEmpty) {
      draft.guided.importDefinitionTree(entity.formulaDefinition);
      draft.formulaInputMode.value = FormulaInputMode.guided;
    } else if (entity.type == TableColumnType.formula &&
        (entity.formula ?? '').trim().isNotEmpty) {
      draft.formulaInputMode.value = FormulaInputMode.textEditor;
    }
    return draft;
  }

  @override
  final String id;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController patternController = TextEditingController();
  final TextEditingController textHintController = TextEditingController();
  final TextEditingController textCustomRegexController =
      TextEditingController();
  final TextEditingController numberHintController = TextEditingController();
  final TextEditingController numberPrefixController = TextEditingController();
  final TextEditingController numberSuffixController = TextEditingController();
  final TextEditingController numberMinController = TextEditingController();
  final TextEditingController numberMaxController = TextEditingController();
  final TextEditingController numberStepController = TextEditingController(
    text: '1',
  );
  final TextEditingController formulaController = TextEditingController();
  final TextEditingController formulaTextController = TextEditingController();
  final Rx<FormulaInputMode> formulaInputMode = FormulaInputMode.guided.obs;
  final TextEditingController dropdownOptionsController =
      TextEditingController();
  final Rx<TableColumnType> type = TableColumnType.text.obs;
  final RxBool includeInCreate = true.obs;
  final RxBool includeInEdit = true.obs;
  final RxBool isRequired = false.obs;
  final RxBool isUnique = false.obs;

  final Rx<TableColumnDropdownSourceKind> dropdownSourceKind =
      TableColumnDropdownSourceKind.manual.obs;
  final RxnString dropdownSourceTableId = RxnString();
  final RxnString dropdownSourceColumnId = RxnString();

  final Rx<TableTextValidationKind> textValidationKind =
      TableTextValidationKind.none.obs;
  final RxBool dateDefaultToday = false.obs;
  final RxnString textPrefixIconKey = RxnString();
  final RxnString textSuffixIconKey = RxnString();
  final RxBool numberAllowDecimals = true.obs;
  final RxBool numberIntegerOnly = false.obs;
  final RxBool numberPositiveOnly = false.obs;
  final RxBool numberShowStepper = false.obs;
  final RxBool numberPrefixUseIcon = false.obs;
  final RxBool numberSuffixUseIcon = false.obs;
  final RxnString numberPrefixIconKey = RxnString();
  final RxnString numberSuffixIconKey = RxnString();

  final GuidedFormulaDraftState guided = GuidedFormulaDraftState();

  void resetTextFieldConfiguration() {
    textHintController.clear();
    textCustomRegexController.clear();
    textValidationKind.value = TableTextValidationKind.none;
    textPrefixIconKey.value = null;
    textSuffixIconKey.value = null;
  }

  void resetNumberFieldConfiguration() {
    numberHintController.clear();
    numberPrefixController.clear();
    numberSuffixController.clear();
    numberMinController.clear();
    numberMaxController.clear();
    numberStepController.text = '1';
    numberAllowDecimals.value = true;
    numberIntegerOnly.value = false;
    numberPositiveOnly.value = false;
    numberShowStepper.value = false;
    numberPrefixUseIcon.value = false;
    numberSuffixUseIcon.value = false;
    numberPrefixIconKey.value = null;
    numberSuffixIconKey.value = null;
  }

  void resetDropdownConfiguration() {
    dropdownSourceKind.value = TableColumnDropdownSourceKind.manual;
    dropdownSourceTableId.value = null;
    dropdownSourceColumnId.value = null;
    dropdownOptionsController.clear();
  }

  List<String> _dropdownOptionsForEntity() {
    if (type.value != TableColumnType.dropdown) {
      return const <String>[];
    }
    if (dropdownSourceKind.value == TableColumnDropdownSourceKind.table) {
      return const <String>[];
    }
    return DropdownColumnOptions.manualOptionsFromMultiline(
      dropdownOptionsController.text,
    );
  }

  TableColumnEntity toEntity() {
    return TableColumnEntity(
      id: id,
      name: nameController.text.trim(),
      type: type.value,
      includeInCreateForm: includeInCreate.value,
      includeInEditForm: includeInEdit.value,
      isRequired: isRequired.value,
      isUnique: isUnique.value,
      pattern:
          patternController.text.trim().isEmpty
              ? null
              : patternController.text.trim(),
      formula:
          type.value == TableColumnType.formula
              ? (formulaInputMode.value == FormulaInputMode.textEditor
                  ? (formulaTextController.text.trim().isEmpty
                      ? null
                      : formulaTextController.text.trim())
                  : (formulaController.text.trim().isEmpty
                      ? null
                      : formulaController.text.trim()))
              : null,
      formulaDefinition:
          type.value == TableColumnType.formula
              ? (formulaInputMode.value == FormulaInputMode.guided
                  ? guided.exportDefinitionTree()
                  : null)
              : null,
      dropdownOptions: _dropdownOptionsForEntity(),
      dropdownSourceKind:
          type.value == TableColumnType.dropdown
              ? dropdownSourceKind.value
              : TableColumnDropdownSourceKind.manual,
      dropdownSourceTableId:
          type.value == TableColumnType.dropdown &&
                  dropdownSourceKind.value ==
                      TableColumnDropdownSourceKind.table
              ? dropdownSourceTableId.value
              : null,
      dropdownSourceColumnId:
          type.value == TableColumnType.dropdown &&
                  dropdownSourceKind.value ==
                      TableColumnDropdownSourceKind.table
              ? dropdownSourceColumnId.value
              : null,
      textFieldHint:
          type.value == TableColumnType.text
              ? (textHintController.text.trim().isEmpty
                  ? null
                  : textHintController.text.trim())
              : null,
      textPrefixIconKey:
          type.value == TableColumnType.text ? textPrefixIconKey.value : null,
      textSuffixIconKey:
          type.value == TableColumnType.text ? textSuffixIconKey.value : null,
      textValidationKind:
          type.value == TableColumnType.text
              ? textValidationKind.value
              : TableTextValidationKind.none,
      textCustomRegex:
          type.value == TableColumnType.text &&
                  textValidationKind.value == TableTextValidationKind.custom
              ? (textCustomRegexController.text.trim().isEmpty
                  ? null
                  : textCustomRegexController.text.trim())
              : null,
      dateDefaultToday:
          type.value == TableColumnType.date ? dateDefaultToday.value : false,
      numberFieldHint:
          type.value == TableColumnType.number
              ? (numberHintController.text.trim().isEmpty
                  ? null
                  : numberHintController.text.trim())
              : null,
      numberPrefixText:
          type.value == TableColumnType.number
              ? (numberPrefixUseIcon.value
                  ? null
                  : (numberPrefixController.text.trim().isEmpty
                      ? null
                      : numberPrefixController.text.trim()))
              : null,
      numberSuffixText:
          type.value == TableColumnType.number
              ? (numberSuffixUseIcon.value
                  ? null
                  : (numberSuffixController.text.trim().isEmpty
                      ? null
                      : numberSuffixController.text.trim()))
              : null,
      numberPrefixIconKey:
          type.value == TableColumnType.number && numberPrefixUseIcon.value
              ? numberPrefixIconKey.value
              : null,
      numberSuffixIconKey:
          type.value == TableColumnType.number && numberSuffixUseIcon.value
              ? numberSuffixIconKey.value
              : null,
      numberMinValue:
          type.value == TableColumnType.number
              ? double.tryParse(numberMinController.text.trim())
              : null,
      numberMaxValue:
          type.value == TableColumnType.number
              ? double.tryParse(numberMaxController.text.trim())
              : null,
      numberAllowDecimals:
          type.value == TableColumnType.number
              ? numberAllowDecimals.value
              : true,
      numberIntegerOnly:
          type.value == TableColumnType.number
              ? numberIntegerOnly.value
              : false,
      numberPositiveOnly:
          type.value == TableColumnType.number
              ? numberPositiveOnly.value
              : false,
      numberShowStepper:
          type.value == TableColumnType.number
              ? numberShowStepper.value
              : false,
      numberStepValue:
          type.value == TableColumnType.number
              ? (double.tryParse(numberStepController.text.trim()) ?? 1)
              : 1,
    );
  }

  TableColumnEntity toEntityForMode(TableMode tableMode) {
    final TableColumnEntity e = toEntity();
    if (tableMode == TableMode.readOnly) {
      return TableColumnEntity(
        id: e.id,
        name: e.name,
        type: e.type,
        includeInCreateForm: false,
        includeInEditForm: false,
        isRequired: e.isRequired,
        isUnique: e.isUnique,
        pattern: e.pattern,
        formula: e.formula,
        formulaDefinition: e.formulaDefinition,
        dropdownOptions: e.dropdownOptions,
        dropdownSourceKind: e.dropdownSourceKind,
        dropdownSourceTableId: e.dropdownSourceTableId,
        dropdownSourceColumnId: e.dropdownSourceColumnId,
        textFieldHint: e.textFieldHint,
        textPrefixIconKey: e.textPrefixIconKey,
        textSuffixIconKey: e.textSuffixIconKey,
        textValidationKind: e.textValidationKind,
        textCustomRegex: e.textCustomRegex,
        dateDefaultToday: e.dateDefaultToday,
        numberFieldHint: e.numberFieldHint,
        numberPrefixText: e.numberPrefixText,
        numberSuffixText: e.numberSuffixText,
        numberPrefixIconKey: e.numberPrefixIconKey,
        numberSuffixIconKey: e.numberSuffixIconKey,
        numberMinValue: e.numberMinValue,
        numberMaxValue: e.numberMaxValue,
        numberAllowDecimals: e.numberAllowDecimals,
        numberIntegerOnly: e.numberIntegerOnly,
        numberPositiveOnly: e.numberPositiveOnly,
        numberShowStepper: e.numberShowStepper,
        numberStepValue: e.numberStepValue,
      );
    }
    return e;
  }

  void dispose() {
    nameController.dispose();
    patternController.dispose();
    textHintController.dispose();
    textCustomRegexController.dispose();
    numberHintController.dispose();
    numberPrefixController.dispose();
    numberSuffixController.dispose();
    numberMinController.dispose();
    numberMaxController.dispose();
    numberStepController.dispose();
    formulaController.dispose();
    formulaTextController.dispose();
    dropdownOptionsController.dispose();
    guided.dispose();
  }
}

enum EditReadOnlyValueSource { manual, formula, auto }

enum EditReadOnlyRowPopulationMode { manual, sourceMap }

class EditReadOnlyCellDraft {
  final Rx<EditReadOnlyValueSource> source = EditReadOnlyValueSource.manual.obs;
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

class EditReadOnlyRowDraft {
  EditReadOnlyRowDraft({required this.id});

  final String id;
  final Map<String, EditReadOnlyCellDraft> cells =
      <String, EditReadOnlyCellDraft>{};

  void dispose() {
    for (final EditReadOnlyCellDraft cell in cells.values) {
      cell.dispose();
    }
  }
}

class EditReadOnlyPopulateMappingDraft {
  final Map<String, EditReadOnlyCellDraft> cells =
      <String, EditReadOnlyCellDraft>{};
  final RxnString uniqueKeyTableId = RxnString();
  final RxnString uniqueKeyColumnId = RxnString();

  void dispose() {
    for (final EditReadOnlyCellDraft cell in cells.values) {
      cell.dispose();
    }
  }
}
