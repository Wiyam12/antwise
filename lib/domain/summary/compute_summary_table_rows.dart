import 'package:antwise/domain/entities/table_row_entity.dart';
import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/domain/entities/table_summary_config.dart';
import 'package:antwise/domain/entities/table_column_entity.dart';

/// Builds derived rows for a summary table from live source rows (no persistence).
List<TableRowEntity> computeSummaryTableRows({
  required TableSchemaEntity summarySchema,
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

  final List<SummaryColumnConfig> groupColumns = cfg.columns
      .where((SummaryColumnConfig c) => c.groupBy)
      .toList(growable: false);
  if (groupColumns.isEmpty) {
    groupColumns.add(seedColumn);
  }

  final Map<String, List<TableRowEntity>> grouped = <String, List<TableRowEntity>>{};
  for (final TableRowEntity row in seedRows) {
    final List<String> parts = <String>[];
    for (final SummaryColumnConfig gc in groupColumns) {
      parts.add((row.values[gc.sourceColumnId] ?? '').toString());
    }
    final String key = parts.join('||');
    grouped.putIfAbsent(key, () => <TableRowEntity>[]).add(row);
  }

  final List<String> keys = grouped.keys.toList()..sort();
  final Map<String, SummaryColumnConfig> configById = <String, SummaryColumnConfig>{
    for (final SummaryColumnConfig column in cfg.columns) column.id: column,
  };

  return List<TableRowEntity>.generate(keys.length, (int i) {
    final List<TableRowEntity> groupRows = grouped[keys[i]] ?? const <TableRowEntity>[];
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
  required Map<String, List<TableRowEntity>> rowsByTableId,
}) {
  final List<TableRowEntity> sourceRows = rowsByTableId[cfg.sourceTableId] ?? const <TableRowEntity>[];
  if (summarySchema.columns.length < 2 || sourceRows.isEmpty) {
    return <TableRowEntity>[];
  }
  final Map<String, double> sums = <String, double>{};
  for (final TableRowEntity row in sourceRows) {
    final String keyStr = (row.values[cfg.groupByColumnId] ?? '').toString().trim();
    if (keyStr.isEmpty) {
      continue;
    }
    final double addend =
        double.tryParse(row.values[cfg.aggregateSourceColumnId]?.toString().trim() ?? '') ?? 0;
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
  required List<TableRowEntity> groupRows,
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
      for (final TableRowEntity row in groupRows) {
        final String v = (row.values[sourceColumnId] ?? '').toString();
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
  required List<TableRowEntity> rows,
  required String sourceColumnId,
  required SummaryAggregationOperation operation,
}) {
  final List<double> numbers = rows
      .map((TableRowEntity row) => double.tryParse((row.values[sourceColumnId] ?? '').toString()) ?? 0)
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
