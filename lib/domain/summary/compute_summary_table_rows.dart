import 'package:antwise/domain/entities/table_row_entity.dart';
import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/domain/entities/table_summary_config.dart';

/// Builds derived rows for a summary table from live source rows (no persistence).
List<TableRowEntity> computeSummaryTableRows({
  required TableSchemaEntity summarySchema,
  required TableSchemaEntity sourceSchema,
  required List<TableRowEntity> sourceRows,
}) {
  final TableSummaryConfig? cfg = summarySchema.summaryConfig;
  if (cfg == null ||
      summarySchema.columns.length < 2 ||
      cfg.sourceTableId != sourceSchema.id) {
    return <TableRowEntity>[];
  }

  final String groupColSource = cfg.groupByColumnId;
  final String valueColSource = cfg.aggregateSourceColumnId;

  final Map<String, double> sums = <String, double>{};
  for (final TableRowEntity row in sourceRows) {
    final dynamic rawKey = row.values[groupColSource];
    final String keyStr = rawKey?.toString().trim() ?? '';
    if (keyStr.isEmpty) {
      continue;
    }
    final double addend =
        double.tryParse(row.values[valueColSource]?.toString().trim() ?? '') ??
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
      values: <String, dynamic>{
        colGroupId: k,
        colTotalId: _formatTotal(total),
      },
    );
  });
}

String _formatTotal(double v) {
  if (v == v.roundToDouble()) {
    return v.round().toString();
  }
  return v.toString();
}
