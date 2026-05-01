import 'dart:io';

import 'package:antwise/core/app_snackbar.dart';
import 'package:antwise/core/services/notification_runtime_service.dart';
import 'package:antwise/core/icons/app_icon_registry.dart';
import 'package:antwise/domain/entities/builder_page_entity.dart';
import 'package:antwise/domain/entities/builder_widget_entity.dart';
import 'package:antwise/domain/entities/card_widget_layout.dart';
import 'package:antwise/domain/entities/table_column_entity.dart';
import 'package:antwise/domain/entities/table_column_type.dart';
import 'package:antwise/domain/entities/table_text_validation_kind.dart';
import 'package:antwise/domain/entities/product_display_mode.dart';
import 'package:antwise/domain/entities/table_data_loading_mode.dart';
import 'package:antwise/domain/entities/table_layout_type.dart';
import 'package:antwise/domain/entities/table_list_design_layout.dart';
import 'package:antwise/domain/entities/table_kind.dart';
import 'package:antwise/domain/entities/table_mode.dart';
import 'package:antwise/domain/entities/table_row_entity.dart';
import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/domain/entities/table_validation_rule.dart';
import 'package:antwise/domain/dropdown/dropdown_column_options.dart';
import 'package:antwise/domain/summary/compute_summary_table_rows.dart';
import 'package:antwise/domain/formula/table_formula_evaluator.dart';
import 'package:antwise/domain/usecases/get_all_table_schemas_usecase.dart';
import 'package:antwise/domain/widgets/compute_card_widget_value.dart';
import 'package:antwise/domain/usecases/apply_affecting_tables_usecase.dart';
import 'package:antwise/domain/usecases/apply_inventory_deduction_usecase.dart';
import 'package:antwise/domain/usecases/delete_table_row_usecase.dart';
import 'package:antwise/domain/usecases/get_builder_widgets_by_page_usecase.dart';
import 'package:antwise/domain/usecases/get_table_rows_usecase.dart';
import 'package:antwise/domain/usecases/get_table_schema_by_id_usecase.dart';
import 'package:antwise/domain/usecases/get_table_schema_by_page_usecase.dart';
import 'package:antwise/domain/usecases/save_table_row_usecase.dart';
import 'package:antwise/domain/usecases/update_table_row_usecase.dart';
import 'package:antwise/presentation/bindings/builder_page_runtime_deps.dart';
import 'package:antwise/presentation/controllers/home_controller.dart';
import 'package:antwise/presentation/widgets/searchable_dropdown_field.dart';
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

TextInputType _textColumnKeyboard(TableTextValidationKind k) {
  return switch (k) {
    TableTextValidationKind.email => TextInputType.emailAddress,
    TableTextValidationKind.phone => TextInputType.phone,
    _ => TextInputType.text,
  };
}

Widget? _textColumnSuffixIcon(
  TableColumnEntity col,
  bool passwordFieldObscured,
  VoidCallback onTogglePasswordVisibility,
) {
  final bool isPwd = col.textValidationKind == TableTextValidationKind.password;
  final String? sk = col.textSuffixIconKey;
  if (isPwd) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          icon: Icon(
            passwordFieldObscured ? Icons.visibility : Icons.visibility_off,
          ),
          onPressed: onTogglePasswordVisibility,
        ),
        if (sk != null && sk.isNotEmpty) Icon(AppIconRegistry.iconOf(sk)),
      ],
    );
  }
  if (sk != null && sk.isNotEmpty) {
    return Icon(AppIconRegistry.iconOf(sk));
  }
  return null;
}

/// Column id seeded for Contact list layout ([CreateTableController.idContactAvatar]).
const String _kContactListAvatarColumnId = 'contact_avatar';

/// Shown when a table cell has no stored value.
const String _kEmptyCellDisplay = '-';

String _tableLayoutKey(String tableId) => 'table:$tableId';
String _chartLayoutKey(String widgetId) => 'chart:$widgetId';

enum _ChartDateGrouping { daily, weekly, monthly, yearly }

/// Compact, non-interactive table preview tile for layout pickers.
class TableLayoutOptionPreview extends StatelessWidget {
  const TableLayoutOptionPreview({
    super.key,
    required this.layout,
    this.productDisplayMode = ProductDisplayMode.list,
  });

  final TableListDesignLayout layout;
  final ProductDisplayMode productDisplayMode;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Widget rowPreview = switch (layout) {
      TableListDesignLayout.contact => _contactPreview(theme),
      TableListDesignLayout.product => _productPreview(theme),
      TableListDesignLayout.standard => _standardPreview(theme),
    };
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _tableShellHeader(theme),
              const SizedBox(height: 6),
              _tableShellSearch(theme),
              const SizedBox(height: 6),
              Expanded(
                child: ClipRect(
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: rowPreview,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              _tableShellFooter(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tableShellHeader(ThemeData theme) {
    final String title = switch (layout) {
      TableListDesignLayout.contact => 'Contacts',
      TableListDesignLayout.product => 'Products',
      TableListDesignLayout.standard => 'Inventory',
    };
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        FilledButton.icon(
          onPressed: () {},
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: const Size(0, 26),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            textStyle: theme.textTheme.labelSmall,
          ),
          icon: const Icon(Icons.add, size: 14),
          label: const Text('Add'),
        ),
      ],
    );
  }

  Widget _tableShellSearch(ThemeData theme) {
    return SizedBox(
      height: 28,
      child: TextField(
        enabled: false,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search...',
          hintStyle: theme.textTheme.labelSmall,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 6,
          ),
          prefixIcon: const Icon(Icons.search, size: 14),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 24,
            minHeight: 24,
          ),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _tableShellFooter(ThemeData theme) {
    return Row(
      children: <Widget>[
        Text(
          'Total: 1',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Icon(
          Icons.chevron_left,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('1', style: theme.textTheme.labelSmall),
        ),
        Icon(
          Icons.chevron_right,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }

  Widget _contactPreview(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    Icons.person,
                    size: 18,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Jane Cooper',
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Product Team',
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _previewRowActions(theme),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _productPreview(ThemeData theme) {
    if (productDisplayMode == ProductDisplayMode.grid) {
      return SizedBox(
        height: 110,
        child: Row(
          children: <Widget>[
            Expanded(
              child: _productGridTile(
                theme,
                name: 'Headphones',
                price: '\$129',
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _productGridTile(theme, name: 'Keyboard', price: '\$89'),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 40,
                  height: 40,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ColoredBox(
                      color: theme.colorScheme.primaryContainer,
                      child: Icon(
                        Icons.image_outlined,
                        size: 18,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Premium Headphones',
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '\$129',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _previewRowActions(theme),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _productGridTile(
    ThemeData theme, {
    required String name,
    required String price,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox.square(
              dimension: 64,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Icon(
                    Icons.image_outlined,
                    size: 14,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall,
            ),
            const SizedBox(height: 2),
            Text(
              price,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _standardPreview(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    children: <Widget>[
                      _kvRow(theme, 'Code', 'INV-001'),
                      _kvRow(theme, 'Name', 'Cable'),
                      _kvRow(theme, 'Qty', '24'),
                    ],
                  ),
                ),
                _previewRowActions(theme),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _previewRowActions(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          onPressed: () {},
          icon: const Icon(Icons.edit_outlined, size: 16),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          onPressed: () {},
          icon: const Icon(Icons.delete_outline, size: 16),
        ),
      ],
    );
  }

  Widget _kvRow(ThemeData theme, String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              key,
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class DynamicBuilderPageBody extends StatefulWidget {
  const DynamicBuilderPageBody({
    super.key,
    required this.page,
    this.contentRevision = 0,
    this.showNestedChildShell = true,
  });

  final BuilderPageEntity page;

  /// Bumps when tables/widgets are saved elsewhere so this body refetches schemas
  /// (e.g. [HomeController.refreshBuilderPageContent]).
  final int contentRevision;

  /// When false, this page never acts as a tab host for its child pages (used for
  /// the "root" tab that shows the parent's own widgets/tables).
  final bool showNestedChildShell;

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
  late final ApplyAffectingTablesUseCase _applyAffectingTables = Get.find();
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
  final Map<String, int> _touchedPieIndexByChartId = <String, int>{};
  final Map<String, _ChartDateGrouping> _selectedDateGroupingByChartId =
      <String, _ChartDateGrouping>{};
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
        oldWidget.contentRevision != widget.contentRevision ||
        oldWidget.showNestedChildShell != widget.showNestedChildShell) {
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
      rowsByTable[schema.id] = computeSummaryTableRows(
        summarySchema: schema,
        allSchemas: allSchemas,
        rowsByTableId: rowsByTable,
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
    final dynamic rawValue = _resolvedRowValues(schema, row)[columnId];
    if (rawValue == null) {
      return '';
    }
    TableColumnEntity? column;
    for (final TableColumnEntity candidate in schema.columns) {
      if (candidate.id == columnId) {
        column = candidate;
        break;
      }
    }
    if (column?.type == TableColumnType.date) {
      final DateTime? parsed = DateTime.tryParse(rawValue.toString().trim());
      if (parsed != null) {
        return _formatDate(parsed);
      }
    }
    return rawValue.toString();
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
          dateValues[c.id] =
              !isEdit && c.dateDefaultToday ? DateTime.now() : null;
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

    final Map<String, bool> textPasswordObscured = <String, bool>{};
    for (final TableColumnEntity c in columns) {
      if (c.type == TableColumnType.text &&
          c.textValidationKind == TableTextValidationKind.password) {
        textPasswordObscured[c.id] = true;
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
                    Text(isEdit ? 'Edit' : 'Add'),
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
                                    final String selectedValue =
                                        ctrl.text.trim();
                                    return SearchableDropdownField<String>(
                                      label: col.name,
                                      options: options,
                                      value:
                                          options.contains(selectedValue)
                                              ? selectedValue
                                              : null,
                                      optionLabel: (String option) => option,
                                      hintText: 'Search option...',
                                      onChanged: (String selected) {
                                        ctrl.text = selected;
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
                                TableColumnType.number =>
                                  (() {
                                    final TextEditingController ctrl =
                                        textCtrls[col.id]!;
                                    final bool allowDecimals =
                                        col.numberIntegerOnly
                                            ? false
                                            : col.numberAllowDecimals;
                                    final bool positiveOnly =
                                        col.numberPositiveOnly;
                                    final List<TextInputFormatter> formatters =
                                        <TextInputFormatter>[
                                          FilteringTextInputFormatter.allow(
                                            allowDecimals
                                                ? (positiveOnly
                                                    ? RegExp(r'^\d*\.?\d*$')
                                                    : RegExp(r'^-?\d*\.?\d*$'))
                                                : (positiveOnly
                                                    ? RegExp(r'^\d*$')
                                                    : RegExp(r'^-?\d*$')),
                                          ),
                                        ];
                                    void validateNow() {
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
                                    }

                                    void stepBy(double delta) {
                                      final double step =
                                          col.numberStepValue == 0
                                              ? 1
                                              : col.numberStepValue.abs();
                                      final double current =
                                          double.tryParse(ctrl.text.trim()) ??
                                          0;
                                      double next = current + delta * step;
                                      if (col.numberPositiveOnly && next < 0) {
                                        next = 0;
                                      }
                                      if (col.numberMinValue != null &&
                                          next < col.numberMinValue!) {
                                        next = col.numberMinValue!;
                                      }
                                      if (col.numberMaxValue != null &&
                                          next > col.numberMaxValue!) {
                                        next = col.numberMaxValue!;
                                      }
                                      ctrl.text =
                                          col.numberIntegerOnly ||
                                                  !allowDecimals
                                              ? next.round().toString()
                                              : next.toString();
                                      validateNow();
                                    }

                                    final InputDecoration
                                    decoration = InputDecoration(
                                      labelText: col.name,
                                      hintText: col.numberFieldHint,
                                      prefixIcon:
                                          (col.numberPrefixIconKey != null &&
                                                  col
                                                      .numberPrefixIconKey!
                                                      .isNotEmpty)
                                              ? Icon(
                                                AppIconRegistry.iconOf(
                                                  col.numberPrefixIconKey!,
                                                ),
                                              )
                                              : null,
                                      suffixIcon:
                                          (col.numberSuffixIconKey != null &&
                                                  col
                                                      .numberSuffixIconKey!
                                                      .isNotEmpty)
                                              ? Icon(
                                                AppIconRegistry.iconOf(
                                                  col.numberSuffixIconKey!,
                                                ),
                                              )
                                              : null,
                                      prefixText:
                                          (col.numberPrefixIconKey == null ||
                                                  col
                                                      .numberPrefixIconKey!
                                                      .isEmpty)
                                              ? col.numberPrefixText
                                              : null,
                                      suffixText:
                                          (col.numberSuffixIconKey == null ||
                                                  col
                                                      .numberSuffixIconKey!
                                                      .isEmpty)
                                              ? col.numberSuffixText
                                              : null,
                                    );

                                    final Widget numberField = TextField(
                                      controller: ctrl,
                                      decoration: decoration,
                                      keyboardType:
                                          TextInputType.numberWithOptions(
                                            decimal: allowDecimals,
                                            signed: !positiveOnly,
                                          ),
                                      inputFormatters: formatters,
                                      onChanged: (_) {
                                        setModalState(validateNow);
                                      },
                                    );

                                    if (!col.numberShowStepper) {
                                      return numberField;
                                    }
                                    return Row(
                                      children: <Widget>[
                                        OutlinedButton(
                                          onPressed: () {
                                            setModalState(() {
                                              stepBy(-1);
                                            });
                                          },
                                          child: const Text('-'),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(child: numberField),
                                        const SizedBox(width: 8),
                                        OutlinedButton(
                                          onPressed: () {
                                            setModalState(() {
                                              stepBy(1);
                                            });
                                          },
                                          child: const Text('+'),
                                        ),
                                      ],
                                    );
                                  })(),
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
                                TableColumnType.text =>
                                  (() {
                                    final bool isPwd =
                                        col.textValidationKind ==
                                        TableTextValidationKind.password;
                                    final bool pwdObscured =
                                        textPasswordObscured[col.id] ?? true;
                                    final String? hk =
                                        col.textFieldHint?.trim();
                                    final String? pfxKey =
                                        col.textPrefixIconKey;
                                    return TextField(
                                      controller: textCtrls[col.id],
                                      obscureText: isPwd && pwdObscured,
                                      keyboardType: _textColumnKeyboard(
                                        col.textValidationKind,
                                      ),
                                      autocorrect:
                                          col.textValidationKind !=
                                              TableTextValidationKind.email &&
                                          col.textValidationKind !=
                                              TableTextValidationKind.password,
                                      enableSuggestions:
                                          col.textValidationKind !=
                                          TableTextValidationKind.password,
                                      decoration: InputDecoration(
                                        labelText: col.name,
                                        hintText:
                                            (hk == null || hk.isEmpty)
                                                ? null
                                                : hk,
                                        prefixIcon:
                                            pfxKey != null && pfxKey.isNotEmpty
                                                ? Icon(
                                                  AppIconRegistry.iconOf(
                                                    pfxKey,
                                                  ),
                                                )
                                                : null,
                                        suffixIcon: _textColumnSuffixIcon(
                                          col,
                                          pwdObscured,
                                          () {
                                            setModalState(() {
                                              textPasswordObscured[col.id] =
                                                  !pwdObscured;
                                            });
                                          },
                                        ),
                                      ),
                                      onChanged: (_) {
                                        setModalState(() {
                                          final String? msg =
                                              TableRowModalFieldValidators.validate(
                                                col: col,
                                                textValue:
                                                    textCtrls[col.id]?.text,
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
      // Delay dispose to avoid "used after disposed" from lingering gesture/frame
      // callbacks still referencing the modal's controllers.
      Future<void>.microtask(() => _disposeTextControllersSafely(textCtrls));
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

    final String? validationError = _runCustomValidationRules(
      schema: schema,
      values: values,
    );
    if (validationError != null && validationError.isNotEmpty) {
      showAppSnackbar('Validation', validationError);
      Future<void>.microtask(() => _disposeTextControllersSafely(textCtrls));
      return;
    }

    final TableRowEntity row = TableRowEntity(
      id: existing?.id ?? _uuid.v4(),
      tableId: schema.id,
      values: values,
    );
    if (existing == null) {
      await _saveRow(row);
      try {
        final int triggeredCount =
            await NotificationRuntimeService.evaluateRulesForRowChange(
              tableId: row.tableId,
              rowId: row.id,
            );
        if (triggeredCount > 0) {
          // showAppSnackbar('Notification', 'Triggered $triggeredCount alert(s)');
          print('Triggered $triggeredCount alert(s)');
        }
      } catch (_) {
        /* best-effort; row is already saved */
      }
      if (schema.tableKind != TableKind.summary) {
        try {
          await _applyAffectingTables(
            sourceSchema: schema,
            configs: schema.affectingTables,
            allSchemas: _allSchemas,
            lineValues: values,
          );
        } catch (_) {
          /* best-effort; row is already saved */
        }
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
      showAppSnackbar('${schema.name} Table', 'Data added');
    } else {
      await _updateRow(row);
      try {
        final int triggeredCount =
            await NotificationRuntimeService.evaluateRulesForRowChange(
              tableId: row.tableId,
              rowId: row.id,
            );
        if (triggeredCount > 0) {
          // showAppSnackbar('Notification', 'Triggered $triggeredCount alert(s)');
          print('Triggered $triggeredCount alert(s)');
        }
      } catch (_) {
        /* best-effort; row is already updated */
      }
      if (schema.tableKind != TableKind.summary) {
        try {
          await _applyAffectingTables(
            sourceSchema: schema,
            configs: schema.affectingTables,
            allSchemas: _allSchemas,
            lineValues: values,
          );
        } catch (_) {
          /* best-effort; row is already updated */
        }
      }
      showAppSnackbar('${schema.name} Table', 'Data updated');
    }
    await _load();
    Future<void>.microtask(() => _disposeTextControllersSafely(textCtrls));
  }

  String _generateAutoValue(TableColumnEntity column, String tableId) {
    final DateTime now = DateTime.now();
    final String pattern =
        column.pattern?.trim().isNotEmpty == true
            ? column.pattern!.trim()
            : '{YYYY}-{RAND4}';
    return pattern
        .replaceAll('(DAY)', now.day.toString().padLeft(2, '0'))
        .replaceAll('(MONTH)', now.month.toString().padLeft(2, '0'))
        .replaceAll('(YEAR)', now.year.toString())
        .replaceAll('(YEAR-2dig)', (now.year % 100).toString().padLeft(2, '0'))
        .replaceAll(
          '(SEQ)',
          ((_rowsByTable[tableId]?.length ?? 0) + 1).toString().padLeft(4, '0'),
        )
        .replaceAll('(HOUR)', now.hour.toString().padLeft(2, '0'))
        .replaceAll('(MIN)', now.minute.toString().padLeft(2, '0'))
        .replaceAll('(USER)', 'USER')
        .replaceAll('(BRANCH)', 'MAIN')
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

  String? _runCustomValidationRules({
    required TableSchemaEntity schema,
    required Map<String, dynamic> values,
  }) {
    if (schema.validationRules.isEmpty) {
      return null;
    }
    for (final TableValidationRule rule in schema.validationRules) {
      if (!rule.enabled) {
        continue;
      }
      final String formula = rule.conditionFormula.trim();
      if (formula.isEmpty) {
        continue;
      }
      final String result = TableFormulaEvaluator.evaluate(
        formula: formula,
        currentSchema: schema,
        workingRowByColId: values,
        allSchemas: _allSchemas,
        rowsByTableId: _rowsByTable,
        forColumnId: null,
      );
      if (!_isValidationFormulaTrue(result)) {
        return rule.errorMessage.trim().isEmpty
            ? 'Validation failed for rule "${rule.name}".'
            : rule.errorMessage.trim();
      }
    }
    return null;
  }

  bool _isValidationFormulaTrue(String value) {
    final String normalized = value.trim().toLowerCase();
    if (normalized.isEmpty ||
        normalized == 'false' ||
        normalized == '0' ||
        normalized == 'no') {
      return false;
    }
    if (normalized == 'true' || normalized == 'yes') {
      return true;
    }
    final num? asNum = num.tryParse(normalized);
    if (asNum != null) {
      return asNum != 0;
    }
    return normalized == 'ok' || normalized == 'pass';
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
    showAppSnackbar('${schema.name} Table', 'Data deleted');
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
    const List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sept',
      'Oct',
      'Nov',
      'Dec',
    ];
    final String month = months[(date.month - 1).clamp(0, 11)];
    return '$month ${date.day}, ${date.year}';
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
    if (widget.showNestedChildShell && Get.isRegistered<HomeController>()) {
      return Obx(() {
        final HomeController home = Get.find<HomeController>();
        home.pages.length;
        final List<BuilderPageEntity> nestedChildren = _nestedChildPages(
          home,
          widget.page,
        );
        if (nestedChildren.isNotEmpty) {
          final String rootLabel =
              (widget.page.nestedRootContentTabName == null ||
                      widget.page.nestedRootContentTabName!.trim().isEmpty)
                  ? widget.page.name
                  : widget.page.nestedRootContentTabName!.trim();
          return _ParentNestedPageHost(
            parent: widget.page,
            children: nestedChildren,
            contentRevision: widget.contentRevision,
            includeParentOwnContent: true,
            ownContentLabel: rootLabel,
          );
        }
        return _buildMainPageContent(theme);
      });
    }
    return _buildMainPageContent(theme);
  }

  List<BuilderPageEntity> _nestedChildPages(
    HomeController home,
    BuilderPageEntity parent,
  ) {
    final List<BuilderPageEntity> out = home.pages
        .where(
          (BuilderPageEntity p) =>
              !p.isDeleted &&
              p.parentPageId == parent.id &&
              p.nestedDisplayType != null,
        )
        .toList(growable: false);
    out.sort(
      (BuilderPageEntity a, BuilderPageEntity b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return out;
  }

  Widget _buildMainPageContent(ThemeData theme) {
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
      case CardWidgetLayout.info:
      case CardWidgetLayout.simple:
      case CardWidgetLayout.customizable:
      case CardWidgetLayout.hero:
        final String heroName =
            card.config['heroCardName']?.toString().trim().isNotEmpty == true
                ? card.config['heroCardName'].toString().trim()
                : title;
        final String heroLabel =
            card.config['heroLabel']?.toString().trim() ?? 'Balance';
        final String heroHex =
            card.config['heroBackgroundHex']?.toString().trim() ?? '#4F46E5';
        final String heroImagePath =
            card.config['heroBackgroundImagePath']?.toString().trim() ?? '';
        final String heroPrefixType =
            card.config['heroPrefixType']?.toString().trim() ?? 'none';
        final String heroPrefixText =
            card.config['heroPrefixText']?.toString().trim() ?? '';
        final String? heroPrefixIconKey =
            card.config['heroPrefixIconKey']?.toString().trim();
        final String heroFormula =
            card.config['formula']?.toString().trim() ?? '';
        String heroValue = value;
        if (heroFormula.isNotEmpty && _allSchemas.isNotEmpty) {
          final String evaluated =
              TableFormulaEvaluator.evaluate(
                formula: heroFormula,
                currentSchema: _allSchemas.first,
                workingRowByColId: const <String, dynamic>{},
                allSchemas: _allSchemas,
                rowsByTableId: _rowsByTable,
                forColumnId: '_hero_card',
              ).trim();
          if (evaluated.isNotEmpty) {
            heroValue = evaluated;
          }
        }
        Color baseColor = cs.primary;
        var normalized = heroHex.replaceAll('#', '').trim();
        if (normalized.length == 6) {
          normalized = 'FF$normalized';
        }
        final int? parsedHex = int.tryParse(normalized, radix: 16);
        if (parsedHex != null) {
          baseColor = Color(parsedHex);
        }
        final File? backgroundFile =
            heroImagePath.isNotEmpty && File(heroImagePath).existsSync()
                ? File(heroImagePath)
                : null;
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(0.8)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              constraints: BoxConstraints(minHeight: compact ? 130 : 160),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    baseColor,
                    Color.lerp(baseColor, Colors.black, 0.28) ?? baseColor,
                  ],
                ),
                image:
                    backgroundFile != null
                        ? DecorationImage(
                          image: FileImage(backgroundFile),
                          fit: BoxFit.cover,
                          opacity: 0.42,
                        )
                        : null,
              ),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double width = constraints.maxWidth;
                  final bool veryNarrow = width <= 175;
                  final bool narrow = width <= 230;
                  final double bubbleScale =
                      veryNarrow ? 0.5 : (narrow || compact ? 0.7 : 1.0);
                  final double contentPadding =
                      veryNarrow ? 10 : (narrow ? 12 : 18);
                  final TextStyle? titleStyle = (veryNarrow
                          ? theme.textTheme.titleMedium
                          : narrow
                          ? theme.textTheme.titleLarge
                          : theme.textTheme.headlineSmall)
                      ?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      );
                  final TextStyle? labelStyle = (veryNarrow
                          ? theme.textTheme.bodySmall
                          : narrow
                          ? theme.textTheme.bodyMedium
                          : theme.textTheme.titleMedium)
                      ?.copyWith(color: Colors.white.withValues(alpha: 0.85));
                  final TextStyle? valueStyle = (veryNarrow
                          ? theme.textTheme.titleMedium
                          : narrow || compact
                          ? theme.textTheme.headlineSmall
                          : theme.textTheme.displaySmall)
                      ?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      );
                  final TextStyle? prefixStyle = (veryNarrow
                          ? theme.textTheme.titleSmall
                          : theme.textTheme.headlineMedium)
                      ?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      );

                  return Stack(
                    children: <Widget>[
                      Positioned(
                        right: -20 * bubbleScale,
                        top: 30 * bubbleScale,
                        child: _heroBubble(
                          90 * bubbleScale,
                          Colors.pinkAccent.withValues(alpha: 0.9),
                        ),
                      ),
                      Positioned(
                        left: 140 * bubbleScale,
                        top: 8 * bubbleScale,
                        child: _heroBubble(
                          110 * bubbleScale,
                          Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      Positioned(
                        left: 65 * bubbleScale,
                        top: 28 * bubbleScale,
                        child: _heroBubble(
                          140 * bubbleScale,
                          Colors.black.withValues(alpha: 0.12),
                        ),
                      ),
                      Positioned(
                        left: 24 * bubbleScale,
                        bottom: -50 * bubbleScale,
                        child: _heroBubble(
                          180 * bubbleScale,
                          Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(contentPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              heroName.isEmpty ? 'Card' : heroName,
                              maxLines: veryNarrow ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: titleStyle,
                            ),
                            SizedBox(height: veryNarrow ? 4 : 8),
                            Text(
                              heroLabel.isEmpty ? 'Balance' : heroLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: labelStyle,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: <Widget>[
                                if (heroPrefixType == 'text' &&
                                    heroPrefixText.isNotEmpty)
                                  Text(heroPrefixText, style: prefixStyle),
                                if (heroPrefixType == 'icon' &&
                                    heroPrefixIconKey != null &&
                                    heroPrefixIconKey.isNotEmpty) ...<Widget>[
                                  Icon(
                                    AppIconRegistry.iconOf(heroPrefixIconKey),
                                    color: Colors.white,
                                    size: veryNarrow ? 18 : 24,
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Expanded(
                                  child: Text(
                                    heroValue.isEmpty ? '—' : heroValue,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: valueStyle,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      case CardWidgetLayout.percent:
        final String percentName =
            card.config['percentCardName']?.toString().trim().isNotEmpty == true
                ? card.config['percentCardName'].toString().trim()
                : title;
        final String percentLabel =
            card.config['percentLabel']?.toString().trim() ?? 'invoice.docx';
        final String percentHex =
            card.config['percentBackgroundHex']?.toString().trim() ?? '#2F80ED';
        final String percentImagePath =
            card.config['percentBackgroundImagePath']?.toString().trim() ?? '';
        final String? percentIconKey =
            card.config['percentIconKey']?.toString().trim();
        final String percentFormula =
            card.config['percentFormula']?.toString().trim() ??
            card.config['formula']?.toString().trim() ??
            '';
        double resolvedPercent =
            (card.config['percentValue'] as num?)?.toDouble() ??
            _toDouble(value) ??
            0;
        if (percentFormula.isNotEmpty && _allSchemas.isNotEmpty) {
          final String evaluated = TableFormulaEvaluator.evaluate(
            formula: percentFormula,
            currentSchema: _allSchemas.first,
            workingRowByColId: const <String, dynamic>{},
            allSchemas: _allSchemas,
            rowsByTableId: _rowsByTable,
            forColumnId: '_percent_card',
          );
          final double? numeric = _toDouble(evaluated);
          if (numeric != null) {
            resolvedPercent = numeric;
          }
        }
        final double percent = resolvedPercent.clamp(0, 100);
        Color percentBaseColor = const Color(0xFF2F80ED);
        var percentNormalized = percentHex.replaceAll('#', '').trim();
        if (percentNormalized.length == 6) {
          percentNormalized = 'FF$percentNormalized';
        }
        final int? percentParsed = int.tryParse(percentNormalized, radix: 16);
        if (percentParsed != null) {
          percentBaseColor = Color(percentParsed);
        }
        final File? percentBackgroundFile =
            percentImagePath.isNotEmpty && File(percentImagePath).existsSync()
                ? File(percentImagePath)
                : null;
        return ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            constraints: BoxConstraints(minHeight: compact ? 130 : 160),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  percentBaseColor,
                  Color.lerp(percentBaseColor, Colors.black, 0.18) ??
                      percentBaseColor,
                ],
              ),
              image:
                  percentBackgroundFile != null
                      ? DecorationImage(
                        image: FileImage(percentBackgroundFile),
                        fit: BoxFit.cover,
                        opacity: 0.3,
                      )
                      : null,
            ),
            child: Padding(
              padding: EdgeInsets.all(compact ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      _percentFileTilePill(
                        compact: compact,
                        iconKey: percentIconKey,
                      ),
                      SizedBox(width: compact ? 8 : 12),
                      Expanded(
                        child: Text(
                          percentName.isEmpty ? 'Uploading' : percentName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: (compact
                                  ? theme.textTheme.titleMedium
                                  : theme.textTheme.titleLarge)
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 12 : 16),
                  LinearProgressIndicator(
                    minHeight: compact ? 4 : 5,
                    value: percent / 100,
                    backgroundColor: Colors.white.withValues(alpha: 0.22),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                  SizedBox(height: compact ? 8 : 12),
                  Row(
                    children: <Widget>[
                      Text(
                        '${percent.toStringAsFixed(0)}%',
                        style: (compact
                                ? theme.textTheme.titleLarge
                                : theme.textTheme.headlineSmall)
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const Spacer(),
                      Expanded(
                        child: Text(
                          percentLabel.isEmpty ? 'invoice.docx' : percentLabel,
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: (compact
                                  ? theme.textTheme.bodyMedium
                                  : theme.textTheme.titleLarge)
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontWeight: FontWeight.w400,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
    }
  }

  Widget _percentFileTilePill({required bool compact, String? iconKey}) {
    return Container(
      width: compact ? 28 : 34,
      height: compact ? 28 : 34,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(compact ? 9 : 11),
      ),
      child: Stack(
        children: <Widget>[
          Center(
            child: Icon(
              iconKey == null || iconKey.isEmpty
                  ? Icons.description_outlined
                  : AppIconRegistry.iconOf(iconKey),
              color: Colors.white,
              size: compact ? 16 : 18,
            ),
          ),
          Positioned(
            right: compact ? 4 : 5,
            bottom: compact ? 3 : 4,
            child: Text(
              '2',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: compact ? 8 : 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroBubble(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
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
    final List<_ChartDateGrouping> enabledDateFilters = _readEnabledDateFilters(
      chartWidget.config['enabledDateFilters'],
    );

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
    TableColumnEntity? xColumn;
    for (final TableColumnEntity col in table.columns) {
      if (col.id == xColumnId) {
        xColumn = col;
        break;
      }
    }
    final bool canUseDateGrouping =
        chartType == 'line' &&
        xColumn?.type == TableColumnType.date &&
        enabledDateFilters.isNotEmpty;
    final _ChartDateGrouping activeDateGrouping =
        _selectedDateGroupingByChartId[chartWidget.id] ??
        _firstDateGroupingOrDefault(enabledDateFilters);
    if (canUseDateGrouping &&
        !_selectedDateGroupingByChartId.containsKey(chartWidget.id)) {
      _selectedDateGroupingByChartId[chartWidget.id] = activeDateGrouping;
    }
    final List<({String label, double value})> points =
        canUseDateGrouping
            ? _buildDateGroupedChartPoints(
              rows: rows,
              table: table,
              xColumnId: xColumnId,
              yColumnId: yColumnId,
              formula: formula,
              grouping: activeDateGrouping,
            )
            : _buildDefaultChartPoints(
              rows: rows,
              table: table,
              xColumn: xColumn,
              xColumnId: xColumnId,
              yColumnId: yColumnId,
              formula: formula,
            );

    if (points.isEmpty) {
      return _buildNoDataChartCard(
        theme: theme,
        title: title,
        chartType: chartType,
        compact: compact,
      );
    }

    final double chartHeight = compact ? 160 : 220;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(0.9)),
      child: Card(
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
              if (canUseDateGrouping) ...<Widget>[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: enabledDateFilters
                      .map((_ChartDateGrouping grouping) {
                        return ChoiceChip(
                          label: Text(_dateGroupingLabel(grouping)),
                          selected: activeDateGrouping == grouping,
                          onSelected: (bool selected) {
                            if (!selected) {
                              return;
                            }
                            setState(() {
                              _selectedDateGroupingByChartId[chartWidget.id] =
                                  grouping;
                            });
                          },
                        );
                      })
                      .toList(growable: false),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                height: chartHeight,
                child: switch (chartType) {
                  'line' => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildLineChart(points, theme),
                  ),
                  'pie' => _buildPieChart(points, theme, chartWidget.id),
                  _ => _buildBarChart(points, theme),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoDataChartCard({
    required ThemeData theme,
    required String title,
    required String chartType,
    required bool compact,
  }) {
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
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  if (chartType == 'line')
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildLineNoDataBackdrop(theme),
                    )
                  else if (chartType == 'pie')
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildPieNoDataBackdrop(theme),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildBarNoDataBackdrop(theme),
                    ),
                  Text(
                    'No Data',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineNoDataBackdrop(ThemeData theme) {
    final Color muted = theme.colorScheme.outlineVariant.withValues(
      alpha: 0.55,
    );
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 8,
        borderData: FlBorderData(show: true, border: Border.all(color: muted)),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          getDrawingHorizontalLine:
              (_) =>
                  FlLine(color: muted.withValues(alpha: 0.45), strokeWidth: 1),
          getDrawingVerticalLine:
              (_) =>
                  FlLine(color: muted.withValues(alpha: 0.45), strokeWidth: 1),
        ),
        lineTouchData: const LineTouchData(enabled: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 2,
              reservedSize: 28,
              getTitlesWidget:
                  (double value, TitleMeta meta) => Text(
                    value.toInt().toString(),
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget:
                  (double value, TitleMeta meta) => Text(
                    'Label ${value.toInt()}',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
            ),
          ),
        ),
        lineBarsData: <LineChartBarData>[
          LineChartBarData(
            spots: const <FlSpot>[
              FlSpot(0, 5),
              FlSpot(1, 8),
              FlSpot(2, 7),
              FlSpot(3, 6),
              FlSpot(4, 2),
            ],
            isCurved: false,
            barWidth: 2.5,
            color: muted,
            dotData: FlDotData(show: false),
          ),
        ],
      ),
    );
  }

  Widget _buildPieNoDataBackdrop(ThemeData theme) {
    final Color muted = theme.colorScheme.outlineVariant.withValues(
      alpha: 0.55,
    );
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 52,
        sections: <PieChartSectionData>[
          PieChartSectionData(value: 24, color: muted.withValues(alpha: 0.9)),
          PieChartSectionData(value: 20, color: muted.withValues(alpha: 0.75)),
          PieChartSectionData(value: 18, color: muted.withValues(alpha: 0.65)),
          PieChartSectionData(value: 15, color: muted.withValues(alpha: 0.55)),
          PieChartSectionData(value: 23, color: muted.withValues(alpha: 0.45)),
        ],
      ),
    );
  }

  Widget _buildBarNoDataBackdrop(ThemeData theme) {
    final Color muted = theme.colorScheme.outlineVariant.withValues(
      alpha: 0.55,
    );
    return BarChart(
      BarChartData(
        minY: 0,
        maxY: 8,
        borderData: FlBorderData(show: true, border: Border.all(color: muted)),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          getDrawingHorizontalLine:
              (_) =>
                  FlLine(color: muted.withValues(alpha: 0.45), strokeWidth: 1),
          getDrawingVerticalLine:
              (_) =>
                  FlLine(color: muted.withValues(alpha: 0.45), strokeWidth: 1),
        ),
        barTouchData: const BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 2,
              reservedSize: 28,
              getTitlesWidget:
                  (double value, TitleMeta meta) => Text(
                    value.toInt().toString(),
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget:
                  (double value, TitleMeta meta) => Text(
                    'Label ${value.toInt()}',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
            ),
          ),
        ),
        barGroups: <BarChartGroupData>[
          for (int i = 0; i < 5; i++)
            BarChartGroupData(
              x: i,
              barRods: <BarChartRodData>[
                BarChartRodData(
                  toY: <double>[5, 8, 7, 6, 2][i],
                  width: 24,
                  color: muted.withValues(alpha: 0.7),
                ),
              ],
            ),
        ],
      ),
    );
  }

  _ChartDateGrouping _firstDateGroupingOrDefault(
    List<_ChartDateGrouping> enabled,
  ) {
    if (enabled.isNotEmpty) {
      return enabled.first;
    }
    return _ChartDateGrouping.daily;
  }

  List<_ChartDateGrouping> _readEnabledDateFilters(dynamic raw) {
    final List<_ChartDateGrouping> out = <_ChartDateGrouping>[];
    if (raw is! List) {
      return out;
    }
    for (final dynamic item in raw) {
      final String token = item.toString().trim().toLowerCase();
      for (final _ChartDateGrouping g in _ChartDateGrouping.values) {
        if (g.name == token) {
          out.add(g);
          break;
        }
      }
    }
    const List<_ChartDateGrouping> order = <_ChartDateGrouping>[
      _ChartDateGrouping.daily,
      _ChartDateGrouping.weekly,
      _ChartDateGrouping.monthly,
      _ChartDateGrouping.yearly,
    ];
    final List<_ChartDateGrouping> sorted = <_ChartDateGrouping>[];
    for (final _ChartDateGrouping g in order) {
      if (out.contains(g)) {
        sorted.add(g);
      }
    }
    return sorted;
  }

  String _dateGroupingLabel(_ChartDateGrouping grouping) {
    return switch (grouping) {
      _ChartDateGrouping.daily => 'Daily',
      _ChartDateGrouping.weekly => 'Weekly',
      _ChartDateGrouping.monthly => 'Monthly',
      _ChartDateGrouping.yearly => 'Yearly',
    };
  }

  List<({String label, double value})> _buildDefaultChartPoints({
    required List<TableRowEntity> rows,
    required TableSchemaEntity table,
    required TableColumnEntity? xColumn,
    required String xColumnId,
    required String? yColumnId,
    required String formula,
  }) {
    final Map<String, double> groupedPoints = <String, double>{};
    for (final TableRowEntity row in rows) {
      final Map<String, dynamic> resolved = _resolvedRowValues(table, row);
      final String rawLabel =
          (resolved[xColumnId] ?? row.values[xColumnId] ?? '').toString();
      String label = rawLabel.trim();
      if (xColumn?.type == TableColumnType.date && label.isNotEmpty) {
        final DateTime? parsed = DateTime.tryParse(label);
        if (parsed != null) {
          label = _formatDate(parsed);
        }
      }
      if (label.isEmpty) {
        continue;
      }
      final double? value = _chartPointValue(
        row: row,
        table: table,
        resolved: resolved,
        yColumnId: yColumnId,
        formula: formula,
      );
      if (value == null) {
        continue;
      }
      groupedPoints.update(
        label,
        (double old) => old + value,
        ifAbsent: () => value,
      );
    }
    return groupedPoints.entries
        .map((MapEntry<String, double> e) => (label: e.key, value: e.value))
        .toList(growable: false);
  }

  List<({String label, double value})> _buildDateGroupedChartPoints({
    required List<TableRowEntity> rows,
    required TableSchemaEntity table,
    required String xColumnId,
    required String? yColumnId,
    required String formula,
    required _ChartDateGrouping grouping,
  }) {
    final Map<String, ({double total, DateTime sortDate})> grouped =
        <String, ({double total, DateTime sortDate})>{};
    for (final TableRowEntity row in rows) {
      final Map<String, dynamic> resolved = _resolvedRowValues(table, row);
      final String rawLabel =
          (resolved[xColumnId] ?? row.values[xColumnId] ?? '')
              .toString()
              .trim();
      final DateTime? date = DateTime.tryParse(rawLabel);
      if (date == null) {
        continue;
      }
      final double? value = _chartPointValue(
        row: row,
        table: table,
        resolved: resolved,
        yColumnId: yColumnId,
        formula: formula,
      );
      if (value == null) {
        continue;
      }
      final ({String label, DateTime sortDate}) bucket = _dateBucket(
        date,
        grouping,
      );
      final ({double total, DateTime sortDate})? existing =
          grouped[bucket.label];
      if (existing == null) {
        grouped[bucket.label] = (total: value, sortDate: bucket.sortDate);
      } else {
        grouped[bucket.label] = (
          total: existing.total + value,
          sortDate: existing.sortDate,
        );
      }
    }
    final List<({String label, double value, DateTime sortDate})> entries =
        grouped.entries
            .map(
              (MapEntry<String, ({double total, DateTime sortDate})> e) => (
                label: e.key,
                value: e.value.total,
                sortDate: e.value.sortDate,
              ),
            )
            .toList(growable: false)
          ..sort((a, b) => a.sortDate.compareTo(b.sortDate));
    return entries
        .map((e) => (label: e.label, value: e.value))
        .toList(growable: false);
  }

  ({String label, DateTime sortDate}) _dateBucket(
    DateTime date,
    _ChartDateGrouping grouping,
  ) {
    switch (grouping) {
      case _ChartDateGrouping.daily:
        return (
          label: _formatDate(date),
          sortDate: DateTime(date.year, date.month, date.day),
        );
      case _ChartDateGrouping.weekly:
        final DateTime monday = date.subtract(
          Duration(days: date.weekday - DateTime.monday),
        );
        final DateTime firstMonday = DateTime(monday.year, 1, 1).subtract(
          Duration(days: DateTime(monday.year, 1, 1).weekday - DateTime.monday),
        );
        final int week = (monday.difference(firstMonday).inDays ~/ 7) + 1;
        return (
          label: 'W${week.toString().padLeft(2, '0')} ${monday.year}',
          sortDate: DateTime(monday.year, monday.month, monday.day),
        );
      case _ChartDateGrouping.monthly:
        final DateTime monthDate = DateTime(date.year, date.month, 1);
        const List<String> m = <String>[
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        return (
          label: '${m[date.month - 1]} ${date.year}',
          sortDate: monthDate,
        );
      case _ChartDateGrouping.yearly:
        return (label: '${date.year}', sortDate: DateTime(date.year, 1, 1));
    }
  }

  double? _chartPointValue({
    required TableRowEntity row,
    required TableSchemaEntity table,
    required Map<String, dynamic> resolved,
    required String? yColumnId,
    required String formula,
  }) {
    if (formula.isNotEmpty) {
      final String raw = TableFormulaEvaluator.evaluate(
        formula: formula,
        currentSchema: table,
        workingRowByColId: row.values,
        allSchemas: _allSchemas,
        rowsByTableId: _rowsByTable,
        forColumnId: '_chart',
      );
      return _toDouble(raw);
    }
    if (yColumnId != null && yColumnId.isNotEmpty) {
      return _toDouble(
        (resolved[yColumnId] ?? row.values[yColumnId]).toString(),
      );
    }
    return null;
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
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (
              BarChartGroupData group,
              int groupIndex,
              BarChartRodData rod,
              int rodIndex,
            ) {
              final int idx = group.x.toInt();
              final String label =
                  idx >= 0 && idx < points.length ? points[idx].label : '';
              return BarTooltipItem(
                '$label\n${rod.toY.toStringAsFixed(2)}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
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
    final double maxPoint = points.fold<double>(
      0,
      (double prev, ({String label, double value}) point) =>
          point.value > prev ? point.value : prev,
    );
    final double maxY =
        maxPoint <= 0 ? 1 : (maxPoint * 1.1).clamp(1, double.infinity);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(0.8)),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: true),
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots
                    .map((LineBarSpot spot) {
                      final int idx = spot.x.toInt();
                      final String label =
                          idx >= 0 && idx < points.length
                              ? points[idx].label
                              : '';
                      return LineTooltipItem(
                        '$label\n${spot.y.toStringAsFixed(2)}',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    })
                    .toList(growable: false);
              },
            ),
          ),
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
      ),
    );
  }

  Widget _buildPieChart(
    List<({String label, double value})> points,
    ThemeData theme,
    String chartWidgetId,
  ) {
    final List<Color> palette = <Color>[
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      theme.colorScheme.tertiary,
      theme.colorScheme.primaryContainer,
      theme.colorScheme.secondaryContainer,
      theme.colorScheme.tertiaryContainer,
    ];
    return Column(
      children: <Widget>[
        const SizedBox(height: 50),
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 10,
              pieTouchData: PieTouchData(
                enabled: true,
                touchCallback: (
                  FlTouchEvent event,
                  PieTouchResponse? response,
                ) {
                  if (!mounted) {
                    return;
                  }
                  final int? idx =
                      response?.touchedSection?.touchedSectionIndex;
                  setState(() {
                    if (event.isInterestedForInteractions && idx != null) {
                      _touchedPieIndexByChartId[chartWidgetId] = idx;
                    } else {
                      _touchedPieIndexByChartId.remove(chartWidgetId);
                    }
                  });
                },
              ),
              sections: <PieChartSectionData>[
                for (int i = 0; i < points.length; i++)
                  PieChartSectionData(
                    value: points[i].value <= 0 ? 0.01 : points[i].value,
                    color: palette[i % palette.length],
                    title: points[i].label,
                    radius:
                        _touchedPieIndexByChartId[chartWidgetId] == i ? 80 : 74,
                    titleStyle: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    badgeWidget:
                        _touchedPieIndexByChartId[chartWidgetId] == i
                            ? DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Text(
                                  '${points[i].label}\n${points[i].value.toStringAsFixed(2)}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                            : null,
                    badgePositionPercentageOffset: 1.3,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 50),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 6,
          children: <Widget>[
            for (int i = 0; i < points.length; i++)
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (_touchedPieIndexByChartId[chartWidgetId] == i) {
                      _touchedPieIndexByChartId.remove(chartWidgetId);
                    } else {
                      _touchedPieIndexByChartId[chartWidgetId] = i;
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        _touchedPieIndexByChartId[chartWidgetId] == i
                            ? theme.colorScheme.surfaceContainerHighest
                            : theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: palette[i % palette.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${points[i].label}: ${points[i].value.toStringAsFixed(2)}',
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
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
                      label: const Text('Add'),
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
                            label: const Text('Add'),
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
      if (priceCol == null && c.type == TableColumnType.number) {
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
                          : _darkModeLightPrimary(theme),
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
      child: InkWell(
        onTap:
            crudEnabled
                ? () => _openCrudRowDetailsBottomSheet(schema, row)
                : null,
        child: body,
      ),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap:
            crudEnabled
                ? () => _openCrudRowDetailsBottomSheet(schema, row)
                : null,
        child: content,
      ),
    );
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
      if (priceCol == null && c.type == TableColumnType.number) {
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
                            : _darkModeLightPrimary(theme),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap:
            crudEnabled
                ? () => _openCrudRowDetailsBottomSheet(schema, row)
                : null,
        child: content,
      ),
    );
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap:
            crudEnabled
                ? () => _openCrudRowDetailsBottomSheet(schema, row)
                : null,
        child: content,
      ),
    );
  }

  Future<void> _openCrudRowDetailsBottomSheet(
    TableSchemaEntity schema,
    TableRowEntity row,
  ) async {
    final ThemeData theme = Theme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(schema.name, style: theme.textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  _primaryLabel(schema, row),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: SingleChildScrollView(
                    child: Builder(
                      builder: (BuildContext context) {
                        bool skippedPrimary = false;
                        final List<Widget> detailRows = <Widget>[];
                        for (final TableColumnEntity col in schema.columns) {
                          final String value =
                              _displayCell(schema, row, col.id).trim();
                          if (!skippedPrimary && value.isNotEmpty) {
                            skippedPrimary = true;
                            continue;
                          }
                          final String shown =
                              value.isEmpty ? _kEmptyCellDisplay : value;
                          detailRows.add(
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      col.name,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color:
                                                theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      shown,
                                      textAlign: TextAlign.right,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return Column(children: detailRows);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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

NestedPageDisplayType _resolveNestedDisplayType(
  List<BuilderPageEntity> children,
) {
  for (final BuilderPageEntity c in children) {
    if (c.nestedDisplayType != null) {
      return c.nestedDisplayType!;
    }
  }
  return NestedPageDisplayType.tab;
}

/// Renders child pages under [parent] using tabs or a segmented control.
class _ParentNestedPageHost extends StatefulWidget {
  const _ParentNestedPageHost({
    required this.parent,
    required this.children,
    required this.contentRevision,
    this.includeParentOwnContent = false,
    this.ownContentLabel = '',
  });

  final BuilderPageEntity parent;
  final List<BuilderPageEntity> children;
  final int contentRevision;
  final bool includeParentOwnContent;
  final String ownContentLabel;

  @override
  State<_ParentNestedPageHost> createState() => _ParentNestedPageHostState();
}

class _ParentNestedPageHostState extends State<_ParentNestedPageHost>
    with TickerProviderStateMixin {
  late TabController _tabController;
  int _segmentIndex = 0;

  int get _tabCount {
    if (widget.children.isEmpty) {
      return 0;
    }
    return widget.children.length + (widget.includeParentOwnContent ? 1 : 0);
  }

  int get _maxSegmentIndex {
    final int c = _tabCount;
    return c > 0 ? c - 1 : 0;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabCount < 1 ? 1 : _tabCount,
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(covariant _ParentNestedPageHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.children.length != widget.children.length ||
        oldWidget.includeParentOwnContent != widget.includeParentOwnContent) {
      final int newLen = _tabCount;
      _tabController.dispose();
      _tabController = TabController(
        length: newLen < 1 ? 1 : newLen,
        vsync: this,
      );
      if (_segmentIndex > _maxSegmentIndex) {
        _segmentIndex = _maxSegmentIndex;
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) {
      return const SizedBox.shrink();
    }
    final ThemeData theme = Theme.of(context);
    final Color activeTabColor = _activeTabColor(theme);
    final NestedPageDisplayType displayType = _resolveNestedDisplayType(
      widget.children,
    );
    if (displayType == NestedPageDisplayType.tab) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Material(
            color: theme.colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              labelPadding: const EdgeInsets.symmetric(horizontal: 30),
              labelColor: activeTabColor,
              indicatorColor: activeTabColor,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              tabs: <Widget>[
                if (widget.includeParentOwnContent)
                  Tab(
                    text:
                        widget.ownContentLabel.isEmpty
                            ? widget.parent.name
                            : widget.ownContentLabel,
                  ),
                for (final BuilderPageEntity c in widget.children)
                  Tab(text: c.name),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: <Widget>[
                if (widget.includeParentOwnContent)
                  DynamicBuilderPageBody(
                    key: ValueKey<String>('nested-root-${widget.parent.id}'),
                    page: widget.parent,
                    contentRevision: widget.contentRevision,
                    showNestedChildShell: false,
                  ),
                for (final BuilderPageEntity c in widget.children)
                  DynamicBuilderPageBody(
                    key: ValueKey<String>('nested-${c.id}'),
                    page: c,
                    contentRevision: widget.contentRevision,
                  ),
              ],
            ),
          ),
        ],
      );
    }
    final int safeIndex = _segmentIndex.clamp(0, _maxSegmentIndex);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: <ButtonSegment<int>>[
              if (widget.includeParentOwnContent)
                ButtonSegment<int>(
                  value: 0,
                  label: Text(
                    widget.ownContentLabel.isEmpty
                        ? widget.parent.name
                        : widget.ownContentLabel,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              for (int i = 0; i < widget.children.length; i++)
                ButtonSegment<int>(
                  value: widget.includeParentOwnContent ? i + 1 : i,
                  label: Text(
                    widget.children[i].name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            selected: <int>{safeIndex},
            onSelectionChanged: (Set<int> next) {
              if (next.isEmpty) {
                return;
              }
              setState(() {
                _segmentIndex = next.first;
              });
            },
          ),
        ),
        Expanded(child: _segmentBodyAt(safeIndex)),
      ],
    );
  }

  Widget _segmentBodyAt(int index) {
    if (widget.includeParentOwnContent) {
      if (index == 0) {
        return DynamicBuilderPageBody(
          key: ValueKey<String>('nested-seg-root-${widget.parent.id}'),
          page: widget.parent,
          contentRevision: widget.contentRevision,
          showNestedChildShell: false,
        );
      }
      final BuilderPageEntity c = widget.children[index - 1];
      return DynamicBuilderPageBody(
        key: ValueKey<String>('nested-seg-${c.id}'),
        page: c,
        contentRevision: widget.contentRevision,
      );
    }
    final BuilderPageEntity c = widget.children[index];
    return DynamicBuilderPageBody(
      key: ValueKey<String>('nested-seg-${c.id}'),
      page: c,
      contentRevision: widget.contentRevision,
    );
  }
}

Color _activeTabColor(ThemeData theme) {
  if (theme.brightness != Brightness.dark) {
    return theme.colorScheme.primary;
  }
  return Color.alphaBlend(
    Colors.white.withValues(alpha: 0.22),
    theme.colorScheme.primary,
  );
}

Color _darkModeLightPrimary(ThemeData theme) {
  if (theme.brightness != Brightness.dark) {
    return theme.colorScheme.primary;
  }
  return Color.alphaBlend(
    Colors.white.withValues(alpha: 0.42),
    theme.colorScheme.primary,
  );
}
