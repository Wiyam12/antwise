import 'package:antwise/domain/entities/table_row_entity.dart';
import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/domain/entities/table_summary_config.dart';
import 'package:antwise/domain/entities/table_column_entity.dart';
import 'package:antwise/domain/formula/table_formula_evaluator.dart';

/// Builds derived rows for a summary table from live source rows (no persistence).
List<TableRowEntity> computeSummaryTableRows({
  required TableSchemaEntity summarySchema,
  required List<TableSchemaEntity> allSchemas,
  required Map<String, List<TableRowEntity>> rowsByTableId,
}) {
  final TableSummaryConfig? cfg = summarySchema.summaryConfig;
  if (cfg == null || summarySchema.columns.isEmpty) {
    return <TableRowEntity>[];
  }
  if (cfg.columns.isEmpty) {
    return _computeLegacySummaryRows(
      summarySchema: summarySchema,
      cfg: cfg,
      allSchemas: allSchemas,
      rowsByTableId: rowsByTableId,
    );
  }

  final SummaryColumnConfig seedColumn = cfg.columns.firstWhere(
    (SummaryColumnConfig c) => c.groupBy,
    orElse: () => cfg.columns.first,
  );
  final String? seedTableId = seedColumn.sourceTableId;
  if (seedTableId == null || seedTableId.isEmpty) {
    return <TableRowEntity>[];
  }
  final List<TableRowEntity> seedRows = rowsByTableId[seedTableId] ?? const <TableRowEntity>[];
  if (seedRows.isEmpty) {
    return <TableRowEntity>[];
  }
  final TableSchemaEntity? seedSchema = _schemaById(allSchemas, seedTableId);
  if (seedSchema == null) {
    return <TableRowEntity>[];
  }
  final List<_ResolvedSeedRow> resolvedSeedRows = seedRows
      .map(
        (TableRowEntity row) => _ResolvedSeedRow(
          row: row,
          resolved: TableFormulaEvaluator.resolveRowValues(
            schema: seedSchema,
            row: row,
            allSchemas: allSchemas,
            rowsByTableId: rowsByTableId,
          ),
        ),
      )
      .toList(growable: false);

  final List<SummaryColumnConfig> groupColumns = cfg.columns
      .where((SummaryColumnConfig c) => c.groupBy)
      .toList(growable: false);
  if (groupColumns.isEmpty) {
    groupColumns.add(seedColumn);
  }

  final Map<String, List<_ResolvedSeedRow>> grouped = <String, List<_ResolvedSeedRow>>{};
  for (final _ResolvedSeedRow row in resolvedSeedRows) {
    final List<String> parts = <String>[];
    for (final SummaryColumnConfig gc in groupColumns) {
      parts.add(_resolvedCellValue(row, gc.sourceColumnId));
    }
    final String key = parts.join('||');
    grouped.putIfAbsent(key, () => <_ResolvedSeedRow>[]).add(row);
  }

  final List<String> keys = grouped.keys.toList()..sort();
  final Map<String, SummaryColumnConfig> configById = <String, SummaryColumnConfig>{
    for (final SummaryColumnConfig column in cfg.columns) column.id: column,
  };

  return List<TableRowEntity>.generate(keys.length, (int i) {
    final List<_ResolvedSeedRow> groupRows = grouped[keys[i]] ?? const <_ResolvedSeedRow>[];
    final Map<String, dynamic> values = <String, dynamic>{};
    for (final TableColumnEntity outCol in summarySchema.columns) {
      final SummaryColumnConfig? colCfg = configById[outCol.id];
      if (colCfg == null) {
        values[outCol.id] = '';
        continue;
      }
      values[outCol.id] = _resolveColumnValue(
        config: colCfg,
        groupRows: groupRows,
        rowsByTableId: rowsByTableId,
      );
    }
    return TableRowEntity(
      id: '${summarySchema.id}_sum_$i',
      tableId: summarySchema.id,
      values: values,
    );
  });
}

List<TableRowEntity> _computeLegacySummaryRows({
  required TableSchemaEntity summarySchema,
  required TableSummaryConfig cfg,
  required List<TableSchemaEntity> allSchemas,
  required Map<String, List<TableRowEntity>> rowsByTableId,
}) {
  final List<TableRowEntity> sourceRows = rowsByTableId[cfg.sourceTableId] ?? const <TableRowEntity>[];
  if (summarySchema.columns.length < 2 || sourceRows.isEmpty) {
    return <TableRowEntity>[];
  }
  final TableSchemaEntity? sourceSchema = _schemaById(allSchemas, cfg.sourceTableId);
  if (sourceSchema == null) {
    return <TableRowEntity>[];
  }
  final Map<String, double> sums = <String, double>{};
  for (final TableRowEntity row in sourceRows) {
    final Map<String, dynamic> resolved = TableFormulaEvaluator.resolveRowValues(
      schema: sourceSchema,
      row: row,
      allSchemas: allSchemas,
      rowsByTableId: rowsByTableId,
    );
    final String keyStr =
        (resolved[cfg.groupByColumnId] ?? row.values[cfg.groupByColumnId] ?? '')
            .toString()
            .trim();
    if (keyStr.isEmpty) {
      continue;
    }
    final double addend =
        double.tryParse(
          (resolved[cfg.aggregateSourceColumnId] ??
                  row.values[cfg.aggregateSourceColumnId] ??
                  '')
              .toString()
              .trim(),
        ) ??
        0;
    sums[keyStr] = (sums[keyStr] ?? 0) + addend;
  }
  final List<String> keys = sums.keys.toList()..sort();
  final String colGroupId = summarySchema.columns[0].id;
  final String colTotalId = summarySchema.columns[1].id;
  return List<TableRowEntity>.generate(keys.length, (int i) {
    final String k = keys[i];
    final double total = sums[k]!;
    return TableRowEntity(
      id: '${summarySchema.id}_sum_$i',
      tableId: summarySchema.id,
      values: <String, dynamic>{colGroupId: k, colTotalId: _formatTotal(total)},
    );
  });
}

String _resolveColumnValue({
  required SummaryColumnConfig config,
  required List<_ResolvedSeedRow> groupRows,
  required Map<String, List<TableRowEntity>> rowsByTableId,
}) {
  if (groupRows.isEmpty) {
    return '';
  }
  final String? sourceColumnId = config.sourceColumnId;
  if (sourceColumnId == null || sourceColumnId.isEmpty) {
    return '';
  }
  switch (config.valueMode) {
    case SummaryValueMode.groupedValue:
    case SummaryValueMode.uniqueValue:
      for (final _ResolvedSeedRow row in groupRows) {
        final String v = _resolvedCellValue(row, sourceColumnId);
        if (v.trim().isNotEmpty) {
          return v;
        }
      }
      return '';
    case SummaryValueMode.aggregation:
      return _aggregate(
        rows: groupRows,
        sourceColumnId: sourceColumnId,
        operation: config.aggregation,
      );
    case SummaryValueMode.formula:
      // Formula expressions are persisted and can be expanded later.
      return config.formula?.trim() ?? '';
  }
}

String _aggregate({
  required List<_ResolvedSeedRow> rows,
  required String sourceColumnId,
  required SummaryAggregationOperation operation,
}) {
  final List<double> numbers = rows
      .map(
        (_ResolvedSeedRow row) =>
            double.tryParse(_resolvedCellValue(row, sourceColumnId).trim()) ?? 0,
      )
      .toList(growable: false);
  if (operation == SummaryAggregationOperation.count) {
    return rows.length.toString();
  }
  if (numbers.isEmpty) {
    return '0';
  }
  final double sum = numbers.fold<double>(0, (double a, double b) => a + b);
  switch (operation) {
    case SummaryAggregationOperation.sum:
      return _formatTotal(sum);
    case SummaryAggregationOperation.avg:
      return _formatTotal(sum / numbers.length);
    case SummaryAggregationOperation.min:
      return _formatTotal(numbers.reduce((double a, double b) => a < b ? a : b));
    case SummaryAggregationOperation.max:
      return _formatTotal(numbers.reduce((double a, double b) => a > b ? a : b));
    case SummaryAggregationOperation.count:
      return rows.length.toString();
  }
}

String _formatTotal(double v) {
  if (v == v.roundToDouble()) {
    return v.round().toString();
  }
  return v.toString();
}

TableSchemaEntity? _schemaById(List<TableSchemaEntity> schemas, String id) {
  for (final TableSchemaEntity schema in schemas) {
    if (schema.id == id) {
      return schema;
    }
  }
  return null;
}

String _resolvedCellValue(_ResolvedSeedRow row, String? sourceColumnId) {
  if (sourceColumnId == null || sourceColumnId.isEmpty) {
    return '';
  }
  return (row.resolved[sourceColumnId] ?? row.row.values[sourceColumnId] ?? '')
      .toString();
}

class _ResolvedSeedRow {
  const _ResolvedSeedRow({required this.row, required this.resolved});

  final TableRowEntity row;
  final Map<String, dynamic> resolved;
}
