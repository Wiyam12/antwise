/// When set on a [TableSchemaEntity], creating a new row in that table will
/// decrement a numeric stock column on another table for the matched product row.
class TableInventoryDeductionConfig {
  const TableInventoryDeductionConfig({
    required this.stockTableId,
    required this.stockMatchColumnId,
    required this.stockQuantityColumnId,
    required this.lineProductColumnId,
    required this.lineQuantityColumnId,
  });

  /// Table that holds inventory (e.g. Products).
  final String stockTableId;

  /// Column on [stockTableId] compared to the line's product value (e.g. product name).
  final String stockMatchColumnId;

  /// Numeric column on [stockTableId] to subtract quantity from (e.g. Stock).
  final String stockQuantityColumnId;

  /// Column on the **line** table whose value matches [stockMatchColumnId].
  final String lineProductColumnId;

  /// Column on the **line** table with quantity sold / used (number).
  final String lineQuantityColumnId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'stockTableId': stockTableId,
        'stockMatchColumnId': stockMatchColumnId,
        'stockQuantityColumnId': stockQuantityColumnId,
        'lineProductColumnId': lineProductColumnId,
        'lineQuantityColumnId': lineQuantityColumnId,
      };

  static TableInventoryDeductionConfig? tryFromJson(dynamic raw) {
    if (raw is! Map) {
      return null;
    }
    final Map<String, dynamic> m = raw.cast<String, dynamic>();
    final String? st = m['stockTableId']?.toString();
    final String? sm = m['stockMatchColumnId']?.toString();
    final String? sq = m['stockQuantityColumnId']?.toString();
    final String? lp = m['lineProductColumnId']?.toString();
    final String? lq = m['lineQuantityColumnId']?.toString();
    if (st == null ||
        st.isEmpty ||
        sm == null ||
        sm.isEmpty ||
        sq == null ||
        sq.isEmpty ||
        lp == null ||
        lp.isEmpty ||
        lq == null ||
        lq.isEmpty) {
      return null;
    }
    return TableInventoryDeductionConfig(
      stockTableId: st,
      stockMatchColumnId: sm,
      stockQuantityColumnId: sq,
      lineProductColumnId: lp,
      lineQuantityColumnId: lq,
    );
  }
}
