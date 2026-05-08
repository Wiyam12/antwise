import 'dart:convert';

import 'package:antwise/core/storage/hive_boxes.dart';
import 'package:antwise/data/models/hive/table_row_hive_model.dart';
import 'package:antwise/data/models/hive/table_schema_hive_model.dart';
import 'package:hive/hive.dart';

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
}
