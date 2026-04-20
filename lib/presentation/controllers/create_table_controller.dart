import 'package:antwise/core/app_snackbar.dart';
import 'package:antwise/domain/entities/builder_widget_entity.dart';
import 'package:antwise/domain/entities/product_display_mode.dart';
import 'package:antwise/domain/dropdown/dropdown_column_options.dart';
import 'package:antwise/domain/entities/table_column_dropdown_source.dart';
import 'package:antwise/domain/entities/table_column_entity.dart';
import 'package:antwise/domain/entities/table_column_type.dart';
import 'package:antwise/domain/entities/table_data_loading_mode.dart';
import 'package:antwise/domain/entities/table_kind.dart';
import 'package:antwise/domain/entities/table_layout_type.dart';
import 'package:antwise/domain/entities/table_list_design_layout.dart';
import 'package:antwise/domain/entities/table_mode.dart';
import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/domain/entities/table_summary_config.dart';
import 'package:antwise/domain/usecases/get_all_table_schemas_usecase.dart';
import 'package:antwise/domain/usecases/get_builder_pages_usecase.dart';
import 'package:antwise/domain/usecases/save_builder_widget_usecase.dart';
import 'package:antwise/domain/usecases/save_table_schema_usecase.dart';
import 'package:antwise/domain/validation/table_formula_validator.dart';
import 'package:antwise/presentation/models/column_draft.dart';
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
  );

  final GetBuilderPagesUseCase _getPages;
  final SaveTableSchemaUseCase _saveTableSchema;
  final SaveBuilderWidgetUseCase _saveWidget;
  final GetAllTableSchemasUseCase _getAllSchemas;

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
        visualLayout1: 2.20,
        visualLayout2: 1.20,
        visualLayout3: 2.20,
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

  final RxInt currentStep = 0.obs;
  final Rxn<TableListDesignLayout> selectedDesign =
      Rxn<TableListDesignLayout>();

  /// Selected template key (`layout_1` … `layout_3`); see [visualLayoutKeysOrdered] for on-screen order.
  final RxnString selectedVisualLayoutKey = RxnString();
  final RxBool swipeToDelete = false.obs;
  final Rx<ProductDisplayMode> productDisplayMode = ProductDisplayMode.list.obs;
  final RxList<ColumnDraft> columns = <ColumnDraft>[].obs;
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
    super.onClose();
  }

  Future<void> _loadPages() async {
    isLoadingPages.value = true;
    try {
      final pages = await _getPages();
      final opts = pages
          .where((p) => !p.isDeleted)
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

  void setMode(TableMode value) => mode.value = value;

  void setTableKind(TableKind value) {
    if (tableKind.value == value) {
      return;
    }
    _clearFormulaFieldErrors();
    tableKind.value = value;
    if (value == TableKind.summary) {
      mode.value = TableMode.readOnly;
      swipeToDelete.value = false;
      _disposeAllColumns();
      selectedDesign.value = TableListDesignLayout.standard;
      selectedVisualLayoutKey.value = visualLayoutKeyForDesign(
        TableListDesignLayout.standard,
      );
      summarySourceTableId.value = null;
      summaryGroupByColumnId.value = null;
      summaryAggregateColumnId.value = null;
      searchEnabled.value = false;
      dataLoadingMode.value = TableDataLoadingMode.lazy;
      pageSize.value = 10;
      lazyInitialLoad.value = 5;
    } else {
      summarySourceTableId.value = null;
      summaryGroupByColumnId.value = null;
      summaryAggregateColumnId.value = null;
      selectedDesign.value = null;
      selectedVisualLayoutKey.value = null;
      _disposeAllColumns();
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
              c.type == TableColumnType.number ||
              c.type == TableColumnType.currency,
        )
        .toList(growable: false);
  }

  void onSummarySourceTableChanged(String? id) {
    summarySourceTableId.value = id;
    summaryGroupByColumnId.value = null;
    summaryAggregateColumnId.value = null;
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
  }

  void setSwipeToDelete(bool value) => swipeToDelete.value = value;

  void setProductDisplayMode(ProductDisplayMode value) =>
      productDisplayMode.value = value;

  void _disposeAllColumns() {
    for (final ColumnDraft col in columns) {
      col.dispose();
    }
    columns.clear();
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
    _applyLiveGuidedValidationForColumn(columnId);
    formulaBuilderFieldErrors.refresh();
    formulaFieldErrors.refresh();
    formulaPreviewVersion.value++;
    formulaErrorsVersion.value++;
  }

  void _applyLiveGuidedValidationForColumn(String columnId) {
    final int ix = columns.indexWhere((ColumnDraft c) => c.id == columnId);
    if (ix < 0) {
      return;
    }
    final ColumnDraft col = columns[ix];
    if (_resolvedTypeForDraft(col) != TableColumnType.formula) {
      return;
    }
    if (col.guided.guidedFormulaKind.value == null) {
      return;
    }
    final List<TableSchemaEntity> schemas =
        existingTableSchemas.isNotEmpty
            ? existingTableSchemas.toList(growable: false)
            : _existingSchemasCache;
    final List<ColumnDraft> snapshot = columns.toList(growable: false);
    final List<ColumnNameDraft> names = allColumnsAsNameDrafts();
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
    final int ix = columns.indexWhere((ColumnDraft c) => c.id == columnId);
    if (ix < 0) {
      return;
    }
    if (previous != next &&
        (previous == TableColumnType.formula ||
            next == TableColumnType.formula)) {
      columns[ix].clearGuidedFormulaBuilder();
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
            initialType: TableColumnType.currency,
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
    columns.add(ColumnDraft(_uuid.v4()));
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
    return null;
  }

  String? validateForStep(int step) {
    switch (step) {
      case 0:
        if (tableKind.value == TableKind.summary) {
          if (summarySourceTableOptions.isEmpty) {
            return 'Create a standard table with data before adding a summary table';
          }
          if (summarySourceTableId.value == null) {
            return 'Select a source table';
          }
          if (summaryGroupByColumnId.value == null) {
            return 'Select a group-by column';
          }
          if (summaryAggregateColumnId.value == null) {
            return 'Select a column to total (sum)';
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
    if (step >= 4) {
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

  TableColumnType _resolvedTypeForDraft(ColumnDraft c) {
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
        return TableColumnType.currency;
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

  List<TableColumnEntity> _buildSummarySchemaColumns({
    required TableColumnEntity sourceGroupColumn,
  }) {
    final String groupColId = _uuid.v4();
    final String totalColId = _uuid.v4();
    return <TableColumnEntity>[
      TableColumnEntity(
        id: groupColId,
        name: sourceGroupColumn.name,
        type: sourceGroupColumn.type,
        includeInCreateForm: false,
        includeInEditForm: false,
        isRequired: false,
        pattern: null,
        formula: null,
        formulaDefinition: null,
        dropdownOptions: List<String>.from(sourceGroupColumn.dropdownOptions),
        dropdownSourceKind: sourceGroupColumn.dropdownSourceKind,
        dropdownSourceTableId: sourceGroupColumn.dropdownSourceTableId,
        dropdownSourceColumnId: sourceGroupColumn.dropdownSourceColumnId,
      ),
      TableColumnEntity(
        id: totalColId,
        name: 'Total',
        type: TableColumnType.formula,
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
      ),
    ];
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
        .map(
          (ColumnDraft c) => TableColumnEntity(
            id: c.id,
            name: c.nameController.text.trim(),
            type: _resolvedTypeForDraft(c),
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
                _resolvedTypeForDraft(c) == TableColumnType.formula
                    ? c.composeGuidedFormula(
                      existingTableSchemas.isNotEmpty
                          ? existingTableSchemas.toList(growable: false)
                          : _existingSchemasCache,
                      colList,
                      nameDrafts,
                    )
                    : null,
            formulaDefinition:
                _resolvedTypeForDraft(c) == TableColumnType.formula
                    ? c.guided.exportDefinitionTree()
                    : null,
            dropdownOptions: _dropdownOptionsForDraft(c),
            dropdownSourceKind:
                _resolvedTypeForDraft(c) == TableColumnType.dropdown
                    ? c.dropdownSourceKind.value
                    : TableColumnDropdownSourceKind.manual,
            dropdownSourceTableId:
                _resolvedTypeForDraft(c) == TableColumnType.dropdown &&
                        c.dropdownSourceKind.value ==
                            TableColumnDropdownSourceKind.table
                    ? c.dropdownSourceTableId.value
                    : null,
            dropdownSourceColumnId:
                _resolvedTypeForDraft(c) == TableColumnType.dropdown &&
                        c.dropdownSourceKind.value ==
                            TableColumnDropdownSourceKind.table
                    ? c.dropdownSourceColumnId.value
                    : null,
          ),
        )
        .toList(growable: false);
  }

  List<String> _dropdownOptionsForDraft(ColumnDraft c) {
    if (_resolvedTypeForDraft(c) != TableColumnType.dropdown) {
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
    if (tableKind.value != TableKind.summary) {
      if (!await validateFormulaColumnsInline()) {
        currentStep.value = 2;
        return;
      }
    }
    final String? error = validateForStep(4);
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
      if (savedKind == TableKind.summary) {
        final String? sid = summarySourceTableId.value;
        final String? gid = summaryGroupByColumnId.value;
        final String? aid = summaryAggregateColumnId.value;
        final TableSchemaEntity? src = summarySourceSchema(sid);
        if (sid == null ||
            gid == null ||
            aid == null ||
            src == null ||
            src.tableKind == TableKind.summary) {
          showAppSnackbar('Validation', 'Invalid summary configuration');
          return;
        }
        TableColumnEntity? groupCol;
        TableColumnEntity? sumCol;
        for (final TableColumnEntity c in src.columns) {
          if (c.id == gid) {
            groupCol = c;
          }
          if (c.id == aid) {
            sumCol = c;
          }
        }
        if (groupCol == null || sumCol == null) {
          showAppSnackbar('Validation', 'Source columns are no longer valid');
          return;
        }
        summaryCfg = TableSummaryConfig(
          sourceTableId: src.id,
          groupByColumnId: groupCol.id,
          aggregateSourceColumnId: sumCol.id,
        );
        schemaColumns = _buildSummarySchemaColumns(sourceGroupColumn: groupCol);
        savedMode = TableMode.readOnly;
        swipe = false;
        savedDesign = TableListDesignLayout.standard;
      } else {
        summaryCfg = null;
        schemaColumns = _buildSchemaColumns();
        savedMode = mode.value;
        swipe = swipeToDelete.value;
        savedDesign = design;
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
      final String? msg = TableFormulaValidator.validate(
        formula: composed,
        currentColumnId: col.id,
        siblingColumns: siblings,
        existingTables: _existingSchemasCache,
      );
      if (msg != null) {
        formulaFieldErrors[col.id] = msg;
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
