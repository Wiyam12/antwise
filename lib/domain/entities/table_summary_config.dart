/// Configuration for a [TableKind.summary] table.
class TableSummaryConfig {
  const TableSummaryConfig({
    required this.sourceTableId,
    required this.groupByColumnId,
    required this.aggregateSourceColumnId,
    this.operation = SummaryAggregationOperation.sum,
    this.columns = const <SummaryColumnConfig>[],
  });

  final String sourceTableId;
  final String groupByColumnId;
  final String aggregateSourceColumnId;
  final SummaryAggregationOperation operation;
  final List<SummaryColumnConfig> columns;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'sourceTableId': sourceTableId,
    'groupByColumnId': groupByColumnId,
    'aggregateSourceColumnId': aggregateSourceColumnId,
    'operation': operation.name,
    'columns': columns.map((SummaryColumnConfig c) => c.toJson()).toList(),
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
    final List<SummaryColumnConfig> columns = <SummaryColumnConfig>[];
    final dynamic rawColumns = m['columns'];
    if (rawColumns is List) {
      for (final dynamic item in rawColumns) {
        final SummaryColumnConfig? parsed = SummaryColumnConfig.tryFromJson(
          item,
        );
        if (parsed != null) {
          columns.add(parsed);
        }
      }
    }

    return TableSummaryConfig(
      sourceTableId: sid,
      groupByColumnId: gid,
      aggregateSourceColumnId: aid,
      operation: op,
      columns: columns,
    );
  }
}

enum SummaryAggregationOperation {
  sum,
  count,
  avg,
  min,
  max,
}

enum SummaryValueMode {
  groupedValue,
  uniqueValue,
  aggregation,
  formula,
}

class SummaryColumnConfig {
  const SummaryColumnConfig({
    required this.id,
    required this.name,
    this.sourceTableId,
    this.sourceColumnId,
    this.groupBy = false,
    this.valueMode = SummaryValueMode.uniqueValue,
    this.aggregation = SummaryAggregationOperation.sum,
    this.formula,
  });

  final String id;
  final String name;
  final String? sourceTableId;
  final String? sourceColumnId;
  final bool groupBy;
  final SummaryValueMode valueMode;
  final SummaryAggregationOperation aggregation;
  final String? formula;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'sourceTableId': sourceTableId,
    'sourceColumnId': sourceColumnId,
    'groupBy': groupBy,
    'valueMode': valueMode.name,
    'aggregation': aggregation.name,
    'formula': formula,
  };

  static SummaryColumnConfig? tryFromJson(dynamic raw) {
    if (raw is! Map) {
      return null;
    }
    final Map<String, dynamic> m = raw.cast<String, dynamic>();
    final String? id = m['id']?.toString();
    final String? name = m['name']?.toString();
    if (id == null || id.isEmpty || name == null || name.isEmpty) {
      return null;
    }
    final SummaryValueMode valueMode = switch (m['valueMode']?.toString()) {
      'groupedValue' => SummaryValueMode.groupedValue,
      'uniqueValue' => SummaryValueMode.uniqueValue,
      'aggregation' => SummaryValueMode.aggregation,
      'formula' => SummaryValueMode.formula,
      _ => SummaryValueMode.uniqueValue,
    };
    final SummaryAggregationOperation aggregation = switch (m['aggregation']
        ?.toString()) {
      'count' => SummaryAggregationOperation.count,
      'avg' => SummaryAggregationOperation.avg,
      'min' => SummaryAggregationOperation.min,
      'max' => SummaryAggregationOperation.max,
      'sum' => SummaryAggregationOperation.sum,
      _ => SummaryAggregationOperation.sum,
    };
    return SummaryColumnConfig(
      id: id,
      name: name,
      sourceTableId: m['sourceTableId']?.toString(),
      sourceColumnId: m['sourceColumnId']?.toString(),
      groupBy: m['groupBy'] == true,
      valueMode: valueMode,
      aggregation: aggregation,
      formula: m['formula']?.toString(),
    );
  }
}
