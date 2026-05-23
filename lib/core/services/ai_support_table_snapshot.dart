import 'dart:convert';
import 'dart:math' as math;

import 'package:antwise/core/formatting/user_friendly_calendar_date.dart';
import 'package:antwise/core/storage/hive_boxes.dart';
import 'package:antwise/data/mappers/table_schema_entity_from_hive.dart';
import 'package:antwise/data/models/hive/table_row_hive_model.dart';
import 'package:antwise/data/models/hive/table_schema_hive_model.dart';
import 'package:antwise/domain/entities/table_column_type.dart';
import 'package:antwise/domain/entities/table_row_entity.dart';
import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/domain/formula/table_formula_evaluator.dart';
import 'package:hive/hive.dart';

/// Parsed calendar range for deterministic aggregate lookups.
final class _TemporalFilter {
  const _TemporalFilter({
    required this.startInclusive,
    required this.endInclusive,
    required this.displayLabel,
    this.specificCalendarDay = false,
  });

  final DateTime startInclusive;
  final DateTime endInclusive;
  final String displayLabel;

  /// True when [displayLabel] is a single calendar day shown in long form (not words like 'today').
  final bool specificCalendarDay;
}

/// Builds a compact table/column outline for on-device AI support prompts.
abstract final class AiSupportTableSnapshot {
  static const int _maxTables = 12;
  static const int _maxColsPerTable = 14;
  static const int _maxOutlineChars = 1600;

  /// Empty string if Hive is unavailable or there are no tables.
  static String tryBuild() {
    try {
      if (!Hive.isBoxOpen(HiveBoxes.tablesBox)) {
        return '';
      }
      final Iterable<TableSchemaHiveModel> values =
          Hive.box<TableSchemaHiveModel>(HiveBoxes.tablesBox).values;
      final List<TableSchemaHiveModel> tables = values.toList(growable: false)
        ..sort(
          (TableSchemaHiveModel a, TableSchemaHiveModel b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      if (tables.isEmpty) {
        return '';
      }
      final StringBuffer out = StringBuffer();
      final int limit = tables.length > _maxTables ? _maxTables : tables.length;
      for (int i = 0; i < limit; i++) {
        final TableSchemaHiveModel t = tables[i];
        final String name = t.name.trim();
        if (name.isEmpty) {
          continue;
        }
        out.write('- ');
        out.write(name);
        out.write(': ');
        final List<String> colParts = <String>[];
        int colCount = 0;
        for (final Map<String, dynamic> raw in t.columns) {
          if (colCount >= _maxColsPerTable) {
            colParts.add('…');
            break;
          }
          final String cn = (raw['name'] ?? '').toString().trim();
          if (cn.isEmpty) {
            continue;
          }
          final String ty = (raw['type'] ?? 'text').toString().trim();
          colParts.add(ty.isEmpty ? cn : '$cn ($ty)');
          colCount++;
        }
        out.writeln(colParts.isEmpty ? '(no columns)' : colParts.join(', '));
        if (out.length >= _maxOutlineChars) {
          out.writeln('… (outline truncated)');
          break;
        }
      }
      if (tables.length > _maxTables) {
        out.writeln('… and ${tables.length - _maxTables} more table(s)');
      }
      return out.toString().trimRight();
    } catch (_) {
      return '';
    }
  }

  static final RegExp _allRecordsQuery = RegExp(
    r'\ball\s+records\s+(?:in|of|from)\s+(?:the\s+)?["`]?([^"`]+?)["`]?\s*(?:table)?\s*$',
    caseSensitive: false,
  );

  /// Deterministic reply for queries like:
  /// "all records in transactions table".
  /// Returns null when the message is not a supported direct-data query.
  static String? tryBuildAllRecordsReply(String userMessage) {
    final String trimmed = userMessage.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final RegExpMatch? match = _allRecordsQuery.firstMatch(trimmed);
    if (match == null) {
      return null;
    }

    final String rawTableName = (match.group(1) ?? '').trim();
    final String queryTableName =
        rawTableName
            .replaceAll(RegExp(r'\s+'), ' ')
            .replaceAll(RegExp(r'\btable\b$', caseSensitive: false), '')
            .trim();
    if (queryTableName.isEmpty) {
      return null;
    }

    try {
      if (!Hive.isBoxOpen(HiveBoxes.tablesBox)) {
        return 'I cannot read tables right now because local table storage is not available.';
      }
      final List<TableSchemaHiveModel> tables = Hive.box<TableSchemaHiveModel>(
        HiveBoxes.tablesBox,
      ).values.toList(growable: false);
      if (tables.isEmpty) {
        return 'There are no tables in your workspace yet.';
      }

      final String lookup = queryTableName.toLowerCase();
      TableSchemaHiveModel? target;
      for (final TableSchemaHiveModel table in tables) {
        if (table.name.trim().toLowerCase() == lookup) {
          target = table;
          break;
        }
      }
      if (target == null) {
        return 'I could not find a table named "$queryTableName".';
      }

      if (!Hive.isBoxOpen(HiveBoxes.rowsBox)) {
        return 'I found "${target.name}" but local row storage is not available right now.';
      }

      final List<TableRowHiveModel> rows = Hive.box<TableRowHiveModel>(
            HiveBoxes.rowsBox,
          ).values
          .where((TableRowHiveModel row) => row.tableId == target!.id)
          .toList(growable: false);

      if (rows.isEmpty) {
        return 'The "${target.name}" table currently has no records.';
      }

      final Map<String, String> columnNamesById = <String, String>{};
      for (final Map<String, dynamic> raw in target.columns) {
        final String id = (raw['id'] ?? '').toString().trim();
        final String name = (raw['name'] ?? '').toString().trim();
        if (id.isNotEmpty) {
          columnNamesById[id] = name.isEmpty ? id : name;
        }
      }

      const int maxRows = 80;
      final int shownCount = rows.length > maxRows ? maxRows : rows.length;
      final List<Map<String, dynamic>> payload = <Map<String, dynamic>>[];
      for (int i = 0; i < shownCount; i++) {
        final TableRowHiveModel row = rows[i];
        final Map<String, dynamic> rowMap = <String, dynamic>{};
        row.values.forEach((String columnId, dynamic value) {
          final String label = columnNamesById[columnId] ?? columnId;
          rowMap[label] = value;
        });
        payload.add(rowMap);
      }

      final String jsonBody = const JsonEncoder.withIndent(
        '  ',
      ).convert(payload);
      if (rows.length > maxRows) {
        return 'Showing $shownCount of ${rows.length} records from "${target.name}":\n$jsonBody\n'
            '... ${rows.length - maxRows} more record(s) not shown.';
      }
      return 'All ${rows.length} record(s) from "${target.name}":\n$jsonBody';
    } catch (_) {
      return 'I could not read records for "$queryTableName" right now.';
    }
  }

  static DateTime _calendarDay(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool _calendarDayBetweenInclusive(
    DateTime cell,
    DateTime startInclusive,
    DateTime endInclusive,
  ) {
    final DateTime x = _calendarDay(cell);
    final DateTime s = _calendarDay(startInclusive);
    final DateTime e = _calendarDay(endInclusive);
    return !x.isBefore(s) && !x.isAfter(e);
  }

  static String _formatAmount(double sum) {
    if (!sum.isFinite) {
      return '0';
    }
    return sum == sum.roundToDouble()
        ? sum.toStringAsFixed(0)
        : sum.toStringAsFixed(2);
  }

  /// User-facing wording after "total" (e.g. "transactions today is …").
  static String _totalsSentenceSubject({
    required String queryLower,
    required _TemporalFilter? temporal,
  }) {
    final String e = _entityHead(queryLower).trimRight();
    if (temporal == null) {
      return e.isEmpty ? 'amounts' : e;
    }
    if (temporal.specificCalendarDay) {
      if (e.isEmpty) {
        return 'records on ${temporal.displayLabel}';
      }
      return '${e.trim()} on ${temporal.displayLabel}'.trimLeft();
    }
    final String d = temporal.displayLabel.trim().toLowerCase();
    if (e.isEmpty) {
      if (d == 'today' || d == 'yesterday') {
        return 'records $d';
      }
      if (d.startsWith('this ') || d.startsWith('last ')) {
        return 'records for $d';
      }
      return 'records for ${temporal.displayLabel}';
    }
    switch (d) {
      case 'today':
      case 'yesterday':
        return '${e.trim()} $d'.trimLeft();
      case 'this week':
      case 'this month':
      case 'last month':
      case 'last week':
        return '${e.trim()} for $d'.trimLeft();
      default:
        return '${e.trim()} for ${temporal.displayLabel}'.trimLeft();
    }
  }

  static String _entityHead(String queryLower) {
    if (queryLower.contains('transactions') ||
        queryLower.contains('transaction')) {
      return 'transactions';
    }
    if (queryLower.contains('sale')) return 'sales';
    if (queryLower.contains('order')) return 'orders';
    if (queryLower.contains('expense')) return 'expenses';
    if (queryLower.contains('customer')) return 'customers';
    if (queryLower.contains('payment')) return 'payments';
    return '';
  }

  /// For negative results (e.g. "No transactions were found …").
  static String _entityNoun(String queryLower) {
    if (queryLower.contains('transactions')) {
      return 'transactions ';
    }
    if (queryLower.contains('transaction')) {
      return 'transactions ';
    }
    if (queryLower.contains('sales') || queryLower.contains('sale')) {
      return 'sales ';
    }
    if (queryLower.contains('order')) {
      return 'matching orders ';
    }
    return 'matching records ';
  }

  static String _temporalUserPhrase(_TemporalFilter f) {
    return 'for ${_temporalPrep(f.displayLabel)}';
  }

  static String _temporalPrep(String label) {
    final String s = label.trim();
    final String lower = s.toLowerCase();
    if (lower == 'today' || lower == 'yesterday') {
      return s;
    }
    return s;
  }

  /// Parse common time phrases; returns null if no time qualifier for filtering.
  static _TemporalFilter? _parseTemporalFilter({
    required String trimmedText,
    required String lowerText,
    required DateTime referenceNow,
  }) {
    DateTime sd(int y, int mo, int d) => DateTime(y, mo, d);
    final DateTime today = _calendarDay(referenceNow);

    if (lowerText.contains('today') ||
        RegExp(r"\btoday'?s\b").hasMatch(lowerText) ||
        lowerText.contains('this day') ||
        lowerText.contains('this date')) {
      return _TemporalFilter(
        startInclusive: today,
        endInclusive: today,
        displayLabel: 'today',
      );
    }
    if (lowerText.contains('yesterday')) {
      final DateTime y = today.subtract(const Duration(days: 1));
      return _TemporalFilter(
        startInclusive: y,
        endInclusive: y,
        displayLabel: 'yesterday',
      );
    }
    if (RegExp(r'\bthis\s+week\b').hasMatch(lowerText)) {
      final int weekday = referenceNow.weekday;
      final DateTime weekStart = today.subtract(Duration(days: weekday - 1));
      final DateTime weekEnd = weekStart.add(const Duration(days: 6));
      return _TemporalFilter(
        startInclusive: weekStart,
        endInclusive: weekEnd,
        displayLabel: 'this week',
      );
    }
    if (RegExp(r'\blast\s+week\b').hasMatch(lowerText)) {
      final int weekday = referenceNow.weekday;
      final DateTime thisWeekStart = today.subtract(
        Duration(days: weekday - 1),
      );
      final DateTime prevEnd = thisWeekStart.subtract(const Duration(days: 1));
      final DateTime prevStart = prevEnd.subtract(const Duration(days: 6));
      return _TemporalFilter(
        startInclusive: prevStart,
        endInclusive: prevEnd,
        displayLabel: 'last week',
      );
    }
    if (RegExp(r'\bthis\s+month\b').hasMatch(lowerText)) {
      final DateTime moStart = sd(referenceNow.year, referenceNow.month, 1);
      final DateTime moEnd = sd(referenceNow.year, referenceNow.month + 1, 0);
      return _TemporalFilter(
        startInclusive: moStart,
        endInclusive: moEnd,
        displayLabel: 'this month',
      );
    }
    if (RegExp(r'\blast\s+month\b').hasMatch(lowerText)) {
      final DateTime firstThis = sd(referenceNow.year, referenceNow.month, 1);
      final DateTime prevLast = firstThis.subtract(const Duration(days: 1));
      final DateTime prevStart = sd(prevLast.year, prevLast.month, 1);
      return _TemporalFilter(
        startInclusive: prevStart,
        endInclusive: prevLast,
        displayLabel: 'last month',
      );
    }

    final Match? iso = RegExp(
      r'\b(\d{4})-(\d{1,2})-(\d{1,2})\b',
    ).firstMatch(trimmedText);
    if (iso != null) {
      final int? y = int.tryParse(iso.group(1)!);
      final int? mo = int.tryParse(iso.group(2)!);
      final int? d = int.tryParse(iso.group(3)!);
      if (y != null && mo != null && d != null) {
        try {
          final DateTime picked = sd(y, mo, d);
          final DateTime pj = sd(picked.year, picked.month, picked.day);
          return _TemporalFilter(
            startInclusive: pj,
            endInclusive: pj,
            displayLabel: formatUserFriendlyCalendarDate(pj),
            specificCalendarDay: true,
          );
        } catch (_) {}
      }
    }

    final Match? slash = RegExp(
      r'\b(\d{1,2})/(\d{1,2})/(\d{2,4})\b',
    ).firstMatch(trimmedText);
    if (slash != null) {
      final String yTok = slash.group(3)!;
      int? mm = int.tryParse(slash.group(1)!);
      int? dd = int.tryParse(slash.group(2)!);
      int ys = int.tryParse(yTok) ?? referenceNow.year;
      if (yTok.length <= 2) {
        ys = ys >= 70 ? 1900 + ys : 2000 + ys;
      }
      if (mm != null && dd != null) {
        if (mm > 12 && dd <= 12) {
          final int t = mm;
          mm = dd;
          dd = t;
        }
        try {
          final DateTime picked = sd(ys, mm, dd);
          final DateTime pj = sd(picked.year, picked.month, picked.day);
          return _TemporalFilter(
            startInclusive: pj,
            endInclusive: pj,
            displayLabel: formatUserFriendlyCalendarDate(pj),
            specificCalendarDay: true,
          );
        } catch (_) {}
      }
    }

    final Match? dm = RegExp(
      r'\b(\d{1,2})\s+(jan|january|feb|february|mar|march|apr|april|may|jun|june|jul|july|aug|august|sep|september|oct|october|nov|november|dec|december)(?:[,]?\s*(\d{4}))?\b',
      caseSensitive: false,
    ).firstMatch(trimmedText);
    if (dm != null) {
      final int? day = int.tryParse(dm.group(1)!);
      final int? mo = _monthAbbrevToNumber(dm.group(2)!);
      final int yr =
          dm.group(3) != null
              ? (int.tryParse(dm.group(3)!) ?? referenceNow.year)
              : referenceNow.year;
      if (mo != null && day != null) {
        try {
          final DateTime pj = sd(yr, mo, day);
          return _TemporalFilter(
            startInclusive: pj,
            endInclusive: pj,
            displayLabel: formatUserFriendlyCalendarDate(pj),
            specificCalendarDay: true,
          );
        } catch (_) {}
      }
    }

    final Match? md = RegExp(
      r'\b(jan|january|feb|february|mar|march|apr|april|may|jun|june|jul|july|aug|august|sep|september|oct|october|nov|november|dec|december)\s+(\d{1,2})(?:st|nd|rd|th)?(?:[,\s]+(\d{4}))?\b',
      caseSensitive: false,
    ).firstMatch(trimmedText);
    if (md != null) {
      final int? mo = _monthAbbrevToNumber(md.group(1)!);
      final int? day = int.tryParse(md.group(2)!);
      final int yr =
          md.group(3) != null
              ? (int.tryParse(md.group(3)!) ?? referenceNow.year)
              : referenceNow.year;
      if (mo != null && day != null) {
        try {
          final DateTime pj = sd(yr, mo, day);
          return _TemporalFilter(
            startInclusive: pj,
            endInclusive: pj,
            displayLabel: formatUserFriendlyCalendarDate(pj),
            specificCalendarDay: true,
          );
        } catch (_) {}
      }
    }

    return null;
  }

  static int? _monthAbbrevToNumber(String tok) {
    final String x = tok.toLowerCase();
    const Map<String, int> map = <String, int>{
      'january': 1,
      'jan': 1,
      'feb': 2,
      'february': 2,
      'mar': 3,
      'march': 3,
      'apr': 4,
      'april': 4,
      'may': 5,
      'jun': 6,
      'june': 6,
      'jul': 7,
      'july': 7,
      'aug': 8,
      'august': 8,
      'sep': 9,
      'sept': 9,
      'september': 9,
      'oct': 10,
      'october': 10,
      'nov': 11,
      'november': 11,
      'dec': 12,
      'december': 12,
    };
    final Match? fm = RegExp(r'^[a-z]+').firstMatch(x.trim());
    final String stem = fm?.group(0) ?? x.trim();
    return map[stem] ?? map[x.trim()];
  }

  /// Business keywords for mapping natural language to Hive table names (partial match).
  static const List<String> _businessHints = <String>[
    'transaction',
    'transactions',
    'sale',
    'sales',
    'order',
    'orders',
    'expense',
    'expenses',
    'inventory',
    'stock',
    'customer',
    'customers',
    'payment',
    'payments',
    'invoice',
    'invoices',
    'purchase',
    'purchases',
    'revenue',
    'report',
    'reports',
  ];

  static bool _isProfitCalculationQuery(String lower) {
    if (RegExp(
      r'\bnon\s*[-]?\s*profit\b|\bnonprofit\b',
      caseSensitive: false,
    ).hasMatch(lower)) {
      return false;
    }
    return RegExp(
          r'\b(profit|profits|nett?\s+income|bottom\s+line|net\s+result)\b',
          caseSensitive: false,
        ).hasMatch(lower) ||
        (RegExp(r'\b(loss|losses)\b').hasMatch(lower) &&
            RegExp(
              r'\b(monetary|money|financial|today|business|made|earn)\b',
              caseSensitive: false,
            ).hasMatch(lower));
  }

  /// Prefer raw ledger `Transactions` over summary / rollups for profit.
  static TableSchemaHiveModel? _preferTransactionsPrimaryTable(
    List<TableSchemaHiveModel> tables, {
    required bool allowSummaryFallback,
  }) {
    bool isSummaryLike(TableSchemaHiveModel t) {
      final String name = t.name.toLowerCase();
      final String condensed = name.replaceAll(RegExp(r'[^a-z0-9]'), '');
      final String kind = t.tableKind.toLowerCase();
      return name.contains(' summary') ||
          condensed.endsWith('summary') ||
          RegExp(r'\bsummary\b').hasMatch(name) ||
          RegExp(r'\brollup\b').hasMatch(name) ||
          kind.contains('summary') ||
          kind.contains('rollup');
    }

    bool isTransactionName(String condensed, String nameLower) {
      return condensed == 'transactions' ||
          condensed == 'transaction' ||
          nameLower.contains('transaction');
    }

    TableSchemaHiveModel? exactLedger;
    TableSchemaHiveModel? otherLedger;
    TableSchemaHiveModel? summaryLedger;

    for (final TableSchemaHiveModel t in tables) {
      final String nameLower = t.name.trim().toLowerCase();
      final String condensed = nameLower.replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (!isTransactionName(condensed, nameLower)) {
        continue;
      }
      final bool summ = isSummaryLike(t);
      if (summ) {
        summaryLedger ??= t;
        continue;
      }
      if (condensed == 'transactions' || condensed == 'transaction') {
        exactLedger = t;
        break;
      }
      otherLedger ??= t;
    }
    if (exactLedger != null) {
      return exactLedger;
    }
    if (otherLedger != null) {
      return otherLedger;
    }
    if (allowSummaryFallback && summaryLedger != null) {
      return summaryLedger;
    }
    return null;
  }

  /// Best numeric column whose name matches [hintSubstrings] (income vs expense).
  static ({String id, String label, int score})? _bestAmountColumnForHints(
    List<Map<String, dynamic>> cols,
    List<String> hintSubstrings,
  ) {
    TableColumnType tyOf(Map<String, dynamic> raw) =>
        TableColumnType.fromStorage((raw['type'] ?? 'text').toString());

    ({String id, String label, int score})? best;
    int bestScore = 0;

    for (final Map<String, dynamic> raw in cols) {
      final String id = (raw['id'] ?? '').toString().trim();
      final String nm = (raw['name'] ?? '').toString().trim().toLowerCase();
      if (id.isEmpty) continue;

      final TableColumnType ty = tyOf(raw);
      if (ty != TableColumnType.number &&
          ty != TableColumnType.formula &&
          ty != TableColumnType.autoGenerated) {
        continue;
      }

      int s =
          ty == TableColumnType.formula
              ? 35
              : ty == TableColumnType.number ||
                  ty == TableColumnType.autoGenerated
              ? 28
              : 0;

      for (final String h in hintSubstrings) {
        if (nm.contains(h)) {
          s += 24;
        }
      }
      if (nm.contains('amount') || nm.contains('total') || nm.contains('sum')) {
        s += 10;
      }
      if (ty == TableColumnType.formula &&
          (nm.contains('total') || nm.contains('amount'))) {
        s += 18;
      }

      if (s > bestScore) {
        bestScore = s;
        best = (id: id, label: (raw['name'] ?? '').toString().trim(), score: s);
      }
    }
    return bestScore >= 44 ? best : null;
  }

  static String _profitTodayClause(_TemporalFilter? temporal) {
    if (temporal == null) {
      return 'overall';
    }
    final String d = temporal.displayLabel.trim().toLowerCase();
    if (d == 'today' || d == 'yesterday') {
      return d;
    }
    if (d.startsWith('this ') || d.startsWith('last ')) {
      return 'for $d';
    }
    if (temporal.specificCalendarDay) {
      return 'on ${temporal.displayLabel}';
    }
    return 'for ${temporal.displayLabel}';
  }

  /// Profit = income − expenses from the primary transactions ledger (deterministic).
  static String? tryBuildProfitReply(String userMessage) {
    final String trimmed = userMessage.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final String lower = trimmed.toLowerCase();
    if (!_isProfitCalculationQuery(lower)) {
      return null;
    }

    try {
      if (!Hive.isBoxOpen(HiveBoxes.tablesBox) ||
          !Hive.isBoxOpen(HiveBoxes.rowsBox)) {
        return null;
      }

      final DateTime nowLocal = DateTime.now();
      final _TemporalFilter? temporalFilter = _parseTemporalFilter(
        trimmedText: trimmed,
        lowerText: lower,
        referenceNow: nowLocal,
      );

      final List<TableSchemaHiveModel> tables = Hive.box<TableSchemaHiveModel>(
            HiveBoxes.tablesBox,
          ).values
          .where((TableSchemaHiveModel s) => s.name.trim().isNotEmpty)
          .toList(growable: false);
      if (tables.isEmpty) {
        return 'There are no tables in your workspace yet.';
      }

      final bool prefersSummaryExplicit =
          RegExp(r'\bsummary\b').hasMatch(lower) ||
          RegExp(r'\baggregat(?:e|ed)\b').hasMatch(lower) ||
          RegExp(r'\brollup\b').hasMatch(lower);

      TableSchemaHiveModel? target =
          _preferTransactionsPrimaryTable(
            tables,
            allowSummaryFallback: prefersSummaryExplicit,
          ) ??
          _pickMatchingBusinessTable(
            tables: tables,
            queryLower:
                '$lower '
                '${prefersSummaryExplicit ? '' : 'transactions ledger'}',
            prefersSummary: prefersSummaryExplicit,
            prioritizeTransactionsLedger: true,
          );
      if (target == null) {
        return 'Profit could not be calculated because no suitable transactions-style '
            'table was found in your workspace.';
      }

      final List<Map<String, dynamic>> colsTyped = target.columns.toList(
        growable: false,
      );
      final ({String id, String label})? datePick =
          temporalFilter != null ? _pickDateColumn(colsTyped) : null;
      const List<String> incomeHints = <String>[
        'revenue',
        'income',
        'sale',
        'sales',
        'credit',
        'earning',
        'deposit',
        'inflow',
        'received',
      ];
      const List<String> expenseHints = <String>[
        'expense',
        'cost',
        'spend',
        'purchase',
        'fee',
        'withdraw',
        'outgoing',
        'debit',
        'payout',
        'spent',
      ];
      final ({String id, String label, int score})? incomePick =
          _bestAmountColumnForHints(colsTyped, incomeHints);
      final ({String id, String label, int score})? expensePick =
          _bestAmountColumnForHints(colsTyped, expenseHints);

      final bool dualIncomeExpense =
          incomePick != null &&
          expensePick != null &&
          incomePick.id != expensePick.id &&
          incomePick.score >= 58 &&
          expensePick.score >= 58;

      final String? incomeId = dualIncomeExpense ? incomePick.id : null;
      final String? expenseId = dualIncomeExpense ? expensePick.id : null;
      final ({String id, String label})? netPick =
          dualIncomeExpense ? null : _pickAmountColumn(colsTyped);

      if (!dualIncomeExpense && netPick == null) {
        return 'No sufficient data found${_temporalUserPhraseBare(temporalFilter)} '
            'to calculate profit from the ${target.name} table.';
      }

      if (temporalFilter != null && datePick == null) {
        return 'To calculate profit for ${_temporalPrep(temporalFilter.displayLabel)}, '
            'the ${target.name} table needs a clear date-style column (such as Date or Created at).';
      }

      final String tableId = target.id;
      final List<TableRowHiveModel> rows = Hive.box<TableRowHiveModel>(
            HiveBoxes.rowsBox,
          ).values
          .where((TableRowHiveModel row) => row.tableId == tableId)
          .toList(growable: false);

      final String nameLine = target.name.trim();

      if (rows.isEmpty) {
        return 'No sufficient data found${_temporalUserPhraseBare(temporalFilter)} '
            'to calculate profit from the $nameLine table.';
      }

      final String? dateColId =
          temporalFilter != null ? datePick?.id.trim() : null;
      final bool applyDateFilter =
          temporalFilter != null && dateColId != null && dateColId.isNotEmpty;

      final List<TableSchemaEntity> allSchemas = tables
          .map(tableSchemaEntityFromHive)
          .toList(growable: false);
      final TableSchemaEntity targetSchemaEntity = tableSchemaEntityFromHive(
        target,
      );
      final Map<String, List<TableRowEntity>> rowsByTableId =
          <String, List<TableRowEntity>>{};
      for (final TableRowHiveModel r
          in Hive.box<TableRowHiveModel>(HiveBoxes.rowsBox).values) {
        rowsByTableId
            .putIfAbsent(r.tableId, () => <TableRowEntity>[])
            .add(
              TableRowEntity(id: r.id, tableId: r.tableId, values: r.values),
            );
      }

      double incomeSum = 0;
      double expenseSum = 0;
      double netSum = 0;
      int rowsInWindow = 0;
      int rowsWithNumbers = 0;

      final _TemporalFilter? tf = temporalFilter;
      for (final TableRowHiveModel rowHive in rows) {
        final Map<String, dynamic> resolved =
            TableFormulaEvaluator.resolveRowValues(
              schema: targetSchemaEntity,
              row: TableRowEntity(
                id: rowHive.id,
                tableId: rowHive.tableId,
                values: rowHive.values,
              ),
              allSchemas: allSchemas,
              rowsByTableId: rowsByTableId,
            );

        if (applyDateFilter) {
          final _TemporalFilter rng = tf!;
          final DateTime? cell = _interpretAsLocalDate(
            resolved[dateColId] ?? rowHive.values[dateColId],
            dateColumnSemantics: true,
          );
          if (cell == null) {
            continue;
          }
          if (!_calendarDayBetweenInclusive(
            cell,
            rng.startInclusive,
            rng.endInclusive,
          )) {
            continue;
          }
        }
        rowsInWindow++;

        if (dualIncomeExpense) {
          final double? inc = _asDouble(
            resolved[incomeId!] ?? rowHive.values[incomeId],
          );
          final double? exp = _asDouble(
            resolved[expenseId!] ?? rowHive.values[expenseId],
          );
          if (inc != null && inc.isFinite) {
            incomeSum += inc;
            rowsWithNumbers++;
          }
          if (exp != null && exp.isFinite) {
            expenseSum += exp;
            rowsWithNumbers++;
          }
        } else {
          final String nid = netPick!.id;
          final double? n = _asDouble(resolved[nid] ?? rowHive.values[nid]);
          if (n != null && n.isFinite) {
            netSum += n;
            rowsWithNumbers++;
          }
        }
      }

      final String windowClause = _profitTodayClause(temporalFilter);

      if (applyDateFilter && rowsInWindow == 0) {
        return 'No sufficient data found${_temporalUserPhraseBare(tf)} '
            'to calculate profit from the $nameLine table.';
      }

      if (rowsInWindow > 0 && rowsWithNumbers == 0) {
        return 'There ${rowsInWindow == 1 ? 'is' : 'are'} $rowsInWindow '
            '${rowsInWindow == 1 ? 'record' : 'records'}${_temporalUserPhraseBare(tf)} '
            'in the $nameLine table, but profit could not be computed from readable amounts '
            '(including formulas). Check your income, expense, or total columns.';
      }

      final double profit = dualIncomeExpense ? incomeSum - expenseSum : netSum;
      final String p = _formatAmount(profit);

      if (windowClause == 'overall') {
        return 'Your profit overall is $p based on the $nameLine table.';
      }
      if (windowClause == 'today' || windowClause == 'yesterday') {
        return 'Your profit $windowClause is $p based on the $nameLine table.';
      }
      return 'Your profit $windowClause is $p based on the $nameLine table.';
    } catch (_) {
      return null;
    }
  }

  static String _temporalUserPhraseBare(_TemporalFilter? f) {
    if (f == null) return '';
    return ' ${_temporalUserPhrase(f)}'.trimRight();
    // produces " for today"
  }

  /// Deterministic totals for questions like total transactions today.
  static String? tryBuildAggregateTotalReply(String userMessage) {
    final String trimmed = userMessage.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final String lower = trimmed.toLowerCase();
    final bool wantsAggregate = RegExp(
      r'\b(total|sum|how\s+much|combined)\b',
      caseSensitive: false,
    ).hasMatch(lower);
    final bool businessContext =
        _businessHints.any((String hint) => lower.contains(hint)) ||
        RegExp(
          r'\b(transactions?|sale|sales|revenue)\b',
          caseSensitive: false,
        ).hasMatch(lower);

    if (!wantsAggregate || !businessContext) {
      return null;
    }

    try {
      if (!Hive.isBoxOpen(HiveBoxes.tablesBox) ||
          !Hive.isBoxOpen(HiveBoxes.rowsBox)) {
        return null;
      }
      final DateTime nowLocal = DateTime.now();
      final _TemporalFilter? temporalFilter = _parseTemporalFilter(
        trimmedText: trimmed,
        lowerText: lower,
        referenceNow: nowLocal,
      );

      final List<TableSchemaHiveModel> tables = Hive.box<TableSchemaHiveModel>(
            HiveBoxes.tablesBox,
          ).values
          .where((TableSchemaHiveModel s) => s.name.trim().isNotEmpty)
          .toList(growable: false);
      if (tables.isEmpty) {
        return 'There are no tables in your workspace yet.';
      }

      final bool prefersSummaryExplicit =
          RegExp(r'\bsummary\b', caseSensitive: false).hasMatch(lower) ||
          RegExp(r'\baggregat(?:e|ed)\b').hasMatch(lower) ||
          RegExp(r'\brollup\b').hasMatch(lower);

      final TableSchemaHiveModel? target = _pickMatchingBusinessTable(
        tables: tables,
        queryLower: lower,
        prefersSummary: prefersSummaryExplicit,
      );
      if (target == null) {
        return 'No table matched that question closely enough (try mentioning your table '
            'name). Available tables: ${_listTableNamesComma(tables)}.';
      }

      final List<Map<String, dynamic>> colsTyped = target.columns.toList(
        growable: false,
      );
      final ({String id, String label})? datePick =
          temporalFilter != null ? _pickDateColumn(colsTyped) : null;
      final ({String id, String label})? amountPick = _pickAmountColumn(
        colsTyped,
      );
      if (amountPick == null) {
        return 'The "${target.name}" table does not show a usable amount or computed total '
            'column. Add totals as number or formula fields to sum.';
      }

      if (temporalFilter != null && datePick == null) {
        return 'I couldn\'t find a suitable date column (for example Date or Created at) on '
            '"${target.name}" to filter ${_temporalUserPhrase(temporalFilter)}. '
            'Add or label a date field, then ask again.';
      }

      final String amountId = amountPick.id;

      final String tableId = target.id;
      final List<TableRowHiveModel> rows = Hive.box<TableRowHiveModel>(
            HiveBoxes.rowsBox,
          ).values
          .where((TableRowHiveModel row) => row.tableId == tableId)
          .toList(growable: false);

      if (rows.isEmpty) {
        if (temporalFilter != null) {
          final _TemporalFilter tt = temporalFilter;
          return 'No ${_entityNoun(lower)}were found ${_temporalUserPhrase(tt)} '
              'in the ${target.name} table.';
        }
        return 'The ${target.name} table has no records yet.';
      }

      final String? dateColId =
          temporalFilter != null ? datePick?.id.trim() : null;

      final List<TableSchemaEntity> allSchemas = tables
          .map(tableSchemaEntityFromHive)
          .toList(growable: false);
      final TableSchemaEntity targetSchemaEntity = tableSchemaEntityFromHive(
        target,
      );
      final Map<String, List<TableRowEntity>> rowsByTableId =
          <String, List<TableRowEntity>>{};
      for (final TableRowHiveModel r
          in Hive.box<TableRowHiveModel>(HiveBoxes.rowsBox).values) {
        rowsByTableId
            .putIfAbsent(r.tableId, () => <TableRowEntity>[])
            .add(
              TableRowEntity(id: r.id, tableId: r.tableId, values: r.values),
            );
      }

      double sum = 0;
      int counted = 0;
      int matchedDateRows = 0;
      final bool applyDateFilter =
          temporalFilter != null && dateColId != null && dateColId.isNotEmpty;

      final _TemporalFilter? tf = temporalFilter;
      for (final TableRowHiveModel rowHive in rows) {
        final Map<String, dynamic> resolved =
            TableFormulaEvaluator.resolveRowValues(
              schema: targetSchemaEntity,
              row: TableRowEntity(
                id: rowHive.id,
                tableId: rowHive.tableId,
                values: rowHive.values,
              ),
              allSchemas: allSchemas,
              rowsByTableId: rowsByTableId,
            );
        if (applyDateFilter) {
          final _TemporalFilter rng = tf!;
          final DateTime? cell = _interpretAsLocalDate(
            resolved[dateColId] ?? rowHive.values[dateColId],
            dateColumnSemantics: true,
          );
          if (cell == null) {
            continue;
          }
          if (!_calendarDayBetweenInclusive(
            cell,
            rng.startInclusive,
            rng.endInclusive,
          )) {
            continue;
          }
          matchedDateRows++;
        }
        final double? piece = _asDouble(
          resolved[amountId] ?? rowHive.values[amountId],
        );
        if (piece != null && piece.isFinite) {
          sum += piece;
          counted++;
        }
      }

      final String amt = _formatAmount(sum);

      if (applyDateFilter && matchedDateRows == 0) {
        final _TemporalFilter tt = temporalFilter;
        return 'No ${_entityNoun(lower)}were found ${_temporalUserPhrase(tt)} '
            'in the ${target.name} table.';
      }

      if (applyDateFilter && matchedDateRows > 0 && counted == 0) {
        final _TemporalFilter tt = temporalFilter;
        return 'There ${matchedDateRows == 1 ? 'is' : 'are'} $matchedDateRows '
            '${matchedDateRows == 1 ? 'record' : 'records'} ${_temporalUserPhrase(tt)} '
            'in the ${target.name} table, but no numeric total could be read from your amount '
            'column (including formula results). Check the column formula and referenced fields.';
      }

      final _TemporalFilter? tFilter = temporalFilter;
      if (tFilter != null) {
        final String subject = _totalsSentenceSubject(
          queryLower: lower,
          temporal: tFilter,
        );
        return 'Your total $subject is $amt from the ${target.name} table.';
      }
      return 'Your ${_aggregateLabel(lower)}total overall is $amt '
          'from the ${target.name} table.';
    } catch (_) {
      return null;
    }
  }

  static String _aggregateLabel(String queryLower) {
    if (queryLower.contains('transaction')) {
      return 'transaction ';
    }
    if (queryLower.contains('sales') || queryLower.contains('sale')) {
      return 'sales ';
    }
    if (queryLower.contains('order')) {
      return 'order ';
    }
    return '';
  }

  static String _listTableNamesComma(List<TableSchemaHiveModel> tables) =>
      tables.map((TableSchemaHiveModel t) => t.name.trim()).join(', ');

  static TableSchemaHiveModel? _pickMatchingBusinessTable({
    required List<TableSchemaHiveModel> tables,
    required String queryLower,
    required bool prefersSummary,
    bool prioritizeTransactionsLedger = false,
  }) {
    final Set<String> hinted = <String>{
      for (final String hint in _businessHints)
        if (queryLower.contains(hint)) hint,
    };

    TableSchemaHiveModel? best;
    int bestScore = 0;

    for (final TableSchemaHiveModel t in tables) {
      final String name = t.name.toLowerCase();
      final String condensedName = name.replaceAll(RegExp(r'[^a-z0-9]'), '');
      final String kindLower = (t.tableKind).toLowerCase();
      final bool isSummaryNamed =
          name.contains(' summary') ||
          condensedName.endsWith('summary') ||
          RegExp(r'\bsummary\b').hasMatch(name) ||
          RegExp(r'\brollup\b').hasMatch(name);
      final bool isSummaryKind =
          kindLower.contains('summary') || kindLower.contains('rollup');

      int score = 0;

      void bump(int v) => score += v;

      if (!prefersSummary && (isSummaryNamed || isSummaryKind)) {
        bump(-52);
      } else if (prefersSummary && (isSummaryNamed || isSummaryKind)) {
        bump(28);
      }

      for (final String h in hinted) {
        if (name.contains(h)) {
          bump(12 + math.min<int>(24, h.length));
        }
      }

      final List<String> nameTokens =
          RegExp('[a-z0-9]+').allMatches(name).map((m) => m.group(0)!).toList();
      final List<String> queryTokens =
          RegExp(
            '[a-z0-9]+',
          ).allMatches(queryLower).map((m) => m.group(0)!).toList();
      for (final String qt in queryTokens) {
        if (qt.length < 4 && qt != 'tax') continue;
        for (final String nt in nameTokens) {
          if (nt.startsWith(qt) || qt.startsWith(nt) || nt.contains(qt)) {
            bump(10);
            break;
          }
        }
      }

      final String condensed = queryLower.replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (condensedName.isNotEmpty && condensed.contains(condensedName)) {
        bump(20);
      }
      if (name.contains(condensed) && condensed.length >= 8) bump(22);

      final bool inferredPrimaryTokens = RegExp(
        r'\b(transactions?|sale|sales|order|payment|payments)\b',
      ).hasMatch(queryLower);
      if (!prefersSummary &&
          inferredPrimaryTokens &&
          (condensedName == 'transactions' || condensedName == 'transaction')) {
        bump(44);
      }

      if (prioritizeTransactionsLedger && !prefersSummary) {
        if (condensedName == 'transactions' || condensedName == 'transaction') {
          if (!isSummaryNamed && !isSummaryKind) {
            bump(88);
          }
        } else if (name.contains('transaction') &&
            !isSummaryNamed &&
            !isSummaryKind) {
          bump(46);
        } else if (name.contains('transaction') &&
            !condensedName.contains('summary')) {
          bump(22);
        }
      }

      if (score > bestScore) {
        bestScore = score;
        best = t;
      }
    }
    if (bestScore < 8) return null;
    return best;
  }

  static ({String id, String label})? _pickDateColumn(
    List<Map<String, dynamic>> cols,
  ) {
    TableColumnType tyOf(Map<String, dynamic> raw) =>
        TableColumnType.fromStorage((raw['type'] ?? 'text').toString());

    ({String id, String label})? best;
    int bestScore = 0;

    for (final Map<String, dynamic> raw in cols) {
      final String id = (raw['id'] ?? '').toString().trim();
      final String nm = (raw['name'] ?? '').toString().trim().toLowerCase();
      if (id.isEmpty) continue;

      int s = 0;
      final TableColumnType ty = tyOf(raw);
      if (ty == TableColumnType.date) {
        s += 56;
      }
      if (nm == 'created_at' ||
          nm.contains('created_at') ||
          nm.contains('updated_at')) {
        s += 26;
      }
      if (nm.contains('date') ||
          nm.contains('time') ||
          nm.contains('created') ||
          nm.contains('_at') ||
          nm.endsWith('at')) {
        s += 18;
      }
      if (s > bestScore) {
        bestScore = s;
        best = (id: id, label: (raw['name'] ?? '').toString().trim());
      }
    }
    return bestScore >= 14 ? best : null;
  }

  static ({String id, String label})? _pickAmountColumn(
    List<Map<String, dynamic>> cols,
  ) {
    TableColumnType tyOf(Map<String, dynamic> raw) =>
        TableColumnType.fromStorage((raw['type'] ?? 'text').toString());

    ({String id, String label})? best;
    int bestScore = 0;

    for (final Map<String, dynamic> raw in cols) {
      final String id = (raw['id'] ?? '').toString().trim();
      final String nm = (raw['name'] ?? '').toString().trim().toLowerCase();
      if (id.isEmpty) continue;

      final TableColumnType ty = tyOf(raw);
      if (ty != TableColumnType.number &&
          ty != TableColumnType.formula &&
          ty != TableColumnType.autoGenerated) {
        continue;
      }

      int s =
          ty == TableColumnType.formula
              ? 35
              : ty == TableColumnType.number ||
                  ty == TableColumnType.autoGenerated
              ? 28
              : 0;

      const List<String> high = <String>[
        'total',
        'amount',
        'subtotal',
        'grand',
        'price',
        'cost',
        'paid',
        'balance',
        'sum',
        'revenue',
        'qty',
        'quantity',
      ];
      for (final String h in high) {
        if (nm.contains(h)) {
          s += 20;
        }
      }
      if (ty == TableColumnType.formula &&
          (nm.contains('total') ||
              nm.contains('subtotal') ||
              nm.contains('amount') ||
              nm.contains('sum'))) {
        s += 24;
      }

      if (s > bestScore) {
        bestScore = s;
        best = (id: id, label: (raw['name'] ?? '').toString().trim());
      }
    }
    return bestScore >= 26 ? best : null;
  }

  static DateTime? _interpretAsLocalDate(
    dynamic v, {
    bool dateColumnSemantics = false,
  }) {
    if (v == null) return null;
    if (v is DateTime) {
      return DateTime(v.year, v.month, v.day);
    }
    if (v is int) {
      try {
        final DateTime converted =
            DateTime.fromMillisecondsSinceEpoch(v, isUtc: false).toLocal();
        return DateTime(converted.year, converted.month, converted.day);
      } catch (_) {
        return null;
      }
    }
    if (v is double && v.isFinite) {
      final double x = v;
      if (x == x.roundToDouble() && x.abs() < 1e15 && x.abs() > 1e11) {
        try {
          final DateTime converted =
              DateTime.fromMillisecondsSinceEpoch(
                x.toInt(),
                isUtc: false,
              ).toLocal();
          return DateTime(converted.year, converted.month, converted.day);
        } catch (_) {
          return null;
        }
      }
    }
    final String s = v.toString().trim();
    if (s.isEmpty) return null;

    if (dateColumnSemantics) {
      final DateTime? fromPrefix = _tryCalendarDateFromIsoPrefix(s);
      if (fromPrefix != null) {
        return fromPrefix;
      }
    }

    final DateTime? parsed =
        DateTime.tryParse(s)?.toLocal() ?? _tryYYYYMMDD(s) ?? _tryMMDDYYYY(s);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  /// Uses yyyy-MM-dd at the start of [s] as the calendar day (ignores time and Z).
  static DateTime? _tryCalendarDateFromIsoPrefix(String s) {
    final Match? m = RegExp(
      r'^(\d{4})-(\d{1,2})-(\d{1,2})',
    ).firstMatch(s.trim());
    if (m == null) return null;
    final int? y = int.tryParse(m.group(1)!);
    final int? mo = int.tryParse(m.group(2)!);
    final int? d = int.tryParse(m.group(3)!);
    if (y == null || mo == null || d == null) return null;
    try {
      return DateTime(y, mo, d);
    } catch (_) {
      return null;
    }
  }

  static DateTime? _tryYYYYMMDD(String s) {
    final Match? m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(s);
    if (m == null) return null;
    final int? y = int.tryParse(m.group(1)!);
    final int? mo = int.tryParse(m.group(2)!);
    final int? d = int.tryParse(m.group(3)!);
    if (y == null || mo == null || d == null) return null;
    return DateTime(y, mo, d);
  }

  /// US-style date stored as MM/DD/YYYY (or DD/MM when first part > 12).
  static DateTime? _tryMMDDYYYY(String s) {
    final Match? m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(s);
    if (m == null) return null;
    int? a = int.tryParse(m.group(1)!);
    int? b = int.tryParse(m.group(2)!);
    final int? y = int.tryParse(m.group(3)!);
    if (a == null || b == null || y == null) return null;
    if (a > 12 && b <= 12) {
      final int t = a;
      a = b;
      b = t;
    }
    try {
      return DateTime(y, a, b);
    } catch (_) {
      return null;
    }
  }

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    String cleaned = v.toString().trim();
    if (cleaned.isEmpty) return null;
    cleaned = cleaned.replaceAll(RegExp(r'[$€£₱]'), '');
    cleaned = cleaned.replaceAll(RegExp(r'[,\s]'), '');
    if (RegExp(r'^\([^)]+\)$').hasMatch(cleaned)) {
      cleaned = cleaned.substring(1, cleaned.length - 1).trim();
    }
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }
}
