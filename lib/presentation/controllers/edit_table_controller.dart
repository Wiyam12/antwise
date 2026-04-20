import 'package:antwise/core/app_snackbar.dart';
import 'package:antwise/domain/dropdown/dropdown_column_options.dart';
import 'package:antwise/domain/entities/table_column_dropdown_source.dart';
import 'package:antwise/domain/entities/table_column_entity.dart';
import 'package:antwise/domain/entities/table_column_type.dart';
import 'package:antwise/domain/entities/table_data_loading_mode.dart';
import 'package:antwise/domain/entities/table_inventory_deduction_config.dart';
import 'package:antwise/domain/entities/table_kind.dart';
import 'package:antwise/domain/entities/table_layout_type.dart';
import 'package:antwise/domain/entities/table_mode.dart';
import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/domain/usecases/get_all_table_schemas_usecase.dart';
import 'package:antwise/domain/usecases/get_table_schema_by_id_usecase.dart';
import 'package:antwise/domain/usecases/save_table_schema_usecase.dart';
import 'package:antwise/domain/validation/table_formula_validator.dart';
import 'package:antwise/presentation/controllers/home_controller.dart';
import 'package:antwise/presentation/models/guided_formula_draft_state.dart';
import 'package:antwise/presentation/models/guided_formula_host.dart';
import 'package:antwise/presentation/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

class EditTableController extends GetxController implements GuidedFormulaHost {
  EditTableController(this._getById, this._save, this._getAllSchemas);

  final GetTableSchemaByIdUseCase _getById;
  final SaveTableSchemaUseCase _save;
  final GetAllTableSchemasUseCase _getAllSchemas;

  final TextEditingController tableNameController = TextEditingController();
  final RxList<EditColumnDraft> columns = <EditColumnDraft>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool isSaving = false.obs;
  final RxBool swipeToDelete = false.obs;
  final Rx<TableMode> mode = TableMode.crud.obs;
  final RxBool searchEnabled = false.obs;
  final Rx<TableDataLoadingMode> dataLoadingMode =
      TableDataLoadingMode.lazy.obs;
  final RxInt pageSize = 10.obs;
  final RxInt lazyInitialLoad = 5.obs;
  final Uuid _uuid = const Uuid();
  TableSchemaEntity? _schema;

  /// Id of the table being edited (excluded from "other table" dropdown sources).
  String? get editingTableId => _schema?.id;
  bool get isSummaryTable => _schema?.tableKind == TableKind.summary;

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
        .where(
          (TableColumnEntity c) =>
              c.type == TableColumnType.number ||
              c.type == TableColumnType.currency,
        )
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
        .where(
          (EditColumnDraft c) =>
              c.type.value == TableColumnType.number ||
              c.type.value == TableColumnType.currency,
        )
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
    _scheduleDisposeFormControllers(
      tableName: tableNameController,
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
    tableNameController.text = schema.name;
    mode.value = schema.mode;
    swipeToDelete.value = schema.swipeToDelete ||
        schema.layoutType == TableLayoutType.swipe;
    searchEnabled.value = schema.searchEnabled;
    dataLoadingMode.value = schema.dataLoadingMode;
    pageSize.value = schema.pageSize;
    lazyInitialLoad.value = schema.lazyInitialLoad;
    columns.assignAll(
      schema.columns
          .map((TableColumnEntity c) => EditColumnDraft.fromEntity(c))
          .toList(growable: false),
    );
    final TableInventoryDeductionConfig? inv = schema.inventoryDeduction;
    inventoryDeductionEnabled.value = inv != null;
    invStockTableId.value = inv?.stockTableId;
    invStockMatchColumnId.value = inv?.stockMatchColumnId;
    invStockQuantityColumnId.value = inv?.stockQuantityColumnId;
    invLineProductColumnId.value = inv?.lineProductColumnId;
    invLineQuantityColumnId.value = inv?.lineQuantityColumnId;
    await _refreshGuidedSchemas();
    isLoading.value = false;
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

  void setMode(TableMode value) => mode.value = value;
  void setSearchEnabled(bool value) => searchEnabled.value = value;
  void setDataLoadingMode(TableDataLoadingMode value) =>
      dataLoadingMode.value = value;
  void setPageSize(int value) => pageSize.value = value.clamp(1, 200);
  void setLazyInitialLoad(int value) =>
      lazyInitialLoad.value = value.clamp(1, 200);

  void addColumn() {
    columns.add(EditColumnDraft(id: _uuid.v4()));
  }

  static void _scheduleDisposeFormControllers({
    required TextEditingController tableName,
    required List<EditColumnDraft> drafts,
  }) {
    void disposeAll() {
      try {
        tableName.dispose();
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

  void reorderColumns(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final EditColumnDraft moved = columns.removeAt(oldIndex);
    columns.insert(newIndex, moved);
  }

  Future<void> removeColumn(int index) async {
    final bool? confirm = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Delete column?'),
        content: Text('Remove "${columns[index].nameController.text.trim()}"'),
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
    final EditColumnDraft removed = columns.removeAt(index);
    dropdownFieldErrors.remove(removed.id);
    dropdownFieldErrors.refresh();
    removed.dispose();
  }

  void onGuidedFormulaInteraction(String columnId) {
    formulaBuilderFieldErrors.removeWhere(
      (String k, String v) => k.startsWith('$columnId|'),
    );
    formulaFieldErrors.remove(columnId);
    _applyLiveGuidedValidationForColumn(columnId);
    formulaBuilderFieldErrors.refresh();
    formulaFieldErrors.refresh();
    formulaPreviewVersion.value++;
    formulaErrorsVersion.value++;
  }

  void _applyLiveGuidedValidationForColumn(String columnId) {
    final int ix = columns.indexWhere((EditColumnDraft c) => c.id == columnId);
    if (ix < 0) {
      return;
    }
    final EditColumnDraft col = columns[ix];
    if (col.type.value != TableColumnType.formula) {
      return;
    }
    if (col.guided.guidedFormulaKind.value == null) {
      return;
    }
    final List<GuidedFormulaColumnLike> sibs = siblingColumnsExcluding(columnId);
    final List<ColumnNameDraft> names = allColumnsAsNameDrafts();
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
        }
      }
    }
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
    }
    if (next != TableColumnType.dropdown) {
      columns[ix].resetDropdownConfiguration();
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
    if (Get.isRegistered<HomeController>()) {
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
      if (c.guided.guidedFormulaKind.value == null) {
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
      final List<GuidedFormulaColumnLike> sibs = siblingColumnsExcluding(col.id);
      if (col.guided.guidedFormulaKind.value != null) {
        final Map<String, String> guidedErrors =
            col.guided.validateGuided(
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

  Future<void> saveChanges() async {
    final TableSchemaEntity? current = _schema;
    if (current == null) {
      return;
    }
    final String tableName = tableNameController.text.trim();
    if (tableName.isEmpty) {
      showAppSnackbar('Validation', 'Table name is required');
      return;
    }
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

    dropdownFieldErrors.clear();
    for (final EditColumnDraft col in columns) {
      if (col.type.value != TableColumnType.dropdown) {
        continue;
      }
      if (col.dropdownSourceKind.value ==
          TableColumnDropdownSourceKind.manual) {
        final List<String> opts = DropdownColumnOptions.manualOptionsFromMultiline(
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
      showAppSnackbar(
        'Validation',
        dropdownFieldErrors.values.first,
      );
      return;
    }

    if (!await _validateFormulaColumnsForSave()) {
      showAppSnackbar('Validation', 'Fix formula errors before saving');
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
      final List<TableColumnEntity> updatedColumns = columns
          .map((EditColumnDraft c) => c.toEntityForMode(savedMode))
          .toList(growable: false);
      final bool swipe = swipeToDelete.value;
      await _save(
        TableSchemaEntity(
          id: current.id,
          pageId: current.pageId,
          name: tableName,
          description: current.description,
          mode: savedMode,
          layoutType: swipe ? TableLayoutType.swipe : TableLayoutType.vertical,
          listDesignLayout: current.listDesignLayout,
          swipeToDelete: swipe,
          productDisplayMode: current.productDisplayMode,
          tableKind: current.tableKind,
          summaryConfig: current.summaryConfig,
          inventoryDeduction: invCfg,
          searchEnabled: searchEnabled.value,
          dataLoadingMode: dataLoadingMode.value,
          pageSize: pageSize.value,
          lazyInitialLoad: lazyInitialLoad.value,
          columns: updatedColumns,
        ),
      );
      _schema = TableSchemaEntity(
        id: current.id,
        pageId: current.pageId,
        name: tableName,
        description: current.description,
        mode: savedMode,
        layoutType: swipe ? TableLayoutType.swipe : TableLayoutType.vertical,
        listDesignLayout: current.listDesignLayout,
        swipeToDelete: swipe,
        productDisplayMode: current.productDisplayMode,
        tableKind: current.tableKind,
        summaryConfig: current.summaryConfig,
        inventoryDeduction: invCfg,
        searchEnabled: searchEnabled.value,
        dataLoadingMode: dataLoadingMode.value,
        pageSize: pageSize.value,
        lazyInitialLoad: lazyInitialLoad.value,
        columns: updatedColumns,
      );
      isSaving.value = false;
      showAppSnackbar('Table', 'Changes saved');
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (isClosed) {
        return;
      }
      final String targetPageId = current.pageId;
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

class EditColumnDraft implements GuidedFormulaColumnLike {
  EditColumnDraft({required this.id});

  factory EditColumnDraft.fromEntity(TableColumnEntity entity) {
    final EditColumnDraft draft = EditColumnDraft(id: entity.id);
    draft.nameController.text = entity.name;
    draft.type.value = entity.type;
    draft.includeInCreate.value = entity.includeInCreateForm;
    draft.includeInEdit.value = entity.includeInEditForm;
    draft.isRequired.value = entity.isRequired;
    draft.isUnique.value = entity.isUnique;
    draft.patternController.text = entity.pattern ?? '';
    draft.formulaController.text = entity.formula ?? '';
    draft.dropdownSourceKind.value = entity.dropdownSourceKind;
    draft.dropdownSourceTableId.value = entity.dropdownSourceTableId;
    draft.dropdownSourceColumnId.value = entity.dropdownSourceColumnId;
    draft.dropdownOptionsController.text =
        DropdownColumnOptions.manualOptionsToMultiline(entity.dropdownOptions);
    if (entity.type == TableColumnType.formula &&
        entity.formulaDefinition != null &&
        entity.formulaDefinition!.isNotEmpty) {
      draft.guided.importDefinitionTree(entity.formulaDefinition);
    }
    return draft;
  }

  @override
  final String id;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController patternController = TextEditingController();
  final TextEditingController formulaController = TextEditingController();
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

  final GuidedFormulaDraftState guided = GuidedFormulaDraftState();

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
      pattern: patternController.text.trim().isEmpty
          ? null
          : patternController.text.trim(),
      formula: formulaController.text.trim().isEmpty
          ? null
          : formulaController.text.trim(),
      formulaDefinition:
          type.value == TableColumnType.formula
              ? guided.exportDefinitionTree()
              : null,
      dropdownOptions: _dropdownOptionsForEntity(),
      dropdownSourceKind: type.value == TableColumnType.dropdown
          ? dropdownSourceKind.value
          : TableColumnDropdownSourceKind.manual,
      dropdownSourceTableId: type.value == TableColumnType.dropdown &&
              dropdownSourceKind.value == TableColumnDropdownSourceKind.table
          ? dropdownSourceTableId.value
          : null,
      dropdownSourceColumnId: type.value == TableColumnType.dropdown &&
              dropdownSourceKind.value == TableColumnDropdownSourceKind.table
          ? dropdownSourceColumnId.value
          : null,
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
      );
    }
    return e;
  }

  void dispose() {
    nameController.dispose();
    patternController.dispose();
    formulaController.dispose();
    dropdownOptionsController.dispose();
    guided.dispose();
  }
}
