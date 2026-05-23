import 'package:antwise/core/services/ai/ai_build_action.dart';
import 'package:antwise/core/services/ai/ai_build_action_parser.dart';
import 'package:antwise/core/services/ai/ai_hive_json_extractor.dart';
import 'package:antwise/core/storage/hive_boxes.dart';
import 'package:antwise/data/models/hive/builder_page_hive_model.dart';
import 'package:antwise/data/models/hive/builder_widget_hive_model.dart';
import 'package:antwise/data/models/hive/table_schema_hive_model.dart';
import 'package:hive/hive.dart';

/// Rule-based fallback when the on-device model returns prose instead of JSON.
abstract final class AiBuildHeuristics {
  static AiBuildActionParseResult? tryInfer({
    required String userPrompt,
    required AiHiveContextPayload hiveContext,
  }) {
    final String lower = userPrompt.trim().toLowerCase();
    if (lower.isEmpty) {
      return null;
    }

    final _WidgetFormulaUpdateIntent? widgetUpdate =
        _parseWidgetFormulaUpdateIntent(lower);
    if (widgetUpdate != null) {
      final AiBuildActionParseResult? plan = _inferUpdateWidgetFormula(
        intent: widgetUpdate,
        hiveContext: hiveContext,
      );
      if (plan != null) {
        return plan;
      }
    }

    final _CardCreateIntent? cardIntent = _parseCardCreateIntent(lower);
    if (cardIntent != null) {
      return _inferCreateCard(intent: cardIntent);
    }

    final _SummaryConvertIntent? summaryIntent =
        _parseSummaryConvertIntent(lower);
    if (summaryIntent != null) {
      return _inferSummaryConvert(
        intent: summaryIntent,
        hiveContext: hiveContext,
      );
    }

    return null;
  }

  static AiBuildActionParseResult? _inferUpdateWidgetFormula({
    required _WidgetFormulaUpdateIntent intent,
    required AiHiveContextPayload hiveContext,
  }) {
    final _WorkspaceIndex index = _WorkspaceIndex.load();
    final String? pageName = index.resolvePageName(intent.pageHint);
    if (pageName == null) {
      return null;
    }
    final String? widgetTitle = index.resolveWidgetTitle(
      pageName: pageName,
      titleHint: intent.widgetTitleHint,
    );
    if (widgetTitle == null) {
      return null;
    }

    final String? sourceTable = intent.preferTransactionsSource
        ? _resolveTransactionsTable(hiveContext)
        : null;
    final String tableName = sourceTable ??
        index.primaryTableOnPage(pageName) ??
        'Transactions';
    final String? amountColumn = index.firstNumericColumn(tableName);
    if (amountColumn == null) {
      return null;
    }

    final UpdateWidgetAction action = UpdateWidgetAction(
      pageRef: pageName,
      title: widgetTitle,
      tableRef: tableName,
      formula: 'SUM($tableName.$amountColumn)',
    );
    return AiBuildActionParseResult(
      actions: <AiBuildAction>[action],
      warnings: <String>[
        'Applied a local rule-based plan (update_widget for card formula).',
      ],
      fallbackText: '',
    );
  }

  static AiBuildActionParseResult? _inferCreateCard({
    required _CardCreateIntent intent,
  }) {
    final _WorkspaceIndex index = _WorkspaceIndex.load();
    final String? pageName = index.resolvePageName(intent.pageHint);
    if (pageName == null) {
      return null;
    }
    final String? tableName = index.primaryTableOnPage(pageName);
    if (tableName == null) {
      return null;
    }
    final String? amountColumn =
        index.firstNumericColumn(tableName) ??
        index.firstColumn(tableName);
    final String title = _titleFromCardIntent(intent);
    final String formula = amountColumn == null
        ? ''
        : 'SUM($tableName.$amountColumn)';

    final CreateCardWidgetAction action = CreateCardWidgetAction(
      pageRef: pageName,
      tableRef: tableName,
      title: title,
      formula: formula,
    );
    return AiBuildActionParseResult(
      actions: <AiBuildAction>[action],
      warnings: <String>[
        'Used a local rule-based plan because the model did not return JSON.',
      ],
      fallbackText: '',
    );
  }

  static AiBuildActionParseResult? _inferSummaryConvert({
    required _SummaryConvertIntent intent,
    required AiHiveContextPayload hiveContext,
  }) {
    final _WorkspaceIndex index = _WorkspaceIndex.load();
    final String? pageName = index.resolvePageName(intent.pageHint);
    if (pageName == null) {
      return null;
    }
    final String? targetTable = index.primaryTableOnPage(pageName);
    if (targetTable == null) {
      return null;
    }

    final String sourceTable = _resolveTransactionsTable(hiveContext) ?? 'Transactions';
    final List<String> sourceCols = index.columnsOf(sourceTable);
    final String groupBy = sourceCols
            .firstWhere(
              (String c) => c.toLowerCase().contains('product'),
              orElse: () => sourceCols.isNotEmpty ? sourceCols.first : 'Product',
            );
    final String aggregate = sourceCols
            .firstWhere(
              (String c) =>
                  c.toLowerCase().contains('total') ||
                  c.toLowerCase().contains('amount'),
              orElse: () =>
                  sourceCols.length > 1 ? sourceCols[1] : 'Total Amount',
            );

    final UpdateTableAction action = UpdateTableAction(
      name: targetTable,
      newName: intent.renameTo ?? '$sourceTable Summary',
      tableKind: AiBuildTableKind.summary,
      columns: const <AiBuildColumnSpec>[],
      summary: AiBuildSummarySpec(
        sourceTable: sourceTable,
        groupBy: groupBy,
        aggregate: aggregate,
        operation: AiBuildSummaryOperation.sum,
      ),
    );
    return AiBuildActionParseResult(
      actions: <AiBuildAction>[action],
      warnings: <String>[
        'Used a local rule-based plan because the model did not return JSON.',
      ],
      fallbackText: '',
    );
  }

  static String? _resolveTransactionsTable(AiHiveContextPayload hiveContext) {
    for (final String name in hiveContext.tableNames) {
      if (name.toLowerCase().contains('transaction') &&
          !name.toLowerCase().contains('summary')) {
        return name;
      }
    }
    return hiveContext.tableNames.isNotEmpty
        ? hiveContext.tableNames.first
        : null;
  }

  static String _titleFromCardIntent(_CardCreateIntent intent) {
    if (intent.titleHint != null && intent.titleHint!.trim().isNotEmpty) {
      return _titleCase(intent.titleHint!.trim());
    }
    return 'Summary Card';
  }

  static String _titleCase(String raw) {
    return raw
        .split(RegExp(r'\s+'))
        .where((String w) => w.isNotEmpty)
        .map(
          (String w) =>
              w.length <= 1 ? w.toUpperCase() : '${w[0].toUpperCase()}${w.substring(1)}',
        )
        .join(' ');
  }

  static _WidgetFormulaUpdateIntent? _parseWidgetFormulaUpdateIntent(
    String lower,
  ) {
    final bool wantsUpdate = RegExp(
      r'\b(update|change|modify|replace|fix|edit)\b',
    ).hasMatch(lower);
    final bool mentionsFormula =
        lower.contains('formula') ||
        lower.contains('use the') && lower.contains('table');
    final bool mentionsCard =
        lower.contains('card') || lower.contains('widget');
    if (!wantsUpdate || (!mentionsFormula && !mentionsCard)) {
      return null;
    }
    if (RegExp(r'\b(add|create|build|make|generate)\b').hasMatch(lower) &&
        !wantsUpdate) {
      return null;
    }
    String? widgetTitleHint;
    final RegExp inCard = RegExp(
      r'\b(?:in|on)\s+(?:the\s+)?(.+?)\s+card\b',
    );
    final Match? m1 = inCard.firstMatch(lower);
    if (m1 != null) {
      widgetTitleHint = m1.group(1)?.trim();
    }
    if (widgetTitleHint == null) {
      final RegExp bareCard = RegExp(r'\b(.+?)\s+card\b');
      final Match? m2 = bareCard.firstMatch(lower);
      widgetTitleHint = m2?.group(1)?.trim();
    }
    final bool preferTransactionsSource =
        (RegExp(r'\btransactions?\s+table\b').hasMatch(lower) &&
            !RegExp(r'\btransactions?\s+summary\s+table\b').hasMatch(lower)) ||
        lower.contains('not the transaction summary') ||
        lower.contains('not transaction summary');
    return _WidgetFormulaUpdateIntent(
      pageHint: _extractPageHint(lower),
      widgetTitleHint: widgetTitleHint,
      preferTransactionsSource: preferTransactionsSource,
    );
  }

  static _CardCreateIntent? _parseCardCreateIntent(String lower) {
    final bool wantsCard = lower.contains('card') || lower.contains('widget');
    final bool wantsAdd = RegExp(
      r'\b(add|create|build|make|generate|new)\b',
    ).hasMatch(lower);
    if (!wantsCard || !wantsAdd) {
      return null;
    }
    final String? pageHint = _extractPageHint(lower);
    String? titleHint;
    final RegExp titleMatch = RegExp(
      r'\b(?:add|create|build|make)\s+(?:a\s+)?(.+?)\s+(?:card|widget)\b',
    );
    final Match? m = titleMatch.firstMatch(lower);
    if (m != null) {
      titleHint = m.group(1)?.trim();
    }
    return _CardCreateIntent(pageHint: pageHint, titleHint: titleHint);
  }

  static _SummaryConvertIntent? _parseSummaryConvertIntent(String lower) {
    final bool wantsSummary = lower.contains('summary');
    final bool convert = RegExp(
      r'\b(make|convert|turn|change)\b.*\b(into|to)\b',
    ).hasMatch(lower) ||
        (lower.contains('summary') && lower.contains('table'));
    if (!wantsSummary || !convert) {
      return null;
    }
    return _SummaryConvertIntent(
      pageHint: _extractPageHint(lower),
      renameTo: lower.contains('transaction') ? 'Transactions Summary' : null,
    );
  }

  static String? _extractPageHint(String lower) {
    final RegExp onPage = RegExp(
      r'\b(?:on|in)\s+(?:the\s+)?([a-z0-9\s]+?)\s+page\b',
    );
    final Match? m = onPage.firstMatch(lower);
    if (m != null) {
      return m.group(1)?.trim();
    }
    final RegExp bare = RegExp(
      r'\b([a-z0-9\s]+?)\s+page\b',
    );
    final Match? m2 = bare.firstMatch(lower);
    return m2?.group(1)?.trim();
  }

  /// Prefer a heuristic plan over model JSON when the model picked the wrong
  /// action type (e.g. `update_table` for a card formula change).
  static bool shouldOverrideParsed(
    AiBuildActionParseResult parsed,
    AiBuildActionParseResult inferred,
  ) {
    if (!parsed.hasActions) {
      return true;
    }
    if (inferred.actions.isEmpty) {
      return false;
    }
    final AiBuildAction inferredAction = inferred.actions.first;
    if (inferredAction is! UpdateWidgetAction) {
      return false;
    }
    for (final AiBuildAction a in parsed.actions) {
      if (a is UpdateTableAction) {
        return true;
      }
      if (a is UpdateWidgetAction) {
        final String formula = a.formula?.toLowerCase() ?? '';
        final String want = inferredAction.formula?.toLowerCase() ?? '';
        if (formula.contains('summary') &&
            want.contains('transactions') &&
            !want.contains('summary')) {
          return true;
        }
      }
    }
    return false;
  }
}

final class _WidgetFormulaUpdateIntent {
  const _WidgetFormulaUpdateIntent({
    this.pageHint,
    this.widgetTitleHint,
    this.preferTransactionsSource = false,
  });

  final String? pageHint;
  final String? widgetTitleHint;
  final bool preferTransactionsSource;
}

final class _CardCreateIntent {
  const _CardCreateIntent({this.pageHint, this.titleHint});

  final String? pageHint;
  final String? titleHint;
}

final class _SummaryConvertIntent {
  const _SummaryConvertIntent({this.pageHint, this.renameTo});

  final String? pageHint;
  final String? renameTo;
}

/// Lightweight workspace lookup for heuristics.
final class _WorkspaceIndex {
  _WorkspaceIndex({
    required this.pageNames,
    required this.pageIdByName,
    required this.tablesByPageName,
    required this.columnsByTableName,
    required this.widgetTitlesByPageName,
  });

  final List<String> pageNames;
  final Map<String, String> pageIdByName;
  final Map<String, List<String>> tablesByPageName;
  final Map<String, List<String>> columnsByTableName;
  final Map<String, List<String>> widgetTitlesByPageName;

  factory _WorkspaceIndex.load() {
    final List<String> pageNames = <String>[];
    final Map<String, String> pageIdToName = <String, String>{};
    final Map<String, List<String>> tablesByPageId = <String, List<String>>{};
    final Map<String, List<String>> columnsByTableName = <String, List<String>>{};

    if (Hive.isBoxOpen(HiveBoxes.pagesBox)) {
      for (final BuilderPageHiveModel p
          in Hive.box<BuilderPageHiveModel>(HiveBoxes.pagesBox).values) {
        if (p.isDeleted || p.name.trim().isEmpty) {
          continue;
        }
        pageNames.add(p.name.trim());
        pageIdToName[p.id] = p.name.trim();
      }
    }

    if (Hive.isBoxOpen(HiveBoxes.tablesBox)) {
      for (final TableSchemaHiveModel t
          in Hive.box<TableSchemaHiveModel>(HiveBoxes.tablesBox).values) {
        final String name = t.name.trim();
        if (name.isEmpty) {
          continue;
        }
        tablesByPageId.putIfAbsent(t.pageId, () => <String>[]).add(name);
        columnsByTableName[name] = t.columns
            .map((Map<String, dynamic> c) => (c['name'] as String?)?.trim() ?? '')
            .where((String n) => n.isNotEmpty)
            .toList(growable: false);
      }
    }

    final Map<String, List<String>> tablesByPageName = <String, List<String>>{};
    final Map<String, String> pageIdByName = <String, String>{};
    for (final MapEntry<String, String> e in pageIdToName.entries) {
      pageIdByName[e.value] = e.key;
      final List<String>? tables = tablesByPageId[e.key];
      if (tables != null && tables.isNotEmpty) {
        tablesByPageName[e.value] = tables;
      }
    }

    final Map<String, List<String>> widgetTitlesByPageName =
        <String, List<String>>{};
    if (Hive.isBoxOpen(HiveBoxes.widgetsBox)) {
      for (final BuilderWidgetHiveModel w
          in Hive.box<BuilderWidgetHiveModel>(HiveBoxes.widgetsBox).values) {
        final String? pageName = pageIdToName[w.pageId];
        if (pageName == null) {
          continue;
        }
        final String title = (w.config['title'] as String?)?.trim() ?? '';
        if (title.isEmpty) {
          continue;
        }
        widgetTitlesByPageName.putIfAbsent(pageName, () => <String>[]).add(title);
      }
    }

    pageNames.sort(
      (String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()),
    );

    return _WorkspaceIndex(
      pageNames: pageNames,
      pageIdByName: pageIdByName,
      tablesByPageName: tablesByPageName,
      columnsByTableName: columnsByTableName,
      widgetTitlesByPageName: widgetTitlesByPageName,
    );
  }

  String? resolveWidgetTitle({
    required String pageName,
    String? titleHint,
  }) {
    final List<String> titles = widgetTitlesByPageName[pageName] ?? const <String>[];
    if (titles.isEmpty) {
      return titleHint == null ? null : AiBuildHeuristics._titleCase(titleHint);
    }
    if (titleHint == null || titleHint.trim().isEmpty) {
      return titles.length == 1 ? titles.first : null;
    }
    final String target = _normalize(titleHint);
    for (final String t in titles) {
      if (_normalize(t) == target) {
        return t;
      }
    }
    for (final String t in titles) {
      final String n = _normalize(t);
      if (n.contains(target) || target.contains(n)) {
        return t;
      }
    }
    return AiBuildHeuristics._titleCase(titleHint);
  }

  String? resolvePageName(String? hint) {
    if (pageNames.isEmpty) {
      return null;
    }
    if (hint == null || hint.trim().isEmpty) {
      return pageNames.length == 1 ? pageNames.first : null;
    }
    final String target = _normalize(hint);
    for (final String name in pageNames) {
      if (_normalize(name) == target) {
        return name;
      }
    }
    for (final String name in pageNames) {
      final String n = _normalize(name);
      if (n.contains(target) || target.contains(n)) {
        return name;
      }
    }
    if (target.endsWith('s')) {
      final String singular = target.substring(0, target.length - 1);
      for (final String name in pageNames) {
        if (_normalize(name) == singular) {
          return name;
        }
      }
    }
    return null;
  }

  String? primaryTableOnPage(String pageName) {
    final List<String>? tables = tablesByPageName[pageName];
    if (tables == null || tables.isEmpty) {
      return null;
    }
    if (tables.length == 1) {
      return tables.first;
    }
    for (final String t in tables) {
      if (t.toLowerCase().contains('summary')) {
        return t;
      }
    }
    return tables.first;
  }

  List<String> columnsOf(String tableName) {
    return columnsByTableName[tableName] ?? const <String>[];
  }

  String? firstNumericColumn(String tableName) {
    for (final String c in columnsOf(tableName)) {
      final String lower = c.toLowerCase();
      if (lower.contains('amount') ||
          lower.contains('total') ||
          lower.contains('qty') ||
          lower.contains('price') ||
          lower.contains('stock')) {
        return c;
      }
    }
    return null;
  }

  String? firstColumn(String tableName) {
    final List<String> cols = columnsOf(tableName);
    return cols.isEmpty ? null : cols.first;
  }

  static String _normalize(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
