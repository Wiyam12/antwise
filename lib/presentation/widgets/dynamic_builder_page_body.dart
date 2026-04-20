import 'dart:io';

import 'package:antwise/core/icons/app_icon_registry.dart';
import 'package:antwise/domain/entities/builder_page_entity.dart';
import 'package:antwise/domain/entities/builder_widget_entity.dart';
import 'package:antwise/domain/entities/card_widget_layout.dart';
import 'package:antwise/domain/entities/table_column_entity.dart';
import 'package:antwise/domain/entities/table_column_type.dart';
import 'package:antwise/domain/entities/product_display_mode.dart';
import 'package:antwise/domain/entities/table_data_loading_mode.dart';
import 'package:antwise/domain/entities/table_layout_type.dart';
import 'package:antwise/domain/entities/table_list_design_layout.dart';
import 'package:antwise/domain/entities/table_kind.dart';
import 'package:antwise/domain/entities/table_mode.dart';
import 'package:antwise/domain/entities/table_row_entity.dart';
import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/domain/dropdown/dropdown_column_options.dart';
import 'package:antwise/domain/summary/compute_summary_table_rows.dart';
import 'package:antwise/domain/formula/table_formula_evaluator.dart';
import 'package:antwise/domain/usecases/get_all_table_schemas_usecase.dart';
import 'package:antwise/domain/widgets/compute_card_widget_value.dart';
import 'package:antwise/domain/usecases/apply_inventory_deduction_usecase.dart';
import 'package:antwise/domain/usecases/delete_table_row_usecase.dart';
import 'package:antwise/domain/usecases/get_builder_widgets_by_page_usecase.dart';
import 'package:antwise/domain/usecases/get_table_rows_usecase.dart';
import 'package:antwise/domain/usecases/get_table_schema_by_id_usecase.dart';
import 'package:antwise/domain/usecases/get_table_schema_by_page_usecase.dart';
import 'package:antwise/domain/usecases/save_table_row_usecase.dart';
import 'package:antwise/domain/usecases/update_table_row_usecase.dart';
import 'package:antwise/presentation/bindings/builder_page_runtime_deps.dart';
import 'package:antwise/presentation/widgets/searchable_dropdown_options_field.dart';
import 'package:antwise/presentation/widgets/table_row_modal_field_helpers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Column id seeded for Contact list layout ([CreateTableController.idContactAvatar]).
const String _kContactListAvatarColumnId = 'contact_avatar';

/// Shown when a table cell has no stored value.
const String _kEmptyCellDisplay = '-';

String _tableLayoutKey(String tableId) => 'table:$tableId';
String _chartLayoutKey(String widgetId) => 'chart:$widgetId';

class DynamicBuilderPageBody extends StatefulWidget {
  const DynamicBuilderPageBody({
    super.key,
    required this.page,
    this.contentRevision = 0,
  });

  final BuilderPageEntity page;

  /// Bumps when tables/widgets are saved elsewhere so this body refetches schemas
  /// (e.g. [HomeController.refreshBuilderPageContent]).
  final int contentRevision;

  @override
  State<DynamicBuilderPageBody> createState() => _DynamicBuilderPageBodyState();
}

class _DynamicBuilderPageBodyState extends State<DynamicBuilderPageBody> {
  static const String _kTableImagesSubdir = 'antwise_table_images';

  late final GetBuilderWidgetsByPageUseCase _getWidgets = Get.find();
  late final GetTableSchemaByIdUseCase _getSchema = Get.find();
  late final GetTableSchemaByPageUseCase _getSchemaByPage = Get.find();
  late final GetTableRowsUseCase _getRows = Get.find();
  late final SaveTableRowUseCase _saveRow = Get.find();
  late final ApplyInventoryDeductionUseCase _applyInventoryDeduction =
      Get.find();
  late final UpdateTableRowUseCase _updateRow = Get.find();
  late final DeleteTableRowUseCase _deleteRow = Get.find();
  final Uuid _uuid = const Uuid();
  final ImagePicker _imagePicker = ImagePicker();

  List<TableSchemaEntity> _allSchemas = <TableSchemaEntity>[];
  List<BuilderWidgetEntity> _cardWidgets = <BuilderWidgetEntity>[];
  Map<String, BuilderWidgetEntity> _chartByLayoutKey =
      <String, BuilderWidgetEntity>{};
  List<String> _layoutOrder = <String>[];
  Map<String, TableSchemaEntity> _tableByLayoutKey =
      <String, TableSchemaEntity>{};
  Map<String, List<TableRowEntity>> _rowsByTable =
      <String, List<TableRowEntity>>{};
  final Map<String, TextEditingController> _tableSearchControllers =
      <String, TextEditingController>{};
  final Map<String, String> _tableSearchQueries = <String, String>{};
  final Map<String, int> _tableVisibleCounts = <String, int>{};
  final Map<String, int> _tableCurrentPages = <String, int>{};
  final Map<String, int> _tablePageSizes = <String, int>{};
  bool _isLoading = true;

  /// Caches [TableFormulaEvaluator.resolveRowValues] per row for list builds.
  final Map<String, Map<String, dynamic>> _resolvedRowCache =
      <String, Map<String, dynamic>>{};

  /// Current install's Application Support path (container UUID may change between debug runs).
  String? _applicationSupportPath;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant DynamicBuilderPageBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload when the page instance changes, table metadata changes (revision),
    // or widget/table order updates from settings.
    if (oldWidget.page != widget.page ||
        oldWidget.contentRevision != widget.contentRevision) {
      _load();
    }
  }

  @override
  void dispose() {
    for (final TextEditingController controller
        in _tableSearchControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    ensureBuilderPageRuntimeDependenciesRegistered();
    setState(() => _isLoading = true);
    await _ensureAppSupportPath();
    final List<BuilderWidgetEntity> widgets = await _getWidgets(widget.page.id);
    final GetAllTableSchemasUseCase getAllSchemas = Get.find();
    final List<TableSchemaEntity> allSchemas = await getAllSchemas();

    final Map<String, List<TableRowEntity>> rowsByTable =
        <String, List<TableRowEntity>>{};
    for (final TableSchemaEntity schema in allSchemas) {
      rowsByTable[schema.id] = await _getRows(schema.id);
    }

    for (final TableSchemaEntity schema in allSchemas) {
      if (schema.tableKind != TableKind.summary) {
        continue;
      }
      final String? sid = schema.summaryConfig?.sourceTableId;
      if (sid == null || sid.isEmpty) {
        rowsByTable[schema.id] = <TableRowEntity>[];
        continue;
      }
      TableSchemaEntity? source;
      for (final TableSchemaEntity s in allSchemas) {
        if (s.id == sid) {
          source = s;
          break;
        }
      }
      if (source == null) {
        rowsByTable[schema.id] = <TableRowEntity>[];
        continue;
      }
      rowsByTable[schema.id] = computeSummaryTableRows(
        summarySchema: schema,
        sourceSchema: source,
        sourceRows: rowsByTable[sid] ?? <TableRowEntity>[],
      );
    }

    final List<TableSchemaEntity> pageTableSchemas = <TableSchemaEntity>[];
    final Set<String> seenIds = <String>{};
    final Map<String, int> orderByTableId = <String, int>{};
    final Map<String, BuilderWidgetEntity> widgetByTableId =
        <String, BuilderWidgetEntity>{};
    int fallbackOrder = 100000;

    final Iterable<BuilderWidgetEntity> tableWidgets = widgets.where(
      (BuilderWidgetEntity w) => w.type == 'table',
    );
    for (final BuilderWidgetEntity widgetDef in tableWidgets) {
      final String? tableId = widgetDef.config['tableId']?.toString();
      if (tableId == null) {
        continue;
      }
      final int? incomingOrder =
          (widgetDef.config['tableOrder'] as num?)?.toInt();
      final BuilderWidgetEntity? existing = widgetByTableId[tableId];
      if (existing == null) {
        widgetByTableId[tableId] = widgetDef;
        continue;
      }
      final int? existingOrder =
          (existing.config['tableOrder'] as num?)?.toInt();
      final bool replaceBecauseOrder =
          existingOrder == null ||
          (incomingOrder != null && incomingOrder < existingOrder);
      if (replaceBecauseOrder) {
        widgetByTableId[tableId] = widgetDef;
      }
    }

    for (final MapEntry<String, BuilderWidgetEntity> entry
        in widgetByTableId.entries) {
      final TableSchemaEntity? schema = await _getSchema(entry.key);
      if (schema == null || seenIds.contains(schema.id)) {
        continue;
      }
      pageTableSchemas.add(schema);
      seenIds.add(schema.id);
      final int? explicitOrder =
          (entry.value.config['tableOrder'] as num?)?.toInt();
      orderByTableId[schema.id] = explicitOrder ?? fallbackOrder++;
    }

    final TableSchemaEntity? fallback = await _getSchemaByPage(widget.page.id);
    if (fallback != null && !seenIds.contains(fallback.id)) {
      pageTableSchemas.add(fallback);
      seenIds.add(fallback.id);
      orderByTableId[fallback.id] = fallbackOrder++;
    }

    pageTableSchemas.sort((TableSchemaEntity a, TableSchemaEntity b) {
      final int oa = orderByTableId[a.id] ?? 999999;
      final int ob = orderByTableId[b.id] ?? 999999;
      return oa.compareTo(ob);
    });

    final Iterable<BuilderWidgetEntity> cardWidgets = widgets.where(
      (BuilderWidgetEntity w) => w.type == 'card',
    );
    final List<BuilderWidgetEntity> cards = _orderCardWidgets(
      cardWidgets.toList(growable: false),
      widget.page.widgetOrder,
    );
    final List<BuilderWidgetEntity> charts = widgets
      .where((BuilderWidgetEntity w) => w.type == 'chart')
      .toList(growable: false)..sort(
      (BuilderWidgetEntity a, BuilderWidgetEntity b) =>
          _widgetDisplayOrder(a).compareTo(_widgetDisplayOrder(b)),
    );
    final Map<String, BuilderWidgetEntity> chartByKey =
        <String, BuilderWidgetEntity>{
          for (final BuilderWidgetEntity c in charts) _chartLayoutKey(c.id): c,
        };
    final Map<String, TableSchemaEntity> tableByKey =
        <String, TableSchemaEntity>{
          for (final TableSchemaEntity s in pageTableSchemas)
            _tableLayoutKey(s.id): s,
        };
    final Set<String> availableKeys = <String>{
      if (cards.isNotEmpty) 'widgets',
      ...chartByKey.keys,
      ...tableByKey.keys,
    };
    final List<String> configuredKeys = widget.page.layoutOrder;
    final List<String> resolvedOrder = <String>[];
    for (final String key in configuredKeys) {
      if (availableKeys.contains(key) && !resolvedOrder.contains(key)) {
        resolvedOrder.add(key);
      }
    }
    if (cards.isNotEmpty && !resolvedOrder.contains('widgets')) {
      resolvedOrder.add('widgets');
    }
    for (final BuilderWidgetEntity chart in charts) {
      final String key = _chartLayoutKey(chart.id);
      if (!resolvedOrder.contains(key)) {
        resolvedOrder.add(key);
      }
    }
    for (final TableSchemaEntity s in pageTableSchemas) {
      final String key = _tableLayoutKey(s.id);
      if (!resolvedOrder.contains(key)) {
        resolvedOrder.add(key);
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _resolvedRowCache.clear();
      _allSchemas = allSchemas;
      _rowsByTable = rowsByTable;
      _cardWidgets = cards;
      _chartByLayoutKey = chartByKey;
      _tableByLayoutKey = tableByKey;
      _layoutOrder = resolvedOrder;
      _syncTableViewState(pageTableSchemas);
      _isLoading = false;
    });
  }

  void _syncTableViewState(List<TableSchemaEntity> schemas) {
    final Set<String> active =
        schemas.map((TableSchemaEntity s) => s.id).toSet();
    final List<String> staleIds = _tableSearchControllers.keys
        .where((String id) => !active.contains(id))
        .toList(growable: false);
    for (final String id in staleIds) {
      _tableSearchControllers.remove(id)?.dispose();
      _tableSearchQueries.remove(id);
      _tableVisibleCounts.remove(id);
      _tableCurrentPages.remove(id);
      _tablePageSizes.remove(id);
    }
    for (final TableSchemaEntity schema in schemas) {
      _tableSearchControllers.putIfAbsent(
        schema.id,
        () => TextEditingController(text: _tableSearchQueries[schema.id] ?? ''),
      );
      _tableSearchQueries.putIfAbsent(schema.id, () => '');
      _tableVisibleCounts.putIfAbsent(schema.id, () => schema.lazyInitialLoad);
      _tableCurrentPages.putIfAbsent(schema.id, () => 1);
      _tablePageSizes.putIfAbsent(schema.id, () => schema.pageSize);
      if (_tableVisibleCounts[schema.id]! < 1) {
        _tableVisibleCounts[schema.id] = schema.lazyInitialLoad;
      }
      if (_tablePageSizes[schema.id]! < 1) {
        _tablePageSizes[schema.id] = schema.pageSize;
      }
      _tablePageSizes[schema.id] = schema.pageSize;
      if (_tableCurrentPages[schema.id]! < 1) {
        _tableCurrentPages[schema.id] = 1;
      }
    }
  }

  static int _widgetDisplayOrder(BuilderWidgetEntity w) {
    final dynamic o = w.config['widgetOrder'] ?? w.config['tableOrder'];
    if (o is num) {
      return o.toInt();
    }
    return 1 << 20;
  }

  static List<BuilderWidgetEntity> _orderCardWidgets(
    List<BuilderWidgetEntity> cards,
    List<String> configuredOrder,
  ) {
    final Map<String, BuilderWidgetEntity> byId = <String, BuilderWidgetEntity>{
      for (final BuilderWidgetEntity w in cards) w.id: w,
    };
    final List<BuilderWidgetEntity> out = <BuilderWidgetEntity>[];
    for (final String id in configuredOrder) {
      final BuilderWidgetEntity? w = byId.remove(id);
      if (w != null) {
        out.add(w);
      }
    }
    final List<BuilderWidgetEntity> rest = byId.values.toList(growable: false)
      ..sort(
        (BuilderWidgetEntity a, BuilderWidgetEntity b) =>
            _widgetDisplayOrder(a).compareTo(_widgetDisplayOrder(b)),
      );
    out.addAll(rest);
    return out;
  }

  Map<String, dynamic> _resolvedRowValues(
    TableSchemaEntity schema,
    TableRowEntity row,
  ) {
    final String cacheKey = '${schema.id}|${row.id}';
    return _resolvedRowCache.putIfAbsent(
      cacheKey,
      () => TableFormulaEvaluator.resolveRowValues(
        schema: schema,
        row: row,
        allSchemas: _allSchemas,
        rowsByTableId: _rowsByTable,
      ),
    );
  }

  String _displayCell(
    TableSchemaEntity schema,
    TableRowEntity row,
    String columnId,
  ) {
    return _resolvedRowValues(schema, row)[columnId]?.toString() ?? '';
  }

  bool _isTextLikeColumn(TableColumnType type) {
    return type == TableColumnType.text || type == TableColumnType.formula;
  }

  Future<void> _ensureAppSupportPath() async {
    _applicationSupportPath ??= p.normalize(
      (await getApplicationSupportDirectory()).path,
    );
  }

  String _toLocalFilesystemPath(String raw) {
    String s = raw.trim();
    if (s.startsWith('file:')) {
      try {
        s = Uri.parse(s).toFilePath();
      } catch (_) {}
    }
    return s;
  }

  /// Resolves a Hive-stored image reference to a concrete path for this app install.
  String _resolveImagePathForDisplay(String stored) {
    final String s = _toLocalFilesystemPath(stored).trim();
    if (s.isEmpty) {
      return s;
    }
    if (File(s).existsSync()) {
      return s;
    }
    final String? root = _applicationSupportPath;
    if (root == null || root.isEmpty) {
      return s;
    }
    if (!p.isAbsolute(s)) {
      return p.normalize(p.join(root, s));
    }
    final String norm = s.replaceAll('\\', '/');
    if (norm.contains('/$_kTableImagesSubdir/')) {
      final String relocated = p.normalize(
        p.join(root, _kTableImagesSubdir, p.basename(s)),
      );
      if (File(relocated).existsSync()) {
        return relocated;
      }
    }
    return s;
  }

  String _toRelativeImageStorageRef(
    String absoluteFilePath,
    String supportRoot,
  ) {
    final String normFile = p.normalize(absoluteFilePath);
    final String normRoot = p.normalize(supportRoot);
    if (normFile.startsWith(normRoot)) {
      return p.relative(normFile, from: normRoot).replaceAll('\\', '/');
    }
    return p
        .join(_kTableImagesSubdir, p.basename(normFile))
        .replaceAll('\\', '/');
  }

  /// Copies gallery/temp files into app support and returns a **portable** ref for Hive
  /// (`antwise_table_images/<name>`), so paths survive simulator reinstall / container changes.
  Future<String?> _persistTableImageIfNeeded(String? sourcePath) async {
    if (sourcePath == null || sourcePath.trim().isEmpty) {
      return null;
    }
    await _ensureAppSupportPath();
    final String supportRoot = _applicationSupportPath!;
    final String trimmed = _toLocalFilesystemPath(sourcePath).trim();
    final String resolved = _resolveImagePathForDisplay(trimmed);
    if (await File(resolved).exists()) {
      final String normRes = p.normalize(resolved);
      final String normRoot = p.normalize(supportRoot);
      if (normRes.startsWith(normRoot)) {
        return _toRelativeImageStorageRef(normRes, normRoot);
      }
    }

    final Directory dir = Directory(p.join(supportRoot, _kTableImagesSubdir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    String ext = p.extension(trimmed);
    if (ext.isEmpty || ext.length > 6) {
      ext = '.jpg';
    }
    final String destPath = p.join(dir.path, '${_uuid.v4()}$ext');
    try {
      final File src = File(trimmed);
      if (await src.exists()) {
        await src.copy(destPath);
        if (await File(destPath).exists()) {
          return p
              .join(_kTableImagesSubdir, p.basename(destPath))
              .replaceAll('\\', '/');
        }
      }
    } catch (_) {}
    try {
      final List<int> bytes = await XFile(trimmed).readAsBytes();
      final File out = File(destPath);
      await out.writeAsBytes(bytes, flush: true);
      if (await out.exists() && await out.length() > 0) {
        return p
            .join(_kTableImagesSubdir, p.basename(destPath))
            .replaceAll('\\', '/');
      }
    } catch (_) {}
    return null;
  }

  TableColumnEntity? _firstColumnWithType(
    TableSchemaEntity schema,
    TableColumnType type,
  ) {
    for (final TableColumnEntity c in schema.columns) {
      if (c.type == type) {
        return c;
      }
    }
    return null;
  }

  /// Contact cards: use the seeded avatar column when present so extra [image] columns
  /// or reordering do not steal the lead avatar slot.
  TableColumnEntity? _contactListAvatarColumn(TableSchemaEntity schema) {
    for (final TableColumnEntity c in schema.columns) {
      if (c.id == _kContactListAvatarColumnId &&
          c.type == TableColumnType.image) {
        return c;
      }
    }
    return _firstColumnWithType(schema, TableColumnType.image);
  }

  Future<void> _createOrEditRow(
    TableSchemaEntity schema, {
    TableRowEntity? existing,
  }) async {
    await _ensureAppSupportPath();
    final bool isEdit = existing != null;
    final List<TableColumnEntity> columns = schema.columns
        .where((TableColumnEntity c) {
          if (c.type == TableColumnType.autoGenerated ||
              c.type == TableColumnType.formula) {
            return false;
          }
          if (schema.mode == TableMode.readOnly) {
            return false;
          }
          return isEdit ? c.includeInEditForm : c.includeInCreateForm;
        })
        .toList(growable: false);
    final Map<String, dynamic> values = <String, dynamic>{
      ...existing?.values ?? <String, dynamic>{},
    };
    final Map<String, TextEditingController> textCtrls =
        <String, TextEditingController>{};
    final Map<String, bool> boolValues = <String, bool>{};
    final Map<String, DateTime?> dateValues = <String, DateTime?>{};
    final Map<String, String?> imageValues = <String, String?>{};
    final Map<String, String?> fileValues = <String, String?>{};

    for (final TableColumnEntity c in columns) {
      if (c.type == TableColumnType.boolean) {
        boolValues[c.id] = (values[c.id] as bool?) ?? false;
      } else if (c.type == TableColumnType.date) {
        final dynamic raw = values[c.id];
        if (raw is String && raw.isNotEmpty) {
          dateValues[c.id] = DateTime.tryParse(raw);
        } else {
          dateValues[c.id] = null;
        }
      } else if (c.type == TableColumnType.image) {
        imageValues[c.id] = values[c.id]?.toString();
      } else if (c.type == TableColumnType.file) {
        fileValues[c.id] = values[c.id]?.toString();
      } else {
        textCtrls[c.id] = TextEditingController(
          text: values[c.id]?.toString() ?? '',
        );
      }
    }

    final Map<String, String?> fieldErrors = <String, String?>{};
    dynamic currentDraftValue(TableColumnEntity col) {
      return switch (col.type) {
        TableColumnType.boolean => boolValues[col.id] ?? false,
        TableColumnType.date => dateValues[col.id]?.toIso8601String(),
        TableColumnType.image => imageValues[col.id],
        TableColumnType.file => fileValues[col.id],
        _ => textCtrls[col.id]?.text.trim(),
      };
    }

    String? validateUniqueValue(TableColumnEntity col, dynamic candidateValue) {
      if (!col.isUnique) {
        return null;
      }
      final String candidate = (candidateValue ?? '').toString().trim();
      if (candidate.isEmpty) {
        return null;
      }
      final List<TableRowEntity> rows =
          _rowsByTable[schema.id] ?? <TableRowEntity>[];
      for (final TableRowEntity row in rows) {
        if (existing != null && row.id == existing.id) {
          continue;
        }
        final String rowValue = (row.values[col.id] ?? '').toString().trim();
        if (rowValue.isNotEmpty &&
            rowValue.toLowerCase() == candidate.toLowerCase()) {
          return '${col.name} must be unique.';
        }
      }
      return null;
    }

    final bool? shouldSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            Widget shellColumn(String columnId, Widget child) {
              final String? err = fieldErrors[columnId];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  child,
                  if (err != null && err.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        err,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              );
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(isEdit ? 'Edit Record' : 'Add Record'),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: columns
                            .map((TableColumnEntity col) {
                              final Widget field = switch (col.type) {
                                TableColumnType.boolean => SwitchListTile(
                                  value: boolValues[col.id] ?? false,
                                  onChanged: (bool v) {
                                    setModalState(() {
                                      boolValues[col.id] = v;
                                      final String? msg =
                                          TableRowModalFieldValidators.validate(
                                            col: col,
                                            textValue: textCtrls[col.id]?.text,
                                            boolValue: v,
                                            dateValue: dateValues[col.id],
                                            imageValue: imageValues[col.id],
                                            fileValue: fileValues[col.id],
                                            rowsByTableForDropdown:
                                                _rowsByTable,
                                          );
                                      if (msg == null || msg.isEmpty) {
                                        fieldErrors.remove(col.id);
                                      } else {
                                        fieldErrors[col.id] = msg;
                                      }
                                    });
                                  },
                                  title: Text(col.name),
                                ),
                                TableColumnType.date =>
                                  (() {
                                    final DateTime? value = dateValues[col.id];
                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(col.name),
                                      subtitle: Text(
                                        value == null
                                            ? 'Tap to select date'
                                            : _formatDate(value),
                                      ),
                                      trailing: const Icon(
                                        Icons.calendar_today_outlined,
                                      ),
                                      onTap: () async {
                                        final DateTime now = DateTime.now();
                                        final DateTime? picked =
                                            await showDatePicker(
                                              context: context,
                                              firstDate: DateTime(
                                                now.year - 50,
                                              ),
                                              lastDate: DateTime(now.year + 50),
                                              initialDate: value ?? now,
                                            );
                                        if (picked != null) {
                                          setModalState(() {
                                            dateValues[col.id] = picked;
                                            final String? msg =
                                                TableRowModalFieldValidators.validate(
                                                  col: col,
                                                  textValue:
                                                      textCtrls[col.id]?.text,
                                                  boolValue: boolValues[col.id],
                                                  dateValue: picked,
                                                  imageValue:
                                                      imageValues[col.id],
                                                  fileValue: fileValues[col.id],
                                                  rowsByTableForDropdown:
                                                      _rowsByTable,
                                                );
                                            if (msg == null || msg.isEmpty) {
                                              fieldErrors.remove(col.id);
                                            } else {
                                              fieldErrors[col.id] = msg;
                                            }
                                          });
                                        }
                                      },
                                    );
                                  })(),
                                TableColumnType.dropdown =>
                                  (() {
                                    final List<String> options =
                                        DropdownColumnOptions.resolve(
                                          column: col,
                                          rowsByTableId: _rowsByTable,
                                        );
                                    final TextEditingController ctrl =
                                        textCtrls[col.id]!;
                                    return SearchableDropdownOptionsField(
                                      label: col.name,
                                      options: options,
                                      controller: ctrl,
                                      onChanged: () {
                                        setModalState(() {
                                          final String? msg =
                                              TableRowModalFieldValidators.validate(
                                                col: col,
                                                textValue: ctrl.text,
                                                boolValue: boolValues[col.id],
                                                dateValue: dateValues[col.id],
                                                imageValue: imageValues[col.id],
                                                fileValue: fileValues[col.id],
                                                rowsByTableForDropdown:
                                                    _rowsByTable,
                                              );
                                          if (msg == null || msg.isEmpty) {
                                            fieldErrors.remove(col.id);
                                          } else {
                                            fieldErrors[col.id] = msg;
                                          }
                                        });
                                      },
                                    );
                                  })(),
                                TableColumnType.number ||
                                TableColumnType.currency => TextField(
                                  controller: textCtrls[col.id],
                                  decoration: InputDecoration(
                                    labelText: col.name,
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                        signed: false,
                                      ),
                                  inputFormatters: const <TextInputFormatter>[
                                    DecimalNumericInputFormatter(),
                                  ],
                                  onChanged: (_) {
                                    setModalState(() {
                                      final String? msg =
                                          TableRowModalFieldValidators.validate(
                                            col: col,
                                            textValue: textCtrls[col.id]?.text,
                                            boolValue: boolValues[col.id],
                                            dateValue: dateValues[col.id],
                                            imageValue: imageValues[col.id],
                                            fileValue: fileValues[col.id],
                                            rowsByTableForDropdown:
                                                _rowsByTable,
                                          );
                                      if (msg == null || msg.isEmpty) {
                                        fieldErrors.remove(col.id);
                                      } else {
                                        fieldErrors[col.id] = msg;
                                      }
                                    });
                                  },
                                ),
                                TableColumnType.image =>
                                  (() {
                                    final String? imagePath =
                                        imageValues[col.id];
                                    final String previewLocal =
                                        imagePath != null &&
                                                imagePath.isNotEmpty
                                            ? _resolveImagePathForDisplay(
                                              imagePath,
                                            )
                                            : '';
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          col.name,
                                          style:
                                              Theme.of(
                                                context,
                                              ).textTheme.bodyMedium,
                                        ),
                                        const SizedBox(height: 8),
                                        if (previewLocal.isNotEmpty)
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: SizedBox(
                                              height: 120,
                                              width: 120,
                                              child:
                                                  File(
                                                        previewLocal,
                                                      ).existsSync()
                                                      ? Image.file(
                                                        File(previewLocal),
                                                        fit: BoxFit.cover,
                                                      )
                                                      : const ColoredBox(
                                                        color: Colors.black12,
                                                        child: Center(
                                                          child: Icon(
                                                            Icons
                                                                .broken_image_outlined,
                                                          ),
                                                        ),
                                                      ),
                                            ),
                                          ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          children: <Widget>[
                                            OutlinedButton.icon(
                                              onPressed: () async {
                                                final XFile? picked =
                                                    await _imagePicker
                                                        .pickImage(
                                                          source:
                                                              ImageSource
                                                                  .gallery,
                                                        );
                                                if (picked != null) {
                                                  setModalState(() {
                                                    imageValues[col.id] =
                                                        picked.path;
                                                    final String? msg =
                                                        TableRowModalFieldValidators.validate(
                                                          col: col,
                                                          textValue:
                                                              textCtrls[col.id]
                                                                  ?.text,
                                                          boolValue:
                                                              boolValues[col
                                                                  .id],
                                                          dateValue:
                                                              dateValues[col
                                                                  .id],
                                                          imageValue:
                                                              picked.path,
                                                          fileValue:
                                                              fileValues[col
                                                                  .id],
                                                          rowsByTableForDropdown:
                                                              _rowsByTable,
                                                        );
                                                    if (msg == null ||
                                                        msg.isEmpty) {
                                                      fieldErrors.remove(
                                                        col.id,
                                                      );
                                                    } else {
                                                      fieldErrors[col.id] = msg;
                                                    }
                                                  });
                                                }
                                              },
                                              icon: const Icon(
                                                Icons.photo_library_outlined,
                                              ),
                                              label: Text(
                                                imagePath == null
                                                    ? 'Pick Image'
                                                    : 'Replace',
                                              ),
                                            ),
                                            if (imagePath != null &&
                                                imagePath.isNotEmpty)
                                              TextButton(
                                                onPressed: () {
                                                  setModalState(() {
                                                    imageValues[col.id] = null;
                                                    final String? msg =
                                                        TableRowModalFieldValidators.validate(
                                                          col: col,
                                                          textValue:
                                                              textCtrls[col.id]
                                                                  ?.text,
                                                          boolValue:
                                                              boolValues[col
                                                                  .id],
                                                          dateValue:
                                                              dateValues[col
                                                                  .id],
                                                          imageValue: null,
                                                          fileValue:
                                                              fileValues[col
                                                                  .id],
                                                          rowsByTableForDropdown:
                                                              _rowsByTable,
                                                        );
                                                    if (msg == null ||
                                                        msg.isEmpty) {
                                                      fieldErrors.remove(
                                                        col.id,
                                                      );
                                                    } else {
                                                      fieldErrors[col.id] = msg;
                                                    }
                                                  });
                                                },
                                                child: const Text('Remove'),
                                              ),
                                          ],
                                        ),
                                      ],
                                    );
                                  })(),
                                TableColumnType.file =>
                                  (() {
                                    final String? filePath = fileValues[col.id];
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          col.name,
                                          style:
                                              Theme.of(
                                                context,
                                              ).textTheme.bodyMedium,
                                        ),
                                        const SizedBox(height: 8),
                                        if (filePath != null &&
                                            filePath.isNotEmpty)
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: _fileColumnIconButton(
                                              filePath,
                                            ),
                                          ),
                                        Wrap(
                                          spacing: 8,
                                          children: <Widget>[
                                            OutlinedButton.icon(
                                              onPressed: () async {
                                                final FilePickerResult? result =
                                                    await FilePicker.pickFiles();
                                                final String? path =
                                                    result?.files.single.path;
                                                if (path != null &&
                                                    path.isNotEmpty) {
                                                  setModalState(() {
                                                    fileValues[col.id] = path;
                                                    final String? msg =
                                                        TableRowModalFieldValidators.validate(
                                                          col: col,
                                                          textValue:
                                                              textCtrls[col.id]
                                                                  ?.text,
                                                          boolValue:
                                                              boolValues[col
                                                                  .id],
                                                          dateValue:
                                                              dateValues[col
                                                                  .id],
                                                          imageValue:
                                                              imageValues[col
                                                                  .id],
                                                          fileValue: path,
                                                          rowsByTableForDropdown:
                                                              _rowsByTable,
                                                        );
                                                    if (msg == null ||
                                                        msg.isEmpty) {
                                                      fieldErrors.remove(
                                                        col.id,
                                                      );
                                                    } else {
                                                      fieldErrors[col.id] = msg;
                                                    }
                                                  });
                                                }
                                              },
                                              icon: const Icon(
                                                Icons.upload_file_outlined,
                                              ),
                                              label: Text(
                                                filePath == null
                                                    ? 'Pick File'
                                                    : 'Replace',
                                              ),
                                            ),
                                            if (filePath != null &&
                                                filePath.isNotEmpty)
                                              TextButton(
                                                onPressed: () {
                                                  setModalState(() {
                                                    fileValues[col.id] = null;
                                                    final String? msg =
                                                        TableRowModalFieldValidators.validate(
                                                          col: col,
                                                          textValue:
                                                              textCtrls[col.id]
                                                                  ?.text,
                                                          boolValue:
                                                              boolValues[col
                                                                  .id],
                                                          dateValue:
                                                              dateValues[col
                                                                  .id],
                                                          imageValue:
                                                              imageValues[col
                                                                  .id],
                                                          fileValue: null,
                                                          rowsByTableForDropdown:
                                                              _rowsByTable,
                                                        );
                                                    if (msg == null ||
                                                        msg.isEmpty) {
                                                      fieldErrors.remove(
                                                        col.id,
                                                      );
                                                    } else {
                                                      fieldErrors[col.id] = msg;
                                                    }
                                                  });
                                                },
                                                child: const Text('Remove'),
                                              ),
                                          ],
                                        ),
                                      ],
                                    );
                                  })(),
                                _ => TextField(
                                  controller: textCtrls[col.id],
                                  decoration: InputDecoration(
                                    labelText: col.name,
                                  ),
                                  onChanged: (_) {
                                    setModalState(() {
                                      final String? msg =
                                          TableRowModalFieldValidators.validate(
                                            col: col,
                                            textValue: textCtrls[col.id]?.text,
                                            boolValue: boolValues[col.id],
                                            dateValue: dateValues[col.id],
                                            imageValue: imageValues[col.id],
                                            fileValue: fileValues[col.id],
                                            rowsByTableForDropdown:
                                                _rowsByTable,
                                          );
                                      if (msg == null || msg.isEmpty) {
                                        fieldErrors.remove(col.id);
                                      } else {
                                        fieldErrors[col.id] = msg;
                                      }
                                    });
                                  },
                                ),
                              };

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: shellColumn(col.id, field),
                              );
                            })
                            .toList(growable: false),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          bool allValid = true;
                          setModalState(() {
                            fieldErrors.clear();
                            for (final TableColumnEntity col in columns) {
                              final String? msg =
                                  TableRowModalFieldValidators.validate(
                                    col: col,
                                    textValue: textCtrls[col.id]?.text,
                                    boolValue: boolValues[col.id],
                                    dateValue: dateValues[col.id],
                                    imageValue: imageValues[col.id],
                                    fileValue: fileValues[col.id],
                                    rowsByTableForDropdown: _rowsByTable,
                                  );
                              if (msg != null && msg.isNotEmpty) {
                                fieldErrors[col.id] = msg;
                                allValid = false;
                                continue;
                              }
                              final String? uniqueMsg = validateUniqueValue(
                                col,
                                currentDraftValue(col),
                              );
                              if (uniqueMsg != null && uniqueMsg.isNotEmpty) {
                                fieldErrors[col.id] = uniqueMsg;
                                allValid = false;
                              }
                            }
                          });
                          if (!allValid) {
                            return;
                          }
                          Navigator.of(context).pop(true);
                        },
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (shouldSave != true) {
      _disposeTextControllersSafely(textCtrls);
      return;
    }

    for (final TableColumnEntity col in columns) {
      if (col.type == TableColumnType.boolean) {
        values[col.id] = boolValues[col.id] ?? false;
      } else if (col.type == TableColumnType.date) {
        final DateTime? value = dateValues[col.id];
        values[col.id] = value?.toIso8601String();
      } else if (col.type == TableColumnType.image) {
        values[col.id] = imageValues[col.id];
      } else if (col.type == TableColumnType.file) {
        values[col.id] = fileValues[col.id];
      } else {
        values[col.id] = textCtrls[col.id]?.text.trim();
      }
    }
    for (final TableColumnEntity col in schema.columns) {
      if (col.type != TableColumnType.image) {
        continue;
      }
      final String? cur = values[col.id]?.toString();
      if (cur == null || cur.trim().isEmpty) {
        continue;
      }
      final String? persisted = await _persistTableImageIfNeeded(cur);
      if (persisted != null && persisted.isNotEmpty) {
        values[col.id] = persisted;
      }
    }
    for (final TableColumnEntity col in schema.columns) {
      if (col.type == TableColumnType.autoGenerated &&
          !values.containsKey(col.id)) {
        values[col.id] = _generateAutoValue(col, schema.id);
      }
    }
    _disposeTextControllersSafely(textCtrls);

    final TableRowEntity row = TableRowEntity(
      id: existing?.id ?? _uuid.v4(),
      tableId: schema.id,
      values: values,
    );
    if (existing == null) {
      await _saveRow(row);
      if (schema.tableKind != TableKind.summary) {
        try {
          await _applyInventoryDeduction(
            config: schema.inventoryDeduction,
            allSchemas: _allSchemas,
            lineValues: values,
          );
        } catch (_) {
          /* best-effort; row is already saved */
        }
      }
    } else {
      await _updateRow(row);
    }
    await _load();
  }

  String _generateAutoValue(TableColumnEntity column, String tableId) {
    final DateTime now = DateTime.now();
    final String pattern =
        column.pattern?.trim().isNotEmpty == true
            ? column.pattern!.trim()
            : '{YYYY}-{RAND4}';
    return pattern
        .replaceAll('{YYYY}', now.year.toString())
        .replaceAll('{MM}', now.month.toString().padLeft(2, '0'))
        .replaceAll('{DD}', now.day.toString().padLeft(2, '0'))
        .replaceAll('{RAND4}', (1000 + now.millisecond).toString())
        .replaceAll(
          '{SEQ}',
          ((_rowsByTable[tableId]?.length ?? 0) + 1).toString().padLeft(4, '0'),
        )
        .replaceAll('{DATE}', _compactDate(now))
        .replaceAll('{TABLE}', widget.page.name.toUpperCase());
  }

  Future<void> _deleteRecord(
    TableSchemaEntity schema,
    TableRowEntity row, {
    bool askConfirmation = true,
  }) async {
    bool confirmed = true;
    if (askConfirmation) {
      final bool? dialogResult = await showDialog<bool>(
        context: context,
        builder:
            (BuildContext context) => AlertDialog(
              title: const Text('Delete record'),
              content: const Text('This action cannot be undone.'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            ),
      );
      confirmed = dialogResult == true;
    }
    if (!confirmed) {
      return;
    }
    await _deleteRow(row.id);
    await _load();
  }

  String _primaryLabel(TableSchemaEntity schema, TableRowEntity row) {
    final Map<String, dynamic> resolved = _resolvedRowValues(schema, row);
    for (final TableColumnEntity col in schema.columns) {
      final dynamic value = resolved[col.id];
      if (value != null && value.toString().trim().isNotEmpty) {
        return '${col.name}: ${value.toString()}';
      }
    }
    return 'Record ${row.id.substring(0, 6)}';
  }

  String _compactDate(DateTime date) {
    final String year = date.year.toString();
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '$year$month$day';
  }

  String _formatDate(DateTime date) {
    final String year = date.year.toString();
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _fileName(String? path) {
    if (path == null || path.isEmpty) {
      return '';
    }
    final int slash = path.lastIndexOf(Platform.pathSeparator);
    if (slash < 0) {
      return path;
    }
    return path.substring(slash + 1);
  }

  /// File columns in lists / detail rows: icon control only (filename opens in preview sheet).
  Widget _fileColumnIconButton(String rawValue) {
    final String trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      return const SizedBox.shrink();
    }
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      tooltip: 'Open file',
      icon: Icon(_fileIconFor(trimmed)),
      onPressed: () => _openFilePreview(trimmed),
    );
  }

  void _disposeTextControllersSafely(
    Map<String, TextEditingController> controllers,
  ) {
    // Delay disposal slightly to avoid TextField rebuild/dispose race during
    // bottom-sheet close animation.
    Future<void>.delayed(const Duration(milliseconds: 250), () {
      for (final TextEditingController controller in controllers.values) {
        controller.dispose();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_layoutOrder.isNotEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: _layoutOrder.length,
        itemBuilder: (BuildContext context, int index) {
          final String key = _layoutOrder[index];
          if (key == 'widgets') {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildCardsGroup(theme, _cardWidgets),
            );
          }
          final BuilderWidgetEntity? chart = _chartByLayoutKey[key];
          if (chart != null) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildCardSection(theme, chart),
            );
          }
          final TableSchemaEntity? schema = _tableByLayoutKey[key];
          if (schema != null) {
            final List<TableRowEntity> rows =
                _rowsByTable[schema.id] ?? <TableRowEntity>[];
            final bool crudEnabled =
                schema.mode == TableMode.crud &&
                schema.tableKind != TableKind.summary;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildTableSection(theme, schema, rows, crudEnabled),
            );
          }
          return const SizedBox.shrink();
        },
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              AppIconRegistry.iconOf(widget.page.iconName),
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              widget.page.name,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'This page is ready for widgets. Builder content will load from saved metadata.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: <Widget>[
                if (widget.page.showInBottomNav)
                  Chip(
                    avatar: const Icon(Icons.navigation, size: 18),
                    label: const Text('Bottom nav'),
                  ),
                if (widget.page.showInDrawer)
                  Chip(
                    avatar: const Icon(Icons.menu, size: 18),
                    label: const Text('Drawer'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardSection(
    ThemeData theme,
    BuilderWidgetEntity card, {
    bool compact = false,
  }) {
    if (card.type == 'chart') {
      return _buildChartSection(theme, card, compact: compact);
    }
    final CardWidgetLayout layout = CardWidgetLayout.fromStorage(
      card.config['cardLayout']?.toString(),
    );
    final String title = card.config['title']?.toString().trim() ?? '';
    final String value = computeCardWidgetDisplayValue(
      widget: card,
      allSchemas: _allSchemas,
      rowsByTableId: _rowsByTable,
    );
    final ColorScheme cs = theme.colorScheme;

    switch (layout) {
      case CardWidgetLayout.kpi:
        return Card(
          elevation: 0,
          color: cs.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (title.isNotEmpty)
                  Text(
                    title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      letterSpacing: 0.6,
                    ),
                  ),
                if (title.isNotEmpty) const SizedBox(height: 6),
                Text(
                  value.isEmpty ? '—' : value,
                  maxLines: compact ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: (compact
                          ? theme.textTheme.headlineSmall
                          : theme.textTheme.headlineMedium)
                      ?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                ),
              ],
            ),
          ),
        );
      case CardWidgetLayout.info:
        return Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.insights_outlined, color: cs.primary, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (title.isNotEmpty)
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      if (title.isNotEmpty) const SizedBox(height: 4),
                      Text(
                        value.isEmpty ? '—' : value,
                        maxLines: compact ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: (compact
                                ? theme.textTheme.titleMedium
                                : theme.textTheme.titleLarge)
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      case CardWidgetLayout.simple:
        return Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (title.isNotEmpty)
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                if (title.isNotEmpty) const SizedBox(height: 8),
                Text(
                  value.isEmpty ? '—' : value,
                  maxLines: compact ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: (compact
                          ? theme.textTheme.titleLarge
                          : theme.textTheme.headlineSmall)
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        );
    }
  }

  Widget _buildChartSection(
    ThemeData theme,
    BuilderWidgetEntity chartWidget, {
    bool compact = false,
  }) {
    final String title = chartWidget.config['title']?.toString().trim() ?? '';
    final String tableId = chartWidget.config['tableId']?.toString() ?? '';
    final String xColumnId = chartWidget.config['xColumnId']?.toString() ?? '';
    final String? yColumnId = chartWidget.config['yColumnId']?.toString();
    final String formula =
        chartWidget.config['formula']?.toString().trim() ?? '';
    final String chartType =
        chartWidget.config['chartType']?.toString() ?? 'bar';

    TableSchemaEntity? table;
    for (final TableSchemaEntity s in _allSchemas) {
      if (s.id == tableId) {
        table = s;
        break;
      }
    }
    if (table == null ||
        xColumnId.isEmpty ||
        (yColumnId == null && formula.isEmpty)) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Chart is not fully configured.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    final List<TableRowEntity> rows =
        _rowsByTable[table.id] ?? <TableRowEntity>[];
    final List<({String label, double value})> points =
        <({String label, double value})>[];
    for (final TableRowEntity row in rows) {
      final Map<String, dynamic> resolved = _resolvedRowValues(table, row);
      final String label =
          (resolved[xColumnId] ?? row.values[xColumnId] ?? '').toString();
      if (label.trim().isEmpty) {
        continue;
      }
      double? value;
      if (formula.isNotEmpty) {
        final String raw = TableFormulaEvaluator.evaluate(
          formula: formula,
          currentSchema: table,
          workingRowByColId: row.values,
          allSchemas: _allSchemas,
          rowsByTableId: _rowsByTable,
          forColumnId: '_chart',
        );
        value = _toDouble(raw);
      } else if (yColumnId != null && yColumnId.isNotEmpty) {
        value = _toDouble(
          (resolved[yColumnId] ?? row.values[yColumnId]).toString(),
        );
      }
      if (value == null) {
        continue;
      }
      points.add((label: label, value: value));
    }

    if (points.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            title.isEmpty
                ? 'No chart data available.'
                : '$title: no chart data.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    final double chartHeight = compact ? 160 : 220;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
            SizedBox(
              height: chartHeight,
              child: switch (chartType) {
                'line' => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildLineChart(points, theme),
                ),
                'pie' => _buildPieChart(points, theme),
                _ => _buildBarChart(points, theme),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(
    List<({String label, double value})> points,
    ThemeData theme,
  ) {
    final double xInterval = _chartXAxisInterval(points.length);
    final bool rotateLabels = points.length > 3;
    return BarChart(
      BarChartData(
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 34),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: rotateLabels ? 44 : 28,
              interval: xInterval,
              getTitlesWidget: (double value, TitleMeta meta) {
                final int idx = value.toInt();
                final String label =
                    idx >= 0 && idx < points.length ? points[idx].label : '';
                return _chartBottomTitle(
                  label,
                  meta: meta,
                  rotate: rotateLabels,
                );
              },
            ),
          ),
        ),
        barGroups: <BarChartGroupData>[
          for (int i = 0; i < points.length; i++)
            BarChartGroupData(
              x: i,
              barRods: <BarChartRodData>[
                BarChartRodData(
                  toY: points[i].value,
                  width: 16,
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLineChart(
    List<({String label, double value})> points,
    ThemeData theme,
  ) {
    final double xInterval = _chartXAxisInterval(points.length);
    final bool rotateLabels = points.length > 3;
    return LineChart(
      LineChartData(
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 34),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: rotateLabels ? 44 : 28,
              interval: xInterval,
              getTitlesWidget: (double value, TitleMeta meta) {
                final int idx = value.toInt();
                final String label =
                    idx >= 0 && idx < points.length ? points[idx].label : '';
                return _chartBottomTitle(
                  label,
                  meta: meta,
                  rotate: rotateLabels,
                );
              },
            ),
          ),
        ),
        lineBarsData: _buildLineSegments(points, theme),
      ),
    );
  }

  Widget _buildPieChart(
    List<({String label, double value})> points,
    ThemeData theme,
  ) {
    final List<Color> palette = <Color>[
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      theme.colorScheme.tertiary,
      theme.colorScheme.primaryContainer,
      theme.colorScheme.secondaryContainer,
      theme.colorScheme.tertiaryContainer,
    ];
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 26,
        sections: <PieChartSectionData>[
          for (int i = 0; i < points.length; i++)
            PieChartSectionData(
              value: points[i].value <= 0 ? 0.01 : points[i].value,
              color: palette[i % palette.length],
              title: points[i].label,
              radius: 74,
              titleStyle: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  double? _toDouble(String raw) {
    final String normalized = raw.trim().replaceAll(',', '');
    return double.tryParse(normalized);
  }

  double _chartXAxisInterval(int count) {
    if (count <= 4) {
      return 1;
    }
    if (count <= 8) {
      return 2;
    }
    if (count <= 14) {
      return 3;
    }
    return (count / 5).ceilToDouble();
  }

  List<LineChartBarData> _buildLineSegments(
    List<({String label, double value})> points,
    ThemeData theme,
  ) {
    if (points.length <= 1) {
      return <LineChartBarData>[
        LineChartBarData(
          isCurved: false,
          color: theme.colorScheme.primary,
          barWidth: 3,
          spots: <FlSpot>[
            for (int i = 0; i < points.length; i++)
              FlSpot(i.toDouble(), points[i].value),
          ],
          dotData: const FlDotData(show: true),
        ),
      ];
    }
    final List<LineChartBarData> segments = <LineChartBarData>[];
    for (int i = 0; i < points.length - 1; i++) {
      final double from = points[i].value;
      final double to = points[i + 1].value;
      segments.add(
        LineChartBarData(
          // Flat consecutive values stay straight; value changes can curve.
          isCurved: (from - to).abs() > 0.000001,
          color: theme.colorScheme.primary,
          barWidth: 3,
          spots: <FlSpot>[
            FlSpot(i.toDouble(), from),
            FlSpot((i + 1).toDouble(), to),
          ],
          dotData: FlDotData(
            show: true,
            checkToShowDot: (FlSpot spot, LineChartBarData barData) {
              return (spot.x - i.toDouble()).abs() < 0.000001 ||
                  (spot.x - (i + 1).toDouble()).abs() < 0.000001;
            },
          ),
        ),
      );
    }
    return segments;
  }

  Widget _chartBottomTitle(
    String label, {
    required TitleMeta meta,
    required bool rotate,
  }) {
    final Widget text = SizedBox(
      width: rotate ? 64 : 80,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: rotate ? TextAlign.right : TextAlign.center,
      ),
    );
    final Widget sideTitle = SideTitleWidget(
      meta: meta,
      space: 6,
      child: ClipRect(child: text),
    );
    if (!rotate) {
      return sideTitle;
    }
    return Transform.rotate(angle: -0.55, child: sideTitle);
  }

  Widget _buildCardsGroup(ThemeData theme, List<BuilderWidgetEntity> cards) {
    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }
    final int gridCount = widget.page.widgetGridCount.clamp(1, 3);
    if (gridCount == 1) {
      return Column(
        children: <Widget>[
          for (final BuilderWidgetEntity card in cards) ...<Widget>[
            _buildCardSection(theme, card),
            if (card != cards.last) const SizedBox(height: 12),
          ],
        ],
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: gridCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: gridCount >= 3 ? 1.05 : 1.2,
      ),
      itemCount: cards.length,
      itemBuilder: (BuildContext context, int index) {
        return _buildCardSection(theme, cards[index], compact: true);
      },
    );
  }

  Widget _buildTableSection(
    ThemeData theme,
    TableSchemaEntity schema,
    List<TableRowEntity> rows,
    bool crudEnabled,
  ) {
    final String tableId = schema.id;
    final String query =
        (_tableSearchQueries[tableId] ?? '').trim().toLowerCase();
    final List<TableRowEntity> filteredRows =
        query.isEmpty
            ? rows
            : rows
                .where((TableRowEntity row) {
                  final Map<String, dynamic> resolved = _resolvedRowValues(
                    schema,
                    row,
                  );
                  for (final TableColumnEntity column in schema.columns) {
                    final String value =
                        (resolved[column.id] ?? '').toString().toLowerCase();
                    if (value.contains(query)) {
                      return true;
                    }
                  }
                  return false;
                })
                .toList(growable: false);
    final bool isLazy = schema.dataLoadingMode == TableDataLoadingMode.lazy;
    final int totalFiltered = filteredRows.length;
    final int currentPage = _tableCurrentPages[tableId] ?? 1;
    final int pageSize = (_tablePageSizes[tableId] ?? schema.pageSize).clamp(
      1,
      200,
    );
    final int lazyVisible = (_tableVisibleCounts[tableId] ??
            schema.lazyInitialLoad)
        .clamp(1, filteredRows.length == 0 ? 1 : filteredRows.length);
    final int totalPages =
        totalFiltered == 0 ? 1 : (totalFiltered / pageSize).ceil();
    final int boundedPage = currentPage > totalPages ? totalPages : currentPage;
    final List<TableRowEntity> visibleRows =
        isLazy
            ? filteredRows.take(lazyVisible).toList(growable: false)
            : filteredRows
                .skip((boundedPage - 1) * pageSize)
                .take(pageSize)
                .toList(growable: false);
    final bool canLoadMoreLazy = isLazy && lazyVisible < totalFiltered;

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        if (!isLazy || !canLoadMoreLazy) {
          return false;
        }
        if (notification.metrics.extentAfter < 220) {
          setState(() {
            final int current =
                _tableVisibleCounts[tableId] ?? schema.lazyInitialLoad;
            _tableVisibleCounts[tableId] = (current + 5).clamp(
              1,
              totalFiltered,
            );
          });
        }
        return false;
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(schema.name, style: theme.textTheme.titleMedium),
                        if (schema.description.isNotEmpty)
                          Text(
                            schema.description,
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  if (crudEnabled)
                    FilledButton.icon(
                      onPressed: () => _createOrEditRow(schema),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Record'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (!isLazy) ...<Widget>[
                Row(
                  children: <Widget>[
                    DropdownButton<int>(
                      value: pageSize,
                      items: const <int>[5, 10, 20, 50]
                          .map(
                            (int value) => DropdownMenuItem<int>(
                              value: value,
                              child: Text(value.toString()),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (int? value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _tablePageSizes[tableId] = value;
                          _tableCurrentPages[tableId] = 1;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'rows per page',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (schema.searchEnabled) ...<Widget>[
                TextField(
                  controller: _tableSearchControllers[tableId],
                  decoration: InputDecoration(
                    hintText: 'Search in ${schema.name}',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: const OutlineInputBorder(),
                    suffixIcon:
                        (_tableSearchQueries[tableId] ?? '').isEmpty
                            ? null
                            : IconButton(
                              onPressed: () {
                                _tableSearchControllers[tableId]?.clear();
                                setState(() {
                                  _tableSearchQueries[tableId] = '';
                                  _tableCurrentPages[tableId] = 1;
                                  _tableVisibleCounts[tableId] =
                                      schema.lazyInitialLoad;
                                });
                              },
                              icon: const Icon(Icons.close),
                            ),
                  ),
                  onChanged: (String value) {
                    setState(() {
                      _tableSearchQueries[tableId] = value;
                      _tableCurrentPages[tableId] = 1;
                      _tableVisibleCounts[tableId] = schema.lazyInitialLoad;
                    });
                  },
                ),
                const SizedBox(height: 8),
              ],
              if (visibleRows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Column(
                      children: <Widget>[
                        const Text('No data available'),
                        if (crudEnabled) ...<Widget>[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () => _createOrEditRow(schema),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Record'),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else if (schema.listDesignLayout ==
                      TableListDesignLayout.product &&
                  schema.productDisplayMode == ProductDisplayMode.grid)
                _buildProductGrid(theme, schema, visibleRows, crudEnabled)
              else
                ...visibleRows.map(
                  (TableRowEntity row) => _wrapSwipeDelete(
                    schema: schema,
                    row: row,
                    crudEnabled: crudEnabled,
                    child: _tableRowForDesign(schema, row, crudEnabled),
                  ),
                ),
              if (canLoadMoreLazy) ...<Widget>[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        final int current =
                            _tableVisibleCounts[tableId] ??
                            schema.lazyInitialLoad;
                        _tableVisibleCounts[tableId] = (current + 5).clamp(
                          1,
                          totalFiltered,
                        );
                      });
                    },
                    icon: const Icon(Icons.expand_more),
                    label: Text(
                      'Load more (${totalFiltered - lazyVisible} remaining)',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Total records: ${rows.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (!isLazy && totalFiltered > 0) ...<Widget>[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        onPressed:
                            boundedPage > 1
                                ? () => setState(
                                  () =>
                                      _tableCurrentPages[tableId] =
                                          boundedPage - 1,
                                )
                                : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      ..._buildPaginationItems(
                        currentPage: boundedPage,
                        totalPages: totalPages,
                      ).map((dynamic item) {
                        if (item == null) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              '...',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        }
                        final int pageNumber = item as int;
                        final bool selected = pageNumber == boundedPage;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: TextButton(
                            onPressed:
                                () => setState(
                                  () =>
                                      _tableCurrentPages[tableId] = pageNumber,
                                ),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(32, 32),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              backgroundColor:
                                  selected
                                      ? theme.colorScheme.primaryContainer
                                      : null,
                            ),
                            child: Text(pageNumber.toString()),
                          ),
                        );
                      }),
                      IconButton(
                        onPressed:
                            boundedPage < totalPages
                                ? () => setState(
                                  () =>
                                      _tableCurrentPages[tableId] =
                                          boundedPage + 1,
                                )
                                : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<int?> _buildPaginationItems({
    required int currentPage,
    required int totalPages,
  }) {
    if (totalPages <= 7) {
      return List<int?>.generate(totalPages, (int i) => i + 1);
    }

    final Set<int> pages = <int>{1, totalPages};
    for (int p = currentPage - 1; p <= currentPage + 1; p++) {
      if (p > 1 && p < totalPages) {
        pages.add(p);
      }
    }
    if (currentPage <= 3) {
      pages.addAll(<int>{2, 3, 4});
    }
    if (currentPage >= totalPages - 2) {
      pages.addAll(<int>{totalPages - 3, totalPages - 2, totalPages - 1});
    }

    final List<int> sorted = pages
      .where((int p) => p >= 1 && p <= totalPages)
      .toList(growable: false)..sort();

    final List<int?> out = <int?>[];
    for (int i = 0; i < sorted.length; i++) {
      if (i > 0 && sorted[i] - sorted[i - 1] > 1) {
        out.add(null);
      }
      out.add(sorted[i]);
    }
    return out;
  }

  Widget _wrapSwipeDelete({
    required TableSchemaEntity schema,
    required TableRowEntity row,
    required bool crudEnabled,
    required Widget child,
  }) {
    if (schema.layoutType != TableLayoutType.swipe) {
      return child;
    }
    return Dismissible(
      key: ValueKey<String>('${schema.id}-${row.id}'),
      direction:
          crudEnabled ? DismissDirection.endToStart : DismissDirection.none,
      confirmDismiss: (_) async {
        if (!crudEnabled) {
          return false;
        }
        final bool? confirmed = await showDialog<bool>(
          context: context,
          builder:
              (BuildContext context) => AlertDialog(
                title: const Text('Delete record'),
                content: const Text('This action cannot be undone.'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
        );
        return confirmed == true;
      },
      onDismissed: (_) => _deleteRecord(schema, row, askConfirmation: false),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: Theme.of(context).colorScheme.errorContainer,
        child: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      child: child,
    );
  }

  Widget _tableRowForDesign(
    TableSchemaEntity schema,
    TableRowEntity row,
    bool crudEnabled,
  ) {
    return switch (schema.listDesignLayout) {
      TableListDesignLayout.contact => _buildContactListRow(
        schema,
        row,
        crudEnabled,
      ),
      TableListDesignLayout.product => _buildProductListRow(
        schema,
        row,
        crudEnabled,
      ),
      TableListDesignLayout.standard => _buildVerticalDetailRow(
        schema,
        row,
        crudEnabled,
        showDeleteButton: schema.layoutType != TableLayoutType.swipe,
      ),
    };
  }

  Widget _buildProductGrid(
    ThemeData theme,
    TableSchemaEntity schema,
    List<TableRowEntity> rows,
    bool crudEnabled,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.72,
      ),
      itemCount: rows.length,
      itemBuilder: (BuildContext context, int index) {
        final TableRowEntity row = rows[index];
        return _wrapSwipeDelete(
          schema: schema,
          row: row,
          crudEnabled: crudEnabled,
          child: _buildProductGridTile(schema, row, crudEnabled),
        );
      },
    );
  }

  Widget _buildProductGridTile(
    TableSchemaEntity schema,
    TableRowEntity row,
    bool crudEnabled,
  ) {
    final ThemeData theme = Theme.of(context);
    if (schema.columns.isEmpty) {
      return const SizedBox.shrink();
    }
    final TableColumnEntity? imageCol = _firstColumnWithType(
      schema,
      TableColumnType.image,
    );
    if (imageCol == null) {
      return const SizedBox.shrink();
    }
    TableColumnEntity? nameCol;
    TableColumnEntity? priceCol;
    final int imageIdx = schema.columns.indexOf(imageCol);
    for (int i = imageIdx + 1; i < schema.columns.length; i++) {
      final TableColumnEntity c = schema.columns[i];
      if (nameCol == null && _isTextLikeColumn(c.type)) {
        nameCol = c;
      }
      if (priceCol == null && c.type == TableColumnType.currency) {
        priceCol = c;
      }
    }
    final String imagePath = _displayCell(schema, row, imageCol.id);
    final String name =
        nameCol == null ? '' : _displayCell(schema, row, nameCol.id);
    final String price =
        priceCol == null ? '' : _displayCell(schema, row, priceCol.id);

    final Widget imageBox = _buildProductImageFill(theme, imagePath);

    final Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            child: imageBox,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                name.isEmpty ? _kEmptyCellDisplay : name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  color:
                      name.isEmpty ? theme.colorScheme.onSurfaceVariant : null,
                ),
              ),
              Text(
                price.isEmpty ? _kEmptyCellDisplay : price,
                style: theme.textTheme.labelLarge?.copyWith(
                  color:
                      price.isEmpty
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        if (crudEnabled)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              IconButton(
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _createOrEditRow(schema, existing: row),
              ),
              if (schema.layoutType != TableLayoutType.swipe)
                IconButton(
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteRecord(schema, row),
                ),
            ],
          ),
      ],
    );

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: body,
    );
  }

  Widget _buildProductImageFill(ThemeData theme, String imagePath) {
    if (imagePath.isEmpty) {
      return ColoredBox(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Center(
          child: Icon(Icons.image_outlined, color: theme.colorScheme.outline),
        ),
      );
    }
    final String localPath = _resolveImagePathForDisplay(imagePath);
    final File imageFile = File(localPath);
    return InkWell(
      onTap: () => _openImagePreview(imagePath),
      child:
          imageFile.existsSync()
              ? Image.file(imageFile, fit: BoxFit.cover, width: double.infinity)
              : ColoredBox(
                color: theme.colorScheme.surfaceContainerHighest,
                child: const Center(child: Icon(Icons.broken_image_outlined)),
              ),
    );
  }

  Widget _buildProductImageThumb(ThemeData theme, String imagePath) {
    if (imagePath.isEmpty) {
      return ColoredBox(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Center(
          child: Icon(Icons.image_outlined, color: theme.colorScheme.outline),
        ),
      );
    }
    final String localPath = _resolveImagePathForDisplay(imagePath);
    final File imageFile = File(localPath);
    return InkWell(
      onTap: () => _openImagePreview(imagePath),
      child:
          imageFile.existsSync()
              ? Image.file(imageFile, fit: BoxFit.cover)
              : ColoredBox(
                color: theme.colorScheme.surfaceContainerHighest,
                child: const Center(child: Icon(Icons.broken_image_outlined)),
              ),
    );
  }

  Widget _buildContactListRow(
    TableSchemaEntity schema,
    TableRowEntity row,
    bool crudEnabled,
  ) {
    final TableColumnEntity? avatarCol = _contactListAvatarColumn(schema);
    if (avatarCol == null) {
      return _buildVerticalDetailRow(schema, row, crudEnabled);
    }
    final List<TableColumnEntity> bodyCols = <TableColumnEntity>[
      for (final TableColumnEntity c in schema.columns)
        if (c.id != avatarCol.id) c,
    ];
    if (bodyCols.isEmpty) {
      return _buildVerticalDetailRow(schema, row, crudEnabled);
    }
    TableColumnEntity? titleCol;
    for (final TableColumnEntity c in bodyCols) {
      if (_isTextLikeColumn(c.type)) {
        titleCol = c;
        break;
      }
    }
    titleCol ??= bodyCols.first;

    final String avatarPath = _displayCell(schema, row, avatarCol.id);

    final ThemeData theme = Theme.of(context);
    final Widget avatar = _buildContactAvatar(theme, avatarPath);

    final List<Widget> bodyLines = <Widget>[];
    for (final TableColumnEntity c in schema.columns) {
      if (c.id == avatarCol.id) {
        continue;
      }
      if (c.id == titleCol.id) {
        final String titleVal = _displayCell(schema, row, c.id);
        bodyLines.add(
          Text(
            titleVal.isEmpty ? _kEmptyCellDisplay : titleVal,
            style: theme.textTheme.titleSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        );
        continue;
      }
      final Widget line = _contactSubtitleForColumn(theme, schema, row, c);
      bodyLines.add(
        Padding(padding: const EdgeInsets.only(top: 4), child: line),
      );
    }

    final Widget textBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: bodyLines,
    );

    final bool showDelete =
        crudEnabled && schema.layoutType != TableLayoutType.swipe;

    final Widget content = Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          avatar,
          const SizedBox(width: 12),
          Expanded(child: textBlock),
          if (crudEnabled)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _createOrEditRow(schema, existing: row),
                ),
                if (showDelete)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteRecord(schema, row),
                  ),
              ],
            ),
        ],
      ),
    );
    return Card(margin: const EdgeInsets.only(bottom: 8), child: content);
  }

  TextStyle _emptyCellTextStyle(ThemeData theme) =>
      theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ) ??
      TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12);

  /// Extra columns on the contact row (after title); empty values show [_kEmptyCellDisplay].
  Widget _contactSubtitleForColumn(
    ThemeData theme,
    TableSchemaEntity schema,
    TableRowEntity row,
    TableColumnEntity col,
  ) {
    final String rawValue = _displayCell(schema, row, col.id).trim();
    switch (col.type) {
      case TableColumnType.image:
        if (rawValue.isEmpty) {
          return Text(_kEmptyCellDisplay, style: _emptyCellTextStyle(theme));
        }
        return SizedBox(
          width: 40,
          height: 40,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: _buildProductImageThumb(theme, rawValue),
          ),
        );
      case TableColumnType.file:
        if (rawValue.isEmpty) {
          return Text(_kEmptyCellDisplay, style: _emptyCellTextStyle(theme));
        }
        return _fileColumnIconButton(rawValue);
      default:
        if (rawValue.isEmpty) {
          return Text(_kEmptyCellDisplay, style: _emptyCellTextStyle(theme));
        }
        if (_isTextLikeColumn(col.type)) {
          return Text(
            rawValue,
            style: theme.textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          );
        }
        return Text(
          '${col.name}: $rawValue',
          style: theme.textTheme.bodySmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );
    }
  }

  Widget _buildContactAvatar(ThemeData theme, String avatarPath) {
    if (avatarPath.isEmpty) {
      return CircleAvatar(
        radius: 26,
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(Icons.person, color: theme.colorScheme.onPrimaryContainer),
      );
    }
    final String localPath = _resolveImagePathForDisplay(avatarPath);
    final File file = File(localPath);
    if (!file.existsSync()) {
      return CircleAvatar(
        radius: 26,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.broken_image_outlined),
      );
    }
    return InkWell(
      onTap: () => _openImagePreview(avatarPath),
      borderRadius: BorderRadius.circular(26),
      child: CircleAvatar(
        radius: 26,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: ClipOval(
          child: Image.file(
            file,
            width: 52,
            height: 52,
            fit: BoxFit.cover,
            errorBuilder:
                (BuildContext context, Object error, StackTrace? stackTrace) =>
                    const Icon(Icons.broken_image_outlined),
          ),
        ),
      ),
    );
  }

  Widget _buildProductListRow(
    TableSchemaEntity schema,
    TableRowEntity row,
    bool crudEnabled,
  ) {
    if (schema.columns.isEmpty) {
      return _buildVerticalDetailRow(schema, row, crudEnabled);
    }
    final ThemeData theme = Theme.of(context);
    final TableColumnEntity? imageCol = _firstColumnWithType(
      schema,
      TableColumnType.image,
    );
    if (imageCol == null) {
      return _buildVerticalDetailRow(schema, row, crudEnabled);
    }
    TableColumnEntity? nameCol;
    TableColumnEntity? priceCol;
    final int imageIdx = schema.columns.indexOf(imageCol);
    for (int i = imageIdx + 1; i < schema.columns.length; i++) {
      final TableColumnEntity c = schema.columns[i];
      if (nameCol == null && _isTextLikeColumn(c.type)) {
        nameCol = c;
      }
      if (priceCol == null && c.type == TableColumnType.currency) {
        priceCol = c;
      }
    }
    final String imagePath = _displayCell(schema, row, imageCol.id);
    final String name =
        nameCol == null ? '' : _displayCell(schema, row, nameCol.id);
    final String price =
        priceCol == null ? '' : _displayCell(schema, row, priceCol.id);

    final Set<String> coreIds = <String>{
      imageCol.id,
      if (nameCol != null) nameCol.id,
      if (priceCol != null) priceCol.id,
    };
    final List<Widget> extras = <Widget>[];
    for (final TableColumnEntity c in schema.columns) {
      if (coreIds.contains(c.id)) {
        continue;
      }
      final String v = _displayCell(schema, row, c.id);
      if (c.type == TableColumnType.file) {
        extras.add(
          v.isEmpty
              ? Text(
                '${c.name}: $_kEmptyCellDisplay',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
              : _fileColumnIconButton(v),
        );
      } else {
        extras.add(
          Text(
            v.isEmpty ? '${c.name}: $_kEmptyCellDisplay' : '${c.name}: $v',
            style: theme.textTheme.labelSmall?.copyWith(
              color: v.isEmpty ? theme.colorScheme.onSurfaceVariant : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }
    }

    final bool showDelete =
        crudEnabled && schema.layoutType != TableLayoutType.swipe;

    final Widget thumb = SizedBox(
      width: 56,
      height: 56,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _buildProductImageThumb(theme, imagePath),
      ),
    );

    final Widget content = Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          thumb,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name.isEmpty ? _kEmptyCellDisplay : name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color:
                        name.isEmpty
                            ? theme.colorScheme.onSurfaceVariant
                            : null,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  price.isEmpty ? _kEmptyCellDisplay : price,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color:
                        price.isEmpty
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ...extras,
              ],
            ),
          ),
          if (crudEnabled)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _createOrEditRow(schema, existing: row),
                ),
                if (showDelete)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteRecord(schema, row),
                  ),
              ],
            ),
        ],
      ),
    );
    return Card(margin: const EdgeInsets.only(bottom: 8), child: content);
  }

  Widget _buildVerticalDetailRow(
    TableSchemaEntity schema,
    TableRowEntity row,
    bool crudEnabled, {
    bool showDeleteButton = true,
  }) {
    final ThemeData theme = Theme.of(context);
    final List<Widget> cells = <Widget>[];
    final Iterable<TableColumnEntity> displayColumns = schema.columns;
    for (final TableColumnEntity col in displayColumns) {
      final String label = col.name;
      final String rawValue = _displayCell(schema, row, col.id);
      final bool isEmpty = rawValue.trim().isEmpty;

      Widget valueWidget;
      if (col.type == TableColumnType.image) {
        if (isEmpty) {
          valueWidget = Text(
            _kEmptyCellDisplay,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          );
        } else {
          final String imageLocal = _resolveImagePathForDisplay(rawValue);
          final File imageFile = File(imageLocal);
          valueWidget = InkWell(
            onTap: () => _openImagePreview(rawValue),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child:
                        imageFile.existsSync()
                            ? Image.file(imageFile, fit: BoxFit.cover)
                            : const ColoredBox(
                              color: Colors.black12,
                              child: Center(
                                child: Icon(Icons.broken_image_outlined),
                              ),
                            ),
                  ),
                  const Positioned(
                    right: 2,
                    bottom: 2,
                    child: Icon(Icons.open_in_full, size: 14),
                  ),
                ],
              ),
            ),
          );
        }
      } else {
        if (col.type == TableColumnType.file) {
          valueWidget =
              isEmpty
                  ? Text(
                    _kEmptyCellDisplay,
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                  : _fileColumnIconButton(rawValue);
        } else {
          valueWidget = Text(
            isEmpty ? _kEmptyCellDisplay : rawValue,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                isEmpty
                    ? theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )
                    : null,
          );
        }
      }

      cells.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  style: Get.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    if (col.type == TableColumnType.image ||
                        col.type == TableColumnType.file)
                      valueWidget
                    else
                      Flexible(child: valueWidget),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (cells.isEmpty) {
      cells.add(
        Text(_primaryLabel(schema, row), overflow: TextOverflow.ellipsis),
      );
    }

    final Widget content = Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: Column(children: cells)),
          if (crudEnabled)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _createOrEditRow(schema, existing: row),
                ),
                if (showDeleteButton)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteRecord(schema, row),
                  ),
              ],
            ),
        ],
      ),
    );
    return Card(margin: const EdgeInsets.only(bottom: 8), child: content);
  }

  Future<void> _openImagePreview(String imagePath) async {
    await _ensureAppSupportPath();
    final String localPath = _resolveImagePathForDisplay(imagePath);
    final File file = File(localPath);
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700, maxHeight: 560),
            child: Column(
              children: <Widget>[
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4,
                      child:
                          file.existsSync()
                              ? Image.file(file, fit: BoxFit.contain)
                              : const Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('Image not found'),
                              ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openFilePreview(String filePath) async {
    final String fileName = _fileName(filePath);
    final String ext = _fileExtension(filePath).toUpperCase();
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(_fileIconFor(filePath)),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('File details')),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Name: $fileName'),
                  const SizedBox(height: 6),
                  Text('Type: ${ext.isEmpty ? 'Unknown' : ext}'),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    children: <Widget>[
                      FilledButton.icon(
                        onPressed: () => OpenFilex.open(filePath),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Open file'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => OpenFilex.open(filePath),
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('View locally'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _fileExtension(String path) {
    final String fileName = _fileName(path);
    final int dotIndex = fileName.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == fileName.length - 1) {
      return '';
    }
    return fileName.substring(dotIndex + 1).toLowerCase();
  }

  IconData _fileIconFor(String path) {
    final String ext = _fileExtension(path);
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'doc':
      case 'docx':
        return Icons.description_outlined;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_outlined;
      case 'txt':
        return Icons.notes_outlined;
      default:
        return Icons.attach_file;
    }
  }
}
