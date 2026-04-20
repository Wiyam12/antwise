class TableRowEntity {
  const TableRowEntity({
    required this.id,
    required this.tableId,
    required this.values,
  });

  final String id;
  final String tableId;
  final Map<String, dynamic> values;
}
