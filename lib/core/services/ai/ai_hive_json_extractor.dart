import 'dart:convert';
import 'dart:math' as math;

import 'package:antwise/core/services/ai/ai_formula_processor.dart';
import 'package:antwise/core/storage/hive_boxes.dart';
import 'package:antwise/data/mappers/table_schema_entity_from_hive.dart';
import 'package:antwise/data/models/hive/table_row_hive_model.dart';
import 'package:antwise/data/models/hive/table_schema_hive_model.dart';
import 'package:antwise/domain/entities/table_column_entity.dart';
import 'package:antwise/domain/entities/table_column_type.dart';
import 'package:antwise/domain/entities/table_row_entity.dart';
import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:hive/hive.dart';

/// Compact, formula-resolved workspace snapshot for AI prompts.
final class AiHiveContextPayload {
  const AiHiveContextPayload({
    required this.jsonBlock,
    required this.tableNames,
    required this.rowCountByTableName,
    required this.computedFormulaFields,
    required this.isEmpty,
  });

  final String jsonBlock;
  final List<String> tableNames;

  /// Lowercase table name → total row count in Hive.
  final Map<String, int> rowCountByTableName;
  final List<String> computedFormulaFields;
  final bool isEmpty;
}

/// Builds processed Hive JSON (computed values only) for the active workspace.
abstract final class AiHiveJsonExtractor {
  static const int _maxTables = 10;
  static const int _maxRowsPerTable = 35;
  static const int _maxJsonChars = 7200;

  static AiHiveContextPayload build({AiFormulaProcessor? processor}) {
    final AiFormulaProcessor formulaProcessor = processor ?? AiFormulaProcessor();
    try {
      if (!Hive.isBoxOpen(HiveBoxes.tablesBox) ||
          !Hive.isBoxOpen(HiveBoxes.rowsBox)) {
        return const AiHiveContextPayload(
          jsonBlock: '',
          tableNames: <String>[],
          rowCountByTableName: <String, int>{},
          computedFormulaFields: <String>[],
          isEmpty: true,
        );
      }

      final List<TableSchemaHiveModel> hiveTables =
          Hive.box<TableSchemaHiveModel>(HiveBoxes.tablesBox).values
              .where((TableSchemaHiveModel t) => t.name.trim().isNotEmpty)
              .toList(growable: false)
            ..sort(
              (TableSchemaHiveModel a, TableSchemaHiveModel b) =>
                  a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );

      if (hiveTables.isEmpty) {
        return const AiHiveContextPayload(
          jsonBlock: '',
          tableNames: <String>[],
          rowCountByTableName: <String, int>{},
          computedFormulaFields: <String>[],
          isEmpty: true,
        );
      }

      final List<TableSchemaEntity> allSchemas = hiveTables
          .map(tableSchemaEntityFromHive)
          .toList(growable: false);

      final Map<String, List<TableRowEntity>> rowsByTableId =
          <String, List<TableRowEntity>>{};
      for (final TableRowHiveModel row
          in Hive.box<TableRowHiveModel>(HiveBoxes.rowsBox).values) {
        rowsByTableId
            .putIfAbsent(row.tableId, () => <TableRowEntity>[])
            .add(
              TableRowEntity(id: row.id, tableId: row.tableId, values: row.values),
            );
      }

      final Set<String> computedFieldNames = <String>{};
      final List<String> injectedTableNames = <String>[];
      final Map<String, int> rowCountByTableName = <String, int>{};
      final List<Map<String, dynamic>> tablesPayload = <Map<String, dynamic>>[];

      final int tableLimit =
          hiveTables.length > _maxTables ? _maxTables : hiveTables.length;

      for (int i = 0; i < tableLimit; i++) {
        final TableSchemaHiveModel hiveTable = hiveTables[i];
        final TableSchemaEntity schema = tableSchemaEntityFromHive(hiveTable);
        final String tableName = hiveTable.name.trim();
        injectedTableNames.add(tableName);
        computedFieldNames.addAll(
          AiFormulaProcessor.formulaColumnLabels(schema),
        );

        final Map<String, String> columnIdToName = <String, String>{
          for (final TableColumnEntity col in schema.columns)
            col.id: col.name.trim().isEmpty ? col.id : col.name.trim(),
        };

        final List<Map<String, dynamic>> columnMeta = schema.columns
            .map((TableColumnEntity col) {
              return <String, dynamic>{
                'name': col.name.trim(),
                'type': col.type.storageValue,
              };
            })
            .toList(growable: false);

        final List<TableRowHiveModel> tableRows =
            Hive.box<TableRowHiveModel>(HiveBoxes.rowsBox).values
                .where((TableRowHiveModel r) => r.tableId == hiveTable.id)
                .toList(growable: false);

        rowCountByTableName[tableName.toLowerCase()] = tableRows.length;

        final int rowLimit = tableRows.length > _maxRowsPerTable
            ? _maxRowsPerTable
            : tableRows.length;

        final List<Map<String, dynamic>> records = <Map<String, dynamic>>[];
        for (int r = 0; r < rowLimit; r++) {
          final TableRowHiveModel rowHive = tableRows[r];
          final Map<String, dynamic> resolved =
              formulaProcessor.resolveRowValues(
            schema: schema,
            row: TableRowEntity(
              id: rowHive.id,
              tableId: rowHive.tableId,
              values: rowHive.values,
            ),
            allSchemas: allSchemas,
            rowsByTableId: rowsByTableId,
          );

          final Map<String, dynamic> record = <String, dynamic>{};
          for (final MapEntry<String, dynamic> entry in resolved.entries) {
            final String? label = columnIdToName[entry.key];
            if (label == null || label.isEmpty) {
              continue;
            }
            final TableColumnEntity? col = _columnById(schema, entry.key);
            if (col != null &&
                (col.type == TableColumnType.image ||
                    col.type == TableColumnType.file)) {
              continue;
            }
            record[label] = _serializeCellValue(entry.value);
          }
          if (record.isNotEmpty) {
            records.add(record);
          }
        }

        tablesPayload.add(<String, dynamic>{
          'name': tableName,
          'table_kind': hiveTable.tableKind,
          'row_count': tableRows.length,
          'columns': columnMeta,
          'records': records,
          if (tableRows.length > rowLimit)
            'records_truncated': tableRows.length - rowLimit,
        });
      }

      if (hiveTables.length > _maxTables) {
        tablesPayload.add(<String, dynamic>{
          'note': '${hiveTables.length - _maxTables} more table(s) omitted',
        });
      }

      final Map<String, dynamic> root = <String, dynamic>{
        'workspace_tables': tablesPayload,
      };

      String jsonBlock = const JsonEncoder.withIndent('  ').convert(root);
      if (jsonBlock.length > _maxJsonChars) {
        root['workspace_tables'] = tablesPayload
            .take(math.min(6, tablesPayload.length))
            .toList();
        jsonBlock = const JsonEncoder.withIndent('  ').convert(root);
        if (jsonBlock.length > _maxJsonChars) {
          jsonBlock =
              '${jsonBlock.substring(0, _maxJsonChars)}\n… (JSON truncated for model limits)';
        }
      }

      return AiHiveContextPayload(
        jsonBlock: jsonBlock,
        tableNames: injectedTableNames,
        rowCountByTableName: rowCountByTableName,
        computedFormulaFields: computedFieldNames.toList()..sort(),
        isEmpty: false,
      );
    } catch (_) {
      return const AiHiveContextPayload(
        jsonBlock: '',
        tableNames: <String>[],
        rowCountByTableName: <String, int>{},
        computedFormulaFields: <String>[],
        isEmpty: true,
      );
    }
  }

  static TableColumnEntity? _columnById(TableSchemaEntity schema, String id) {
    for (final TableColumnEntity col in schema.columns) {
      if (col.id == id) {
        return col;
      }
    }
    return null;
  }

  static dynamic _serializeCellValue(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is num || value is bool || value is String) {
      return value;
    }
    if (value is Map || value is List) {
      return value.toString();
    }
    return value.toString();
  }
}
