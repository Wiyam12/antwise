import 'package:antwise/core/services/ai/ai_build_action.dart';
import 'package:antwise/domain/entities/bottom_nav_layout_type.dart';
import 'package:antwise/domain/entities/builder_page_entity.dart';
import 'package:antwise/domain/entities/builder_widget_entity.dart';
import 'package:antwise/domain/entities/drawer_nav_layout_type.dart';
import 'package:antwise/domain/entities/navigation_config_entity.dart';
import 'package:antwise/domain/entities/table_affecting_config.dart';
import 'package:antwise/domain/entities/table_column_entity.dart';
import 'package:antwise/domain/entities/table_column_type.dart';
import 'package:antwise/domain/entities/table_data_loading_mode.dart';
import 'package:antwise/domain/entities/table_kind.dart';
import 'package:antwise/domain/entities/table_mode.dart';
import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/domain/entities/table_summary_config.dart';
import 'package:antwise/domain/entities/table_validation_rule.dart';
import 'package:antwise/domain/usecases/delete_builder_widget_usecase.dart';
import 'package:antwise/domain/usecases/delete_rows_by_table_usecase.dart';
import 'package:antwise/domain/usecases/delete_table_schema_usecase.dart';
import 'package:antwise/domain/usecases/get_all_builder_widgets_usecase.dart';
import 'package:antwise/domain/usecases/get_builder_pages_usecase.dart';
import 'package:antwise/domain/usecases/get_all_table_schemas_usecase.dart';
import 'package:antwise/domain/usecases/get_builder_widgets_by_page_usecase.dart';
import 'package:antwise/domain/usecases/get_navigation_config_usecase.dart';
import 'package:antwise/domain/usecases/replace_builder_pages_usecase.dart';
import 'package:antwise/domain/usecases/save_builder_page_usecase.dart';
import 'package:antwise/domain/usecases/save_builder_widget_usecase.dart';
import 'package:antwise/domain/usecases/save_navigation_config_usecase.dart';
import 'package:antwise/domain/usecases/save_table_schema_usecase.dart';
import 'package:uuid/uuid.dart';

/// Outcome of running a single Build action.
class AiBuildActionExecutionResult {
  const AiBuildActionExecutionResult({
    required this.success,
    this.createdId,
    this.errorMessage,
    this.resolvedName,
  });

  final bool success;
  final String? createdId;
  final String? errorMessage;

  /// Final user-visible name after auto-resolving collisions. Null when the
  /// proposed name was already unique. The controller propagates this back
  /// onto the action so the checklist row reflects what was actually saved.
  final String? resolvedName;

  static AiBuildActionExecutionResult ok(String id, {String? resolvedName}) =>
      AiBuildActionExecutionResult(
        success: true,
        createdId: id,
        resolvedName: resolvedName,
      );

  static AiBuildActionExecutionResult failure(String message) =>
      AiBuildActionExecutionResult(success: false, errorMessage: message);
}

/// Applies one [AiBuildAction] at a time using existing builder use cases.
///
/// The executor is **idempotent per call**: it always fetches the latest pages
/// / tables before mutating, so applying one action and then another from the
/// same batch composes safely. Sibling actions in the same chat message
/// reference each other via `ref` / `pageRef` / `tableRef`. Refs may also point
/// at the **name** of an existing page or table.
class AiBuildActionExecutor {
  AiBuildActionExecutor({
    required SaveBuilderPageUseCase saveBuilderPage,
    required ReplaceBuilderPagesUseCase replaceBuilderPages,
    required GetBuilderPagesUseCase getBuilderPages,
    required SaveTableSchemaUseCase saveTableSchema,
    required GetAllTableSchemasUseCase getAllTableSchemas,
    required DeleteTableSchemaUseCase deleteTableSchema,
    required DeleteRowsByTableUseCase deleteRowsByTable,
    required SaveBuilderWidgetUseCase saveBuilderWidget,
    required GetBuilderWidgetsByPageUseCase getBuilderWidgetsByPage,
    required GetAllBuilderWidgetsUseCase getAllBuilderWidgets,
    required DeleteBuilderWidgetUseCase deleteBuilderWidget,
    required GetNavigationConfigUseCase getNavigationConfig,
    required SaveNavigationConfigUseCase saveNavigationConfig,
  })  : _saveBuilderPage = saveBuilderPage,
        _replaceBuilderPages = replaceBuilderPages,
        _getBuilderPages = getBuilderPages,
        _saveTableSchema = saveTableSchema,
        _getAllTableSchemas = getAllTableSchemas,
        _deleteTableSchema = deleteTableSchema,
        _deleteRowsByTable = deleteRowsByTable,
        _saveBuilderWidget = saveBuilderWidget,
        _getBuilderWidgetsByPage = getBuilderWidgetsByPage,
        _getAllBuilderWidgets = getAllBuilderWidgets,
        _deleteBuilderWidget = deleteBuilderWidget,
        _getNavigationConfig = getNavigationConfig,
        _saveNavigationConfig = saveNavigationConfig;

  static const Uuid _uuid = Uuid();
  static const String _widgetsLayoutKey = 'widgets';

  final SaveBuilderPageUseCase _saveBuilderPage;
  final ReplaceBuilderPagesUseCase _replaceBuilderPages;
  final GetBuilderPagesUseCase _getBuilderPages;
  final SaveTableSchemaUseCase _saveTableSchema;
  final GetAllTableSchemasUseCase _getAllTableSchemas;
  final DeleteTableSchemaUseCase _deleteTableSchema;
  final DeleteRowsByTableUseCase _deleteRowsByTable;
  final SaveBuilderWidgetUseCase _saveBuilderWidget;
  final GetBuilderWidgetsByPageUseCase _getBuilderWidgetsByPage;
  final GetAllBuilderWidgetsUseCase _getAllBuilderWidgets;
  final DeleteBuilderWidgetUseCase _deleteBuilderWidget;
  final GetNavigationConfigUseCase _getNavigationConfig;
  final SaveNavigationConfigUseCase _saveNavigationConfig;

  /// Maps in-batch refs to created entity ids so subsequent actions in the
  /// same chat response can resolve `pageRef` / `tableRef`.
  final Map<String, String> _pageIdByRef = <String, String>{};
  final Map<String, String> _tableIdByRef = <String, String>{};

  /// Original user request that triggered the batch. Used as a last-resort
  /// hint when the model emitted a placeholder ref (e.g. "p") for an
  /// existing page — we scan the prompt for known workspace page/table names.
  String _batchUserPrompt = '';

  Future<AiBuildActionExecutionResult> execute(AiBuildAction action) async {
    try {
      switch (action) {
        case CreatePageAction():
          return await _executeCreatePage(action);
        case CreateTableAction():
          return await _executeCreateTable(action);
        case CreateCardWidgetAction():
          return await _executeCreateCardWidget(action);
        case CreateChartWidgetAction():
          return await _executeCreateChartWidget(action);
        case UpdatePageAction():
          return await _executeUpdatePage(action);
        case UpdateTableAction():
          return await _executeUpdateTable(action);
        case UpdateWidgetAction():
          return await _executeUpdateWidget(action);
        case DeletePageAction():
          return await _executeDeletePage(action);
        case DeleteTableAction():
          return await _executeDeleteTable(action);
        case DeleteWidgetAction():
          return await _executeDeleteWidget(action);
      }
    } catch (e) {
      return AiBuildActionExecutionResult.failure('$e');
    }
  }

  /// Resets in-batch state for a new Build-Plan run. [userPrompt] is the
  /// original user message that triggered the AI plan — passed through so
  /// `_resolvePageId` / `_resolveTableSchema` can fall back to scanning it
  /// for known workspace entity names when the model emits a placeholder ref.
  void beginBatch({String userPrompt = ''}) {
    _pageIdByRef.clear();
    _tableIdByRef.clear();
    _batchUserPrompt = userPrompt;
  }

  Future<AiBuildActionExecutionResult> _executeCreatePage(
    CreatePageAction action,
  ) async {
    final String trimmedName = action.name.trim();
    if (trimmedName.isEmpty) {
      return AiBuildActionExecutionResult.failure('Page name is required.');
    }
    final List<BuilderPageEntity> pages = await _getBuilderPages();
    final String finalName = _uniqueName(
      desired: trimmedName,
      takenLower: pages
          .where((BuilderPageEntity p) => !p.isDeleted)
          .map((BuilderPageEntity p) => p.name.trim().toLowerCase())
          .toSet(),
    );
    final String pageId = _uuid.v4();
    final BuilderPageEntity page = BuilderPageEntity(
      id: pageId,
      name: finalName,
      showInBottomNav: action.navigation.showInBottomNav,
      showInDrawer: action.navigation.showInDrawer,
      iconName: action.icon.isEmpty ? 'article_outlined' : action.icon,
    );
    await _saveBuilderPage(page);

    if (action.ref != null && action.ref!.isNotEmpty) {
      _pageIdByRef[action.ref!] = pageId;
    }
    _pageIdByRef[finalName.toLowerCase()] = pageId;
    _pageIdByRef[trimmedName.toLowerCase()] = pageId;

    if (page.showInBottomNav || page.showInDrawer) {
      await _updateNavigationConfig(page);
    }
    return AiBuildActionExecutionResult.ok(
      pageId,
      resolvedName: finalName == trimmedName ? null : finalName,
    );
  }

  Future<AiBuildActionExecutionResult> _executeCreateTable(
    CreateTableAction action,
  ) async {
    final String trimmedName = action.name.trim();
    if (trimmedName.isEmpty) {
      return AiBuildActionExecutionResult.failure('Table name is required.');
    }
    final List<TableSchemaEntity> tables = await _getAllTableSchemas();
    final String finalName = _uniqueName(
      desired: trimmedName,
      takenLower: tables
          .map((TableSchemaEntity t) => t.name.trim().toLowerCase())
          .toSet(),
    );
    final String? pageId = await _resolvePageId(action.pageRef);
    if (pageId == null) {
      return AiBuildActionExecutionResult.failure(
        'Could not resolve page "${action.pageRef}". '
        'Create the page first or reference an existing one by name.',
      );
    }

    final bool isSummary = action.tableKind == AiBuildTableKind.summary;
    final _SummaryBuildResult? summaryBuild;
    final List<TableColumnEntity> columns;

    if (isSummary) {
      if (action.summary == null) {
        return AiBuildActionExecutionResult.failure(
          'Summary table needs a "summary" block (sourceTable, groupBy, aggregate).',
        );
      }
      final Object built = _buildSummaryFromSpec(tables, action.summary!);
      if (built is String) {
        return AiBuildActionExecutionResult.failure(built);
      }
      summaryBuild = built as _SummaryBuildResult;
      columns = summaryBuild.derivedSchemaColumns;
    } else {
      summaryBuild = null;
      columns = action.columns
          .map(_columnSpecToEntity)
          .toList(growable: false);
      if (columns.isEmpty) {
        return AiBuildActionExecutionResult.failure(
          'Table needs at least one column.',
        );
      }
    }

    final String tableId = _uuid.v4();
    final TableSchemaEntity schema = TableSchemaEntity(
      id: tableId,
      pageId: pageId,
      name: finalName,
      description: '',
      mode: TableMode.crud,
      tableKind: isSummary ? TableKind.summary : TableKind.standard,
      summaryConfig: summaryBuild?.config,
      searchEnabled: false,
      dataLoadingMode: TableDataLoadingMode.lazy,
      columns: columns,
    );
    await _saveTableSchema(schema);
    await _saveBuilderWidget(
      BuilderWidgetEntity(
        id: _uuid.v4(),
        pageId: pageId,
        type: 'table',
        config: <String, dynamic>{'tableId': tableId},
      ),
    );
    await _appendLayoutKey(pageId, 'table:$tableId');

    if (action.ref != null && action.ref!.isNotEmpty) {
      _tableIdByRef[action.ref!] = tableId;
    }
    _tableIdByRef[finalName.toLowerCase()] = tableId;
    _tableIdByRef[trimmedName.toLowerCase()] = tableId;

    return AiBuildActionExecutionResult.ok(
      tableId,
      resolvedName: finalName == trimmedName ? null : finalName,
    );
  }

  Future<AiBuildActionExecutionResult> _executeCreateCardWidget(
    CreateCardWidgetAction action,
  ) async {
    final String? pageId = await _resolvePageId(action.pageRef);
    if (pageId == null) {
      return AiBuildActionExecutionResult.failure(
        'Could not resolve page "${action.pageRef}".',
      );
    }
    String? tableId;
    String? columnId;
    if (action.tableRef.trim().isNotEmpty) {
      final List<TableSchemaEntity> tables = await _getAllTableSchemas();
      final TableSchemaEntity? table = _resolveTableSchema(
        tables,
        action.tableRef,
      );
      if (table == null) {
        return AiBuildActionExecutionResult.failure(
          'Could not resolve table "${action.tableRef}".',
        );
      }
      tableId = table.id;
      if (action.columnName.trim().isNotEmpty) {
        final TableColumnEntity? column = _findColumnByName(
          table.columns,
          action.columnName,
        );
        if (column == null) {
          return AiBuildActionExecutionResult.failure(
            'Column "${action.columnName}" not found on table "${table.name}".',
          );
        }
        columnId = column.id;
      }
    }
    final String desiredTitle = action.title.trim();
    final String finalTitle = await _uniqueWidgetTitle(pageId, desiredTitle);
    final String widgetId = _uuid.v4();
    final Map<String, dynamic> config = <String, dynamic>{
      'title': finalTitle,
      'cardLayout': 'standard',
      'widgetOrder': await _nextWidgetOrder(pageId),
      if (tableId != null) 'tableId': tableId,
      if (columnId != null) 'columnId': columnId,
      if (action.formula.trim().isNotEmpty) 'formula': action.formula.trim(),
    };
    await _saveBuilderWidget(
      BuilderWidgetEntity(
        id: widgetId,
        pageId: pageId,
        type: 'card',
        config: config,
      ),
    );
    await _appendWidgetCard(pageId, widgetId);
    return AiBuildActionExecutionResult.ok(
      widgetId,
      resolvedName: finalTitle == desiredTitle ? null : finalTitle,
    );
  }

  Future<AiBuildActionExecutionResult> _executeCreateChartWidget(
    CreateChartWidgetAction action,
  ) async {
    final String? pageId = await _resolvePageId(action.pageRef);
    if (pageId == null) {
      return AiBuildActionExecutionResult.failure(
        'Could not resolve page "${action.pageRef}".',
      );
    }
    final List<TableSchemaEntity> tables = await _getAllTableSchemas();
    final TableSchemaEntity? table = _resolveTableSchema(
      tables,
      action.tableRef,
    );
    if (table == null) {
      return AiBuildActionExecutionResult.failure(
        'Could not resolve table "${action.tableRef}".',
      );
    }
    final TableColumnEntity? xColumn =
        _findColumnByName(table.columns, action.xColumn);
    if (xColumn == null) {
      return AiBuildActionExecutionResult.failure(
        'X column "${action.xColumn}" not found on table "${table.name}".',
      );
    }
    final TableColumnEntity? yColumn =
        _findColumnByName(table.columns, action.yColumn);
    if (yColumn == null) {
      return AiBuildActionExecutionResult.failure(
        'Y column "${action.yColumn}" not found on table "${table.name}".',
      );
    }
    final String desiredTitle = action.title.trim();
    final String finalTitle = await _uniqueWidgetTitle(pageId, desiredTitle);
    final String widgetId = _uuid.v4();
    final Map<String, dynamic> config = <String, dynamic>{
      'title': finalTitle,
      'tableId': table.id,
      'chartType': action.chartType.storageValue,
      'xColumnId': xColumn.id,
      'yColumnId': yColumn.id,
      'widgetOrder': await _nextWidgetOrder(pageId),
    };
    await _saveBuilderWidget(
      BuilderWidgetEntity(
        id: widgetId,
        pageId: pageId,
        type: 'chart',
        config: config,
      ),
    );
    await _appendLayoutKey(pageId, 'chart:$widgetId');
    return AiBuildActionExecutionResult.ok(
      widgetId,
      resolvedName: finalTitle == desiredTitle ? null : finalTitle,
    );
  }

  // ---------------------------------------------------------------------------
  // Update executors
  // ---------------------------------------------------------------------------

  Future<AiBuildActionExecutionResult> _executeUpdatePage(
    UpdatePageAction action,
  ) async {
    final List<BuilderPageEntity> pages = await _getBuilderPages();
    final BuilderPageEntity? existing =
        _findPageByName(pages, action.name) ??
            _fuzzyPageFromUserPrompt(pages);
    if (existing == null) {
      return AiBuildActionExecutionResult.failure(
        'Page "${action.name}" not found.',
      );
    }

    String finalName = existing.name;
    if (action.newName != null && action.newName!.trim().isNotEmpty) {
      final String desired = action.newName!.trim();
      finalName = _uniqueName(
        desired: desired,
        takenLower: pages
            .where((BuilderPageEntity p) =>
                !p.isDeleted && p.id != existing.id)
            .map((BuilderPageEntity p) => p.name.trim().toLowerCase())
            .toSet(),
      );
    }

    final BuilderPageEntity updated = existing.copyWith(
      name: finalName,
      iconName: action.icon == null || action.icon!.isEmpty
          ? existing.iconName
          : action.icon,
      showInBottomNav: action.navigation?.showInBottomNav,
      showInDrawer: action.navigation?.showInDrawer,
    );
    await _saveBuilderPage(updated);
    if (action.navigation != null) {
      await _syncNavigationConfig(updated);
    }
    return AiBuildActionExecutionResult.ok(
      existing.id,
      resolvedName: finalName == action.name ? null : finalName,
    );
  }

  Future<AiBuildActionExecutionResult> _executeUpdateTable(
    UpdateTableAction action,
  ) async {
    final List<TableSchemaEntity> tables = await _getAllTableSchemas();
    final TableSchemaEntity? existing =
        _resolveTableSchema(tables, action.name);
    if (existing == null) {
      return AiBuildActionExecutionResult.failure(
        'Table "${action.name}" not found.',
      );
    }

    String finalName = existing.name;
    if (action.newName != null && action.newName!.trim().isNotEmpty) {
      final String desired = action.newName!.trim();
      finalName = _uniqueName(
        desired: desired,
        takenLower: tables
            .where((TableSchemaEntity t) => t.id != existing.id)
            .map((TableSchemaEntity t) => t.name.trim().toLowerCase())
            .toSet(),
      );
    }

    final bool convertingToSummary =
        action.tableKind == AiBuildTableKind.summary;
    final TableKind nextKind =
        convertingToSummary ? TableKind.summary : existing.tableKind;
    TableSummaryConfig? nextSummary = existing.summaryConfig;
    final List<TableColumnEntity> nextColumns;

    if (convertingToSummary) {
      if (action.summary == null) {
        return AiBuildActionExecutionResult.failure(
          'Summary update needs a "summary" block (sourceTable, groupBy, aggregate).',
        );
      }
      final Object built = _buildSummaryFromSpec(tables, action.summary!);
      if (built is String) {
        return AiBuildActionExecutionResult.failure(built);
      }
      final _SummaryBuildResult res = built as _SummaryBuildResult;
      nextSummary = res.config;
      nextColumns = res.derivedSchemaColumns;
      // Converting changes the schema completely; drop existing rows so
      // we don't carry stale, schema-mismatched data into the summary view.
      await _deleteRowsByTable(existing.id);
    } else {
      // Preserve column IDs by name so existing rows that reference those IDs
      // stay linked to conceptually-the-same column. Newly added columns get a
      // fresh UUID; removed columns are dropped.
      final Map<String, String> existingIdByName = <String, String>{
        for (final TableColumnEntity c in existing.columns)
          c.name.trim().toLowerCase(): c.id,
      };
      nextColumns = action.columns
          .map((AiBuildColumnSpec spec) {
            final String key = spec.name.trim().toLowerCase();
            final String id = existingIdByName[key] ?? _uuid.v4();
            return TableColumnEntity(
              id: id,
              name: spec.name,
              type: _columnTypeFrom(spec.type),
              isRequired: spec.required,
              isUnique: spec.unique,
            );
          })
          .toList(growable: false);
      if (nextColumns.isEmpty) {
        return AiBuildActionExecutionResult.failure(
          'Table needs at least one column.',
        );
      }
    }

    final TableSchemaEntity updated = TableSchemaEntity(
      id: existing.id,
      pageId: existing.pageId,
      name: finalName,
      description: existing.description,
      mode: existing.mode,
      layoutType: existing.layoutType,
      listDesignLayout: existing.listDesignLayout,
      swipeToDelete: existing.swipeToDelete,
      productDisplayMode: existing.productDisplayMode,
      tableKind: nextKind,
      summaryConfig: nextSummary,
      inventoryDeduction: existing.inventoryDeduction,
      affectingTables: nextKind == TableKind.summary
          ? const <TableAffectingConfig>[]
          : existing.affectingTables,
      validationRules: nextKind == TableKind.summary
          ? const <TableValidationRule>[]
          : existing.validationRules,
      searchEnabled:
          nextKind == TableKind.summary ? false : existing.searchEnabled,
      dataLoadingMode: nextKind == TableKind.summary
          ? TableDataLoadingMode.lazy
          : existing.dataLoadingMode,
      pageSize: existing.pageSize,
      lazyInitialLoad: existing.lazyInitialLoad,
      columns: nextColumns,
    );
    await _saveTableSchema(updated);

    _tableIdByRef[finalName.toLowerCase()] = existing.id;
    return AiBuildActionExecutionResult.ok(
      existing.id,
      resolvedName: finalName == action.name ? null : finalName,
    );
  }

  Future<AiBuildActionExecutionResult> _executeUpdateWidget(
    UpdateWidgetAction action,
  ) async {
    final String? pageId = await _resolvePageId(action.pageRef);
    if (pageId == null) {
      return AiBuildActionExecutionResult.failure(
        'Could not resolve page "${action.pageRef}".',
      );
    }
    final List<BuilderWidgetEntity> widgets =
        await _getBuilderWidgetsByPage(pageId);
    final BuilderWidgetEntity? existing =
        _findWidgetByTitle(widgets, action.title);
    if (existing == null) {
      return AiBuildActionExecutionResult.failure(
        'Widget "${action.title}" not found on "${action.pageRef}".',
      );
    }

    final Map<String, dynamic> nextConfig =
        Map<String, dynamic>.from(existing.config);
    String finalTitle = (nextConfig['title'] as String?) ?? action.title;
    if (action.newTitle != null && action.newTitle!.trim().isNotEmpty) {
      final String desired = action.newTitle!.trim();
      final Set<String> taken = <String>{
        for (final BuilderWidgetEntity w in widgets)
          if (w.id != existing.id)
            ((w.config['title'] as String?) ?? '').trim().toLowerCase(),
      }..removeWhere((String s) => s.isEmpty);
      finalTitle = _uniqueName(desired: desired, takenLower: taken);
      nextConfig['title'] = finalTitle;
    }
    if (action.formula != null) {
      nextConfig['formula'] = action.formula;
    }
    if (action.columnName != null && action.columnName!.trim().isNotEmpty) {
      final List<TableSchemaEntity> tables = await _getAllTableSchemas();
      final String? tableId = nextConfig['tableId'] as String?;
      final TableSchemaEntity? hostTable = _tableById(tables, tableId);
      if (hostTable != null) {
        final TableColumnEntity? column =
            _findColumnByName(hostTable.columns, action.columnName!);
        if (column != null) {
          nextConfig['columnId'] = column.id;
        }
      }
    }
    if (action.tableRef != null && action.tableRef!.trim().isNotEmpty) {
      final List<TableSchemaEntity> tables = await _getAllTableSchemas();
      final TableSchemaEntity? hostTable =
          _resolveTableSchema(tables, action.tableRef!);
      if (hostTable != null) {
        nextConfig['tableId'] = hostTable.id;
      }
    }
    if (action.chartType != null) {
      nextConfig['chartType'] = action.chartType!.storageValue;
    }
    if ((action.xColumn != null && action.xColumn!.trim().isNotEmpty) ||
        (action.yColumn != null && action.yColumn!.trim().isNotEmpty)) {
      final String? tableId = nextConfig['tableId'] as String?;
      final List<TableSchemaEntity> tables = await _getAllTableSchemas();
      final TableSchemaEntity? hostTable = _tableById(tables, tableId);
      if (hostTable != null) {
        if (action.xColumn != null && action.xColumn!.trim().isNotEmpty) {
          final TableColumnEntity? c =
              _findColumnByName(hostTable.columns, action.xColumn!);
          if (c != null) {
            nextConfig['xColumnId'] = c.id;
          }
        }
        if (action.yColumn != null && action.yColumn!.trim().isNotEmpty) {
          final TableColumnEntity? c =
              _findColumnByName(hostTable.columns, action.yColumn!);
          if (c != null) {
            nextConfig['yColumnId'] = c.id;
          }
        }
      }
    }

    await _saveBuilderWidget(
      BuilderWidgetEntity(
        id: existing.id,
        pageId: existing.pageId,
        type: existing.type,
        config: nextConfig,
      ),
    );
    return AiBuildActionExecutionResult.ok(
      existing.id,
      resolvedName: finalTitle == action.title ? null : finalTitle,
    );
  }

  // ---------------------------------------------------------------------------
  // Delete executors (with cascading dependency cleanup)
  // ---------------------------------------------------------------------------

  Future<AiBuildActionExecutionResult> _executeDeletePage(
    DeletePageAction action,
  ) async {
    final List<BuilderPageEntity> pages = await _getBuilderPages();
    final BuilderPageEntity? existing =
        _findPageByName(pages, action.name) ??
            _fuzzyPageFromUserPrompt(pages);
    if (existing == null) {
      return AiBuildActionExecutionResult.failure(
        'Page "${action.name}" not found.',
      );
    }

    // Cascade: delete every widget on this page.
    final List<BuilderWidgetEntity> widgets =
        await _getBuilderWidgetsByPage(existing.id);
    for (final BuilderWidgetEntity w in widgets) {
      await _deleteBuilderWidget(w.id);
    }

    // Cascade: delete every table (schema + rows) that lives on this page.
    final List<TableSchemaEntity> tables = await _getAllTableSchemas();
    for (final TableSchemaEntity t
        in tables.where((TableSchemaEntity t) => t.pageId == existing.id)) {
      await _deleteRowsByTable(t.id);
      await _deleteTableSchema(t.id);
    }

    // Mark the page itself as deleted.
    await _saveBuilderPage(existing.copyWith(isDeleted: true));

    // Strip the page from the bottom-nav / drawer.
    await _removePageFromNavigationConfig(existing.id);
    return AiBuildActionExecutionResult.ok(existing.id);
  }

  Future<AiBuildActionExecutionResult> _executeDeleteTable(
    DeleteTableAction action,
  ) async {
    final List<TableSchemaEntity> tables = await _getAllTableSchemas();
    final TableSchemaEntity? existing =
        _resolveTableSchema(tables, action.name);
    if (existing == null) {
      return AiBuildActionExecutionResult.failure(
        'Table "${action.name}" not found.',
      );
    }

    // Cascade: delete every widget that points at this table id, anywhere.
    final List<BuilderWidgetEntity> allWidgets = await _getAllBuilderWidgets();
    final List<BuilderWidgetEntity> referencing = allWidgets
        .where(
          (BuilderWidgetEntity w) => w.config['tableId'] == existing.id,
        )
        .toList(growable: false);
    for (final BuilderWidgetEntity w in referencing) {
      await _deleteBuilderWidget(w.id);
    }

    // Cascade: drop every row, then the schema itself.
    await _deleteRowsByTable(existing.id);
    await _deleteTableSchema(existing.id);

    // Cascade: strip "table:<id>" from the host page's layoutOrder, and any
    // deleted widget ids from widgetOrder.
    final Set<String> deletedWidgetIds = <String>{
      for (final BuilderWidgetEntity w in referencing) w.id,
    };
    await _stripPageLayoutReferences(
      pageId: existing.pageId,
      layoutKeys: <String>{'table:${existing.id}'},
      widgetIds: deletedWidgetIds,
    );
    return AiBuildActionExecutionResult.ok(existing.id);
  }

  Future<AiBuildActionExecutionResult> _executeDeleteWidget(
    DeleteWidgetAction action,
  ) async {
    final String? pageId = await _resolvePageId(action.pageRef);
    if (pageId == null) {
      return AiBuildActionExecutionResult.failure(
        'Could not resolve page "${action.pageRef}".',
      );
    }
    final List<BuilderWidgetEntity> widgets =
        await _getBuilderWidgetsByPage(pageId);
    final BuilderWidgetEntity? existing =
        _findWidgetByTitle(widgets, action.title);
    if (existing == null) {
      return AiBuildActionExecutionResult.failure(
        'Widget "${action.title}" not found on "${action.pageRef}".',
      );
    }
    await _deleteBuilderWidget(existing.id);
    await _stripPageLayoutReferences(
      pageId: pageId,
      layoutKeys: <String>{'chart:${existing.id}', 'table:${existing.id}'},
      widgetIds: <String>{existing.id},
    );
    return AiBuildActionExecutionResult.ok(existing.id);
  }

  /// Returns [desired] if no entity with that name (case-insensitive) is in
  /// [takenLower], otherwise appends " 2", " 3", … until unique.
  String _uniqueName({
    required String desired,
    required Set<String> takenLower,
  }) {
    final String trimmed = desired.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    if (!takenLower.contains(trimmed.toLowerCase())) {
      return trimmed;
    }
    int suffix = 2;
    while (takenLower.contains('${trimmed.toLowerCase()} $suffix')) {
      suffix++;
    }
    return '$trimmed $suffix';
  }

  Future<String> _uniqueWidgetTitle(String pageId, String desired) async {
    final String trimmed = desired.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    final List<BuilderWidgetEntity> widgets =
        await _getBuilderWidgetsByPage(pageId);
    final Set<String> taken = <String>{};
    for (final BuilderWidgetEntity w in widgets) {
      final dynamic raw = w.config['title'];
      if (raw is String) {
        final String name = raw.trim().toLowerCase();
        if (name.isNotEmpty) {
          taken.add(name);
        }
      }
    }
    return _uniqueName(desired: trimmed, takenLower: taken);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<String?> _resolvePageId(String pageRef) async {
    final String key = pageRef.trim();
    if (key.isEmpty) {
      return null;
    }
    final String? fromBatch =
        _pageIdByRef[key] ?? _pageIdByRef[key.toLowerCase()];
    if (fromBatch != null) {
      return fromBatch;
    }
    final List<BuilderPageEntity> pages = await _getBuilderPages();
    final BuilderPageEntity? byName = _findPageByName(pages, key);
    if (byName != null) {
      return byName.id;
    }
    // Fuzzy fallbacks: the model probably emitted a placeholder ref ("p") for
    // an existing page. Try mining the original user request for a known page.
    final BuilderPageEntity? byPrompt = _fuzzyPageFromUserPrompt(pages);
    if (byPrompt != null) {
      return byPrompt.id;
    }
    // If the workspace has exactly one usable page, that has to be the target.
    final List<BuilderPageEntity> usable = pages
        .where(
          (BuilderPageEntity p) =>
              !p.isDeleted && !p.isDrawerParentContainer,
        )
        .toList(growable: false);
    if (usable.length == 1) {
      return usable.first.id;
    }
    return null;
  }

  TableSchemaEntity? _resolveTableSchema(
    List<TableSchemaEntity> tables,
    String tableRef,
  ) {
    final String key = tableRef.trim();
    if (key.isEmpty) {
      return null;
    }
    final String? batchId =
        _tableIdByRef[key] ?? _tableIdByRef[key.toLowerCase()];
    if (batchId != null) {
      for (final TableSchemaEntity t in tables) {
        if (t.id == batchId) {
          return t;
        }
      }
    }
    for (final TableSchemaEntity t in tables) {
      if (t.name.trim().toLowerCase() == key.toLowerCase()) {
        return t;
      }
    }
    // Fuzzy fallback against the original user prompt.
    return _fuzzyTableFromUserPrompt(tables);
  }

  BuilderPageEntity? _fuzzyPageFromUserPrompt(List<BuilderPageEntity> pages) {
    if (_batchUserPrompt.trim().isEmpty) {
      return null;
    }
    final String hay = _normalizeForFuzzy(_batchUserPrompt);
    final List<BuilderPageEntity> usable = pages
        .where(
          (BuilderPageEntity p) =>
              !p.isDeleted && !p.isDrawerParentContainer,
        )
        .toList(growable: false);

    // Pass 1: explicit "<X> page" phrasing wins, regardless of length.
    final BuilderPageEntity? phrased = _matchEntityByPhrasePhrase(
      hay,
      'page',
      usable,
      (BuilderPageEntity p) => p.name,
    );
    if (phrased != null) {
      return phrased;
    }
    // Pass 2: scored containment over the whole prompt.
    BuilderPageEntity? best;
    int bestScore = 0;
    for (final BuilderPageEntity p in usable) {
      final String name = p.name.trim();
      if (name.length < 3) {
        continue;
      }
      final int score = _fuzzyScore(hay, _normalizeForFuzzy(name));
      if (score > bestScore) {
        bestScore = score;
        best = p;
      }
    }
    return bestScore > 0 ? best : null;
  }

  TableSchemaEntity? _fuzzyTableFromUserPrompt(List<TableSchemaEntity> tables) {
    if (_batchUserPrompt.trim().isEmpty) {
      return null;
    }
    final String hay = _normalizeForFuzzy(_batchUserPrompt);

    // Pass 1: "<X> table" phrasing.
    final TableSchemaEntity? phrased = _matchEntityByPhrasePhrase(
      hay,
      'table',
      tables,
      (TableSchemaEntity t) => t.name,
    );
    if (phrased != null) {
      return phrased;
    }
    // Pass 2: scored containment.
    TableSchemaEntity? best;
    int bestScore = 0;
    for (final TableSchemaEntity t in tables) {
      final String name = t.name.trim();
      if (name.length < 3) {
        continue;
      }
      final int score = _fuzzyScore(hay, _normalizeForFuzzy(name));
      if (score > bestScore) {
        bestScore = score;
        best = t;
      }
    }
    return bestScore > 0 ? best : null;
  }

  /// Finds entities referenced as `<X> <suffix>` in [hay] (e.g. "reports page",
  /// "transactions table") and returns the first matching candidate from
  /// [candidates] whose normalized name matches the hint, with simple
  /// singular/plural reconciliation.
  T? _matchEntityByPhrasePhrase<T>(
    String hay,
    String suffix,
    List<T> candidates,
    String Function(T) nameOf,
  ) {
    final RegExp pattern =
        RegExp('([a-z0-9]+(?:\\s+[a-z0-9]+)?)\\s+$suffix\\b');
    for (final Match m in pattern.allMatches(hay)) {
      final String hint = (m.group(1) ?? '').trim();
      if (hint.isEmpty) {
        continue;
      }
      for (final T candidate in candidates) {
        final String name = _normalizeForFuzzy(nameOf(candidate));
        if (name.isEmpty) {
          continue;
        }
        if (name == hint ||
            _singularize(name) == _singularize(hint) ||
            name == _singularize(hint) ||
            hint == _singularize(name)) {
          return candidate;
        }
        // Last-word match: hint "summary transactions" -> name "transactions".
        final String hintLast = hint.split(' ').last;
        if (_singularize(name) == _singularize(hintLast)) {
          return candidate;
        }
      }
    }
    return null;
  }

  String _singularize(String w) {
    if (w.endsWith('ies') && w.length > 4) {
      return '${w.substring(0, w.length - 3)}y';
    }
    if (w.endsWith('s') && w.length > 3) {
      return w.substring(0, w.length - 1);
    }
    return w;
  }

  /// Lowercase, drop punctuation/extra whitespace.
  String _normalizeForFuzzy(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Higher = better match. Considers full substring, singular/plural, and
  /// per-word containment.
  int _fuzzyScore(String hay, String needle) {
    if (needle.isEmpty) {
      return 0;
    }
    if (hay.contains(' $needle ') ||
        hay.startsWith('$needle ') ||
        hay.endsWith(' $needle') ||
        hay == needle) {
      return 100 + needle.length;
    }
    // Plural variants: "report" ↔ "reports", "category" ↔ "categories".
    final List<String> variants = <String>[
      needle,
      '${needle}s',
      if (needle.endsWith('y'))
        '${needle.substring(0, needle.length - 1)}ies',
    ];
    for (final String v in variants) {
      if (hay.contains(v)) {
        return 50 + needle.length;
      }
    }
    // Per-word: every word in needle has to appear somewhere in hay.
    final List<String> words = needle
        .split(' ')
        .where((String w) => w.length >= 3)
        .toList(growable: false);
    if (words.isEmpty) {
      return 0;
    }
    for (final String w in words) {
      if (!hay.contains(w)) {
        return 0;
      }
    }
    return 10 + needle.length;
  }

  BuilderPageEntity? _findPageByName(
    List<BuilderPageEntity> pages,
    String name,
  ) {
    final String key = name.trim().toLowerCase();
    for (final BuilderPageEntity p in pages) {
      if (p.name.trim().toLowerCase() == key) {
        return p;
      }
    }
    return null;
  }

  TableSchemaEntity? _tableById(List<TableSchemaEntity> tables, String? id) {
    if (id == null || id.isEmpty) {
      return null;
    }
    for (final TableSchemaEntity t in tables) {
      if (t.id == id) {
        return t;
      }
    }
    return null;
  }

  BuilderWidgetEntity? _findWidgetByTitle(
    List<BuilderWidgetEntity> widgets,
    String title,
  ) {
    final String key = title.trim().toLowerCase();
    if (key.isEmpty) {
      return null;
    }
    for (final BuilderWidgetEntity w in widgets) {
      final String wt = ((w.config['title'] as String?) ?? '').trim();
      if (wt.toLowerCase() == key) {
        return w;
      }
    }
    // Loose fallback: substring (handles "Summary" vs "Total Summary").
    for (final BuilderWidgetEntity w in widgets) {
      final String wt = ((w.config['title'] as String?) ?? '').trim();
      if (wt.isEmpty) {
        continue;
      }
      if (wt.toLowerCase().contains(key) || key.contains(wt.toLowerCase())) {
        return w;
      }
    }
    return null;
  }

  TableColumnEntity _columnSpecToEntity(AiBuildColumnSpec spec) {
    return TableColumnEntity(
      id: _uuid.v4(),
      name: spec.name,
      type: _columnTypeFrom(spec.type),
      isRequired: spec.required,
      isUnique: spec.unique,
    );
  }

  TableColumnType _columnTypeFrom(String raw) {
    switch (raw.toLowerCase()) {
      case 'number':
        return TableColumnType.number;
      case 'date':
        return TableColumnType.date;
      case 'boolean':
        return TableColumnType.boolean;
      case 'dropdown':
        return TableColumnType.dropdown;
      case 'text':
      default:
        return TableColumnType.text;
    }
  }

  Future<int> _nextWidgetOrder(String pageId) async {
    final List<BuilderPageEntity> pages = await _getBuilderPages();
    for (final BuilderPageEntity p in pages) {
      if (p.id == pageId) {
        return p.widgetOrder.length;
      }
    }
    return 0;
  }

  Future<void> _appendLayoutKey(String pageId, String layoutKey) async {
    final List<BuilderPageEntity> pages = await _getBuilderPages();
    final List<BuilderPageEntity> next = pages
        .map((BuilderPageEntity p) {
          if (p.id != pageId) {
            return p;
          }
          final List<String> order = List<String>.from(p.layoutOrder);
          if (!order.contains(layoutKey)) {
            order.add(layoutKey);
          }
          if (!order.contains(_widgetsLayoutKey)) {
            order.insert(0, _widgetsLayoutKey);
          }
          return p.copyWith(layoutOrder: order);
        })
        .toList(growable: false);
    await _replaceBuilderPages(next);
  }

  Future<void> _appendWidgetCard(String pageId, String widgetId) async {
    final List<BuilderPageEntity> pages = await _getBuilderPages();
    final List<BuilderPageEntity> next = pages
        .map((BuilderPageEntity p) {
          if (p.id != pageId) {
            return p;
          }
          final List<String> order = List<String>.from(p.widgetOrder);
          if (!order.contains(widgetId)) {
            order.add(widgetId);
          }
          final List<String> layout = List<String>.from(p.layoutOrder);
          if (!layout.contains(_widgetsLayoutKey)) {
            layout.insert(0, _widgetsLayoutKey);
          }
          return p.copyWith(widgetOrder: order, layoutOrder: layout);
        })
        .toList(growable: false);
    await _replaceBuilderPages(next);
  }

  Future<void> _updateNavigationConfig(BuilderPageEntity page) async {
    final NavigationConfigEntity? current = await _getNavigationConfig();
    final List<String> nextBottom = <String>[
      ...(current?.bottomPageIds ?? const <String>[]),
    ];
    final List<String> nextDrawer = <String>[
      ...(current?.drawerPageIds ?? const <String>[]),
    ];
    if (page.showInBottomNav && !nextBottom.contains(page.id)) {
      nextBottom.add(page.id);
    }
    if (page.showInDrawer && !nextDrawer.contains(page.id)) {
      nextDrawer.add(page.id);
    }
    await _saveNavigationConfig(
      NavigationConfigEntity(
        bottomPageIds: nextBottom,
        drawerPageIds: nextDrawer,
        activePageId: current?.activePageId ?? page.id,
        mainPageId: current?.mainPageId ?? page.id,
        bottomNavLayout:
            current?.bottomNavLayout ?? BottomNavLayoutType.standard,
        bottomNavCenterPageId: current?.bottomNavCenterPageId,
        bottomNavShowLabels: current?.bottomNavShowLabels ?? true,
        drawerNavLayout:
            current?.drawerNavLayout ?? DrawerNavLayoutType.softCard,
      ),
    );
  }

  /// Mirrors a page's nav flags to the navigation config: adds the id where it
  /// should appear, removes it everywhere else. Used by `update_page`.
  Future<void> _syncNavigationConfig(BuilderPageEntity page) async {
    final NavigationConfigEntity? current = await _getNavigationConfig();
    final List<String> nextBottom = <String>[
      ...(current?.bottomPageIds ?? const <String>[]),
    ]..removeWhere((String id) => id == page.id);
    final List<String> nextDrawer = <String>[
      ...(current?.drawerPageIds ?? const <String>[]),
    ]..removeWhere((String id) => id == page.id);
    if (page.showInBottomNav) {
      nextBottom.add(page.id);
    }
    if (page.showInDrawer) {
      nextDrawer.add(page.id);
    }
    await _saveNavigationConfig(
      NavigationConfigEntity(
        bottomPageIds: nextBottom,
        drawerPageIds: nextDrawer,
        activePageId: current?.activePageId ?? page.id,
        mainPageId: current?.mainPageId ?? page.id,
        bottomNavLayout:
            current?.bottomNavLayout ?? BottomNavLayoutType.standard,
        bottomNavCenterPageId:
            current?.bottomNavCenterPageId == page.id
                ? null
                : current?.bottomNavCenterPageId,
        bottomNavShowLabels: current?.bottomNavShowLabels ?? true,
        drawerNavLayout:
            current?.drawerNavLayout ?? DrawerNavLayoutType.softCard,
      ),
    );
  }

  /// Used by `delete_page` to detach the page from nav and active/main slots.
  Future<void> _removePageFromNavigationConfig(String pageId) async {
    final NavigationConfigEntity? current = await _getNavigationConfig();
    if (current == null) {
      return;
    }
    final List<String> nextBottom = <String>[...current.bottomPageIds]
      ..removeWhere((String id) => id == pageId);
    final List<String> nextDrawer = <String>[...current.drawerPageIds]
      ..removeWhere((String id) => id == pageId);
    final String? nextActive = current.activePageId == pageId
        ? (nextBottom.isNotEmpty
            ? nextBottom.first
            : (nextDrawer.isNotEmpty ? nextDrawer.first : null))
        : current.activePageId;
    final String? nextMain = current.mainPageId == pageId ? null : current.mainPageId;
    await _saveNavigationConfig(
      NavigationConfigEntity(
        bottomPageIds: nextBottom,
        drawerPageIds: nextDrawer,
        activePageId: nextActive ?? '',
        mainPageId: nextMain ?? (nextBottom.isNotEmpty ? nextBottom.first : ''),
        bottomNavLayout: current.bottomNavLayout,
        bottomNavCenterPageId:
            current.bottomNavCenterPageId == pageId
                ? null
                : current.bottomNavCenterPageId,
        bottomNavShowLabels: current.bottomNavShowLabels,
        drawerNavLayout: current.drawerNavLayout,
      ),
    );
  }

  /// Removes the given layout keys (e.g. `table:<id>`, `chart:<id>`) and
  /// widget ids from the host page's `layoutOrder` / `widgetOrder`. Used by
  /// the delete cascades to prevent orphaned references.
  Future<void> _stripPageLayoutReferences({
    required String pageId,
    required Set<String> layoutKeys,
    required Set<String> widgetIds,
  }) async {
    final List<BuilderPageEntity> pages = await _getBuilderPages();
    final List<BuilderPageEntity> next = pages
        .map((BuilderPageEntity p) {
          if (p.id != pageId) {
            return p;
          }
          final List<String> nextLayout = List<String>.from(p.layoutOrder)
            ..removeWhere((String k) => layoutKeys.contains(k));
          final List<String> nextWidgetOrder = List<String>.from(p.widgetOrder)
            ..removeWhere((String w) => widgetIds.contains(w));
          if (nextWidgetOrder.isEmpty) {
            nextLayout.removeWhere((String k) => k == _widgetsLayoutKey);
          }
          return p.copyWith(
            layoutOrder: nextLayout,
            widgetOrder: nextWidgetOrder,
          );
        })
        .toList(growable: false);
    await _replaceBuilderPages(next);
  }

  /// Builds a [TableSummaryConfig] + derived schema columns for a new or
  /// converted summary table.
  ///
  /// Resolves `spec.sourceTable`, `spec.groupBy`, `spec.aggregate` to concrete
  /// IDs against [allTables] (which already includes tables created earlier in
  /// the same batch, since the executor refreshes between actions). Returns a
  /// human-readable error string on validation failure, or a populated
  /// [_SummaryBuildResult] on success.
  Object _buildSummaryFromSpec(
    List<TableSchemaEntity> allTables,
    AiBuildSummarySpec spec,
  ) {
    final TableSchemaEntity? source = _resolveTableSchema(
      allTables,
      spec.sourceTable,
    );
    if (source == null) {
      return 'Summary source table "${spec.sourceTable}" not found.';
    }
    final TableColumnEntity? groupCol =
        _findColumnByName(source.columns, spec.groupBy);
    if (groupCol == null) {
      return 'Summary groupBy column "${spec.groupBy}" not found on table '
          '"${source.name}".';
    }
    final TableColumnEntity? aggregateCol =
        _findColumnByName(source.columns, spec.aggregate);
    if (aggregateCol == null) {
      return 'Summary aggregate column "${spec.aggregate}" not found on table '
          '"${source.name}".';
    }

    final SummaryAggregationOperation op = _toSummaryAggregationOperation(
      spec.operation,
    );

    final String groupSummaryColId = _uuid.v4();
    final String aggSummaryColId = _uuid.v4();

    final List<SummaryColumnConfig> summaryColumns = <SummaryColumnConfig>[
      SummaryColumnConfig(
        id: groupSummaryColId,
        name: groupCol.name,
        sourceTableId: source.id,
        sourceColumnId: groupCol.id,
        groupBy: true,
        valueMode: SummaryValueMode.groupedValue,
      ),
      SummaryColumnConfig(
        id: aggSummaryColId,
        name: aggregateCol.name,
        sourceTableId: source.id,
        sourceColumnId: aggregateCol.id,
        valueMode: SummaryValueMode.aggregation,
        aggregation: op,
      ),
    ];

    final TableSummaryConfig config = TableSummaryConfig(
      sourceTableId: source.id,
      groupByColumnId: groupCol.id,
      aggregateSourceColumnId: aggregateCol.id,
      operation: op,
      columns: summaryColumns,
    );

    // The summary table's own schema mirrors the summary columns: the group
    // column becomes a text key, the aggregate column becomes a number cell.
    final List<TableColumnEntity> derivedSchemaColumns = <TableColumnEntity>[
      TableColumnEntity(
        id: groupSummaryColId,
        name: groupCol.name,
        type: TableColumnType.text,
        includeInCreateForm: false,
        includeInEditForm: false,
        isRequired: false,
      ),
      TableColumnEntity(
        id: aggSummaryColId,
        name: aggregateCol.name,
        type: TableColumnType.number,
        includeInCreateForm: false,
        includeInEditForm: false,
        isRequired: false,
      ),
    ];

    return _SummaryBuildResult(
      config: config,
      derivedSchemaColumns: derivedSchemaColumns,
    );
  }

  /// Case- and whitespace-insensitive column lookup with a small fallback that
  /// strips trailing plural `s` so `"products"` matches `"Product"`.
  TableColumnEntity? _findColumnByName(
    List<TableColumnEntity> columns,
    String name,
  ) {
    final String target = name.trim().toLowerCase();
    if (target.isEmpty) {
      return null;
    }
    for (final TableColumnEntity c in columns) {
      if (c.name.trim().toLowerCase() == target) {
        return c;
      }
    }
    final String singular = target.endsWith('s')
        ? target.substring(0, target.length - 1)
        : target;
    if (singular != target) {
      for (final TableColumnEntity c in columns) {
        if (c.name.trim().toLowerCase() == singular) {
          return c;
        }
      }
    }
    return null;
  }

  SummaryAggregationOperation _toSummaryAggregationOperation(
    AiBuildSummaryOperation op,
  ) {
    switch (op) {
      case AiBuildSummaryOperation.sum:
        return SummaryAggregationOperation.sum;
      case AiBuildSummaryOperation.count:
        return SummaryAggregationOperation.count;
      case AiBuildSummaryOperation.avg:
        return SummaryAggregationOperation.avg;
      case AiBuildSummaryOperation.min:
        return SummaryAggregationOperation.min;
      case AiBuildSummaryOperation.max:
        return SummaryAggregationOperation.max;
    }
  }
}

/// Internal carrier for [AiBuildActionExecutor._buildSummaryFromSpec] success.
class _SummaryBuildResult {
  const _SummaryBuildResult({
    required this.config,
    required this.derivedSchemaColumns,
  });

  final TableSummaryConfig config;
  final List<TableColumnEntity> derivedSchemaColumns;
}
