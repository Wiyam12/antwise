import 'dart:convert';

import 'package:antwise/core/services/ai/ai_build_plan.dart';
import 'package:antwise/core/storage/hive_boxes.dart';
import 'package:antwise/data/models/hive/builder_page_hive_model.dart';
import 'package:antwise/data/models/hive/builder_widget_hive_model.dart';
import 'package:antwise/data/models/hive/table_schema_hive_model.dart';
import 'package:hive/hive.dart';

/// Deterministic snapshot of the current Antwise workspace used to build
/// Build-mode prompts without hitting the on-device model. The snapshot is
/// the same shape for the planner and the builder; each prompt encodes a
/// different slice of it (full name index vs filtered context).
final class AiBuildWorkspaceSnapshot {
  AiBuildWorkspaceSnapshot._({
    required this.pages,
    required this.tables,
  });

  /// All non-deleted pages, sorted alphabetically (case-insensitive).
  final List<AiBuildSnapshotPage> pages;

  /// All tables, sorted alphabetically (case-insensitive).
  final List<AiBuildSnapshotTable> tables;

  static const int _defaultPagesCap = 24;
  static const int _defaultTablesCap = 20;
  static const int _defaultColumnsPerTable = 14;

  bool get isEmpty => pages.isEmpty && tables.isEmpty;

  /// Reads pages, tables, and widgets from Hive. Returns an empty snapshot
  /// when the relevant boxes are not yet open (e.g. fresh install).
  static AiBuildWorkspaceSnapshot build() {
    final Map<String, String> pageNameById = <String, String>{};
    final List<AiBuildSnapshotPage> pages = <AiBuildSnapshotPage>[];

    if (Hive.isBoxOpen(HiveBoxes.pagesBox)) {
      final List<BuilderPageHiveModel> rawPages =
          Hive.box<BuilderPageHiveModel>(HiveBoxes.pagesBox).values
              .where(
                (BuilderPageHiveModel p) =>
                    !p.isDeleted && p.name.trim().isNotEmpty,
              )
              .toList(growable: false);
      for (final BuilderPageHiveModel p in rawPages) {
        pageNameById[p.id] = p.name.trim();
      }
      rawPages.sort(
        (BuilderPageHiveModel a, BuilderPageHiveModel b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      for (final BuilderPageHiveModel p in rawPages) {
        pages.add(
          AiBuildSnapshotPage(
            id: p.id,
            name: p.name.trim(),
            navigation: p.navigationType,
          ),
        );
      }
    }

    final Map<String, List<String>> tablesByPageId = <String, List<String>>{};
    final List<AiBuildSnapshotTable> tables = <AiBuildSnapshotTable>[];

    if (Hive.isBoxOpen(HiveBoxes.tablesBox)) {
      final List<TableSchemaHiveModel> rawTables =
          Hive.box<TableSchemaHiveModel>(HiveBoxes.tablesBox).values
              .where((TableSchemaHiveModel t) => t.name.trim().isNotEmpty)
              .toList(growable: false)
            ..sort(
              (TableSchemaHiveModel a, TableSchemaHiveModel b) =>
                  a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );
      for (final TableSchemaHiveModel t in rawTables) {
        final String tableName = t.name.trim();
        tablesByPageId.putIfAbsent(t.pageId, () => <String>[]).add(tableName);
        final List<AiBuildSnapshotColumn> cols = <AiBuildSnapshotColumn>[];
        for (final Map<String, dynamic> raw in t.columns) {
          final String colName = (raw['name'] as String?)?.trim() ?? '';
          if (colName.isEmpty) {
            continue;
          }
          final String type = (raw['type'] as String?)?.trim() ?? '';
          cols.add(AiBuildSnapshotColumn(name: colName, type: type));
        }
        tables.add(
          AiBuildSnapshotTable(
            id: t.id,
            name: tableName,
            kind: t.tableKind,
            pageId: t.pageId,
            pageName: pageNameById[t.pageId] ?? '',
            columns: cols,
          ),
        );
      }
    }

    final Map<String, List<String>> widgetTitlesByPageId =
        <String, List<String>>{};
    if (Hive.isBoxOpen(HiveBoxes.widgetsBox)) {
      for (final BuilderWidgetHiveModel w
          in Hive.box<BuilderWidgetHiveModel>(HiveBoxes.widgetsBox).values) {
        final String title = (w.config['title'] as String?)?.trim() ?? '';
        if (title.isEmpty) {
          continue;
        }
        widgetTitlesByPageId.putIfAbsent(w.pageId, () => <String>[]).add(title);
      }
    }

    // Stitch tables + widgets onto each page so prompt encoders can group by page.
    for (int i = 0; i < pages.length; i++) {
      final AiBuildSnapshotPage p = pages[i];
      pages[i] = p.copyWith(
        tableNames:
            List<String>.unmodifiable(tablesByPageId[p.id] ?? const <String>[]),
        widgetTitles: List<String>.unmodifiable(
          widgetTitlesByPageId[p.id] ?? const <String>[],
        ),
      );
    }

    return AiBuildWorkspaceSnapshot._(pages: pages, tables: tables);
  }

  /// Compact name index used by the **planner** (no column details).
  ///
  /// Shape:
  /// `{"pages":{"Sales":{"nav":"bottom","tables":["Orders"],"widgets":["Revenue"]}},`
  /// `"tables":["Orders","Products"]}`
  String nameIndexJson({
    int maxPages = _defaultPagesCap,
    int maxTables = _defaultTablesCap,
  }) {
    final Map<String, dynamic> root = <String, dynamic>{};
    final Map<String, Map<String, dynamic>> pageMap =
        <String, Map<String, dynamic>>{};
    final int pageLimit = pages.length > maxPages ? maxPages : pages.length;
    for (int i = 0; i < pageLimit; i++) {
      pageMap[pages[i].name] = pages[i].toIndexJson();
    }
    if (pages.length > pageLimit) {
      pageMap['…'] = <String, dynamic>{
        'more_pages': pages.length - pageLimit,
      };
    }
    root['pages'] = pageMap;

    final int tableLimit = tables.length > maxTables ? maxTables : tables.length;
    final List<String> tableNames = <String>[
      for (int i = 0; i < tableLimit; i++) tables[i].name,
    ];
    if (tables.length > tableLimit) {
      tableNames.add('+${tables.length - tableLimit}_more');
    }
    root['tables'] = tableNames;
    return jsonEncode(root);
  }

  /// Detailed JSON for the **builder** prompt. When [plan] is provided, only
  /// pages/tables/widgets referenced by the plan are included (plus their
  /// direct dependencies — referenced tables include their parent page).
  String builderContextJson({
    AiBuildPlan? plan,
    int maxPages = _defaultPagesCap,
    int maxTables = _defaultTablesCap,
    int maxColumnsPerTable = _defaultColumnsPerTable,
  }) {
    final Set<String> includePages = plan == null
        ? pages.map((AiBuildSnapshotPage p) => p.name).toSet()
        : _expandPageRefs(plan);
    final Set<String> includeTables = plan == null
        ? tables.map((AiBuildSnapshotTable t) => t.name).toSet()
        : _expandTableRefs(plan, includePages);

    final Map<String, Map<String, dynamic>> pageMap =
        <String, Map<String, dynamic>>{};
    int pageCount = 0;
    for (final AiBuildSnapshotPage p in pages) {
      if (!includePages.contains(p.name)) {
        continue;
      }
      if (pageCount >= maxPages) {
        pageMap['…'] = <String, dynamic>{'more_pages': true};
        break;
      }
      pageMap[p.name] = p.toIndexJson();
      pageCount++;
    }

    final Map<String, List<String>> tableMap = <String, List<String>>{};
    int tableCount = 0;
    for (final AiBuildSnapshotTable t in tables) {
      if (!includeTables.contains(t.name)) {
        continue;
      }
      if (tableCount >= maxTables) {
        tableMap['…more_tables'] = <String>['${tables.length - tableCount}'];
        break;
      }
      final List<String> colNames = <String>[];
      for (final AiBuildSnapshotColumn c in t.columns) {
        if (colNames.length >= maxColumnsPerTable) {
          colNames.add('…');
          break;
        }
        colNames.add(c.name);
      }
      tableMap[t.name] = colNames;
      tableCount++;
    }

    return jsonEncode(<String, dynamic>{
      'pages': pageMap,
      'tables': tableMap,
    });
  }

  /// All known page names (no truncation) — handy for fallback validation.
  List<String> get pageNames =>
      pages.map((AiBuildSnapshotPage p) => p.name).toList(growable: false);

  /// All known table names (no truncation).
  List<String> get tableNames =>
      tables.map((AiBuildSnapshotTable t) => t.name).toList(growable: false);

  /// Resolves which pages should appear in the builder prompt given a plan.
  /// Includes plan.pageRefs plus the parent page of every referenced table.
  Set<String> _expandPageRefs(AiBuildPlan plan) {
    final Set<String> result = <String>{};
    final Set<String> lowerPageRefs =
        plan.pageRefs.map((String s) => s.toLowerCase()).toSet();
    for (final AiBuildSnapshotPage p in pages) {
      if (lowerPageRefs.contains(p.name.toLowerCase())) {
        result.add(p.name);
      }
    }
    final Set<String> lowerTableRefs =
        plan.tableRefs.map((String s) => s.toLowerCase()).toSet();
    for (final AiBuildSnapshotTable t in tables) {
      if (lowerTableRefs.contains(t.name.toLowerCase()) &&
          t.pageName.isNotEmpty) {
        result.add(t.pageName);
      }
    }
    return result;
  }

  Set<String> _expandTableRefs(AiBuildPlan plan, Set<String> includedPages) {
    final Set<String> result = <String>{};
    final Set<String> lowerTableRefs =
        plan.tableRefs.map((String s) => s.toLowerCase()).toSet();
    for (final AiBuildSnapshotTable t in tables) {
      if (lowerTableRefs.contains(t.name.toLowerCase())) {
        result.add(t.name);
        continue;
      }
      if (includedPages.contains(t.pageName)) {
        result.add(t.name);
      }
    }
    return result;
  }
}

/// One page entry in [AiBuildWorkspaceSnapshot].
class AiBuildSnapshotPage {
  const AiBuildSnapshotPage({
    required this.id,
    required this.name,
    required this.navigation,
    this.tableNames = const <String>[],
    this.widgetTitles = const <String>[],
  });

  final String id;
  final String name;
  final String navigation;
  final List<String> tableNames;
  final List<String> widgetTitles;

  AiBuildSnapshotPage copyWith({
    List<String>? tableNames,
    List<String>? widgetTitles,
  }) {
    return AiBuildSnapshotPage(
      id: id,
      name: name,
      navigation: navigation,
      tableNames: tableNames ?? this.tableNames,
      widgetTitles: widgetTitles ?? this.widgetTitles,
    );
  }

  Map<String, dynamic> toIndexJson() {
    final Map<String, dynamic> entry = <String, dynamic>{
      'nav': navigation,
    };
    if (tableNames.isNotEmpty) {
      entry['tables'] = tableNames;
    }
    if (widgetTitles.isNotEmpty) {
      entry['widgets'] = widgetTitles;
    }
    return entry;
  }
}

/// One table entry in [AiBuildWorkspaceSnapshot].
class AiBuildSnapshotTable {
  const AiBuildSnapshotTable({
    required this.id,
    required this.name,
    required this.kind,
    required this.pageId,
    required this.pageName,
    required this.columns,
  });

  final String id;
  final String name;

  /// `standard` or `summary`.
  final String kind;
  final String pageId;
  final String pageName;
  final List<AiBuildSnapshotColumn> columns;
}

/// One column inside a table.
class AiBuildSnapshotColumn {
  const AiBuildSnapshotColumn({required this.name, required this.type});

  final String name;
  final String type;
}
