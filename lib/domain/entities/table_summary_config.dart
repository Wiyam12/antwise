/// Configuration for a [TableKind.summary] table: group-by + aggregation on a source table.
class TableSummaryConfig {
  const TableSummaryConfig({
    required this.sourceTableId,
    required this.groupByColumnId,
    required this.aggregateSourceColumnId,
    this.operation = SummaryAggregationOperation.sum,
  });

  final String sourceTableId;
  final String groupByColumnId;
  final String aggregateSourceColumnId;
  final SummaryAggregationOperation operation;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'sourceTableId': sourceTableId,
    'groupByColumnId': groupByColumnId,
    'aggregateSourceColumnId': aggregateSourceColumnId,
    'operation': operation.name,
  };

  static TableSummaryConfig? tryFromJson(dynamic raw) {
    if (raw is! Map) {
      return null;
    }
    final Map<String, dynamic> m = raw.cast<String, dynamic>();
    final String? sid = m['sourceTableId']?.toString();
    final String? gid = m['groupByColumnId']?.toString();
    final String? aid = m['aggregateSourceColumnId']?.toString();
    if (sid == null ||
        sid.isEmpty ||
        gid == null ||
        gid.isEmpty ||
        aid == null ||
        aid.isEmpty) {
      return null;
    }
    final SummaryAggregationOperation op = switch (m['operation']?.toString()) {
      'sum' => SummaryAggregationOperation.sum,
      _ => SummaryAggregationOperation.sum,
    };
    return TableSummaryConfig(
      sourceTableId: sid,
      groupByColumnId: gid,
      aggregateSourceColumnId: aid,
      operation: op,
    );
  }
}

enum SummaryAggregationOperation {
  sum,
}
