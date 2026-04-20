import 'package:antwise/domain/entities/table_column_type.dart';
import 'package:antwise/domain/entities/table_inventory_deduction_config.dart';
import 'package:antwise/domain/entities/table_row_entity.dart';
import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/domain/repositories/table_row_repository.dart';

/// After a **new** line row is saved, optionally decrements stock on a product table.
class ApplyInventoryDeductionUseCase {
  ApplyInventoryDeductionUseCase(this._rowRepository);

  final TableRowRepository _rowRepository;

  Future<void> call({
    required TableInventoryDeductionConfig? config,
    required List<TableSchemaEntity> allSchemas,
    required Map<String, dynamic> lineValues,
  }) async {
    if (config == null) {
      return;
    }
    final String productKey =
        lineValues[config.lineProductColumnId]?.toString().trim() ?? '';
    if (productKey.isEmpty) {
      return;
    }
    final double qty = double.tryParse(
          lineValues[config.lineQuantityColumnId]?.toString().trim() ?? '',
        ) ??
        0;
    if (qty <= 0) {
      return;
    }

    TableSchemaEntity? stockSchema;
    for (final TableSchemaEntity s in allSchemas) {
      if (s.id == config.stockTableId) {
        stockSchema = s;
        break;
      }
    }
    if (stockSchema == null) {
      return;
    }

    bool hasMatchCol = false;
    bool hasQtyCol = false;
    for (final c in stockSchema.columns) {
      if (c.id == config.stockMatchColumnId) {
        hasMatchCol = true;
      }
      if (c.id == config.stockQuantityColumnId &&
          (c.type == TableColumnType.number ||
              c.type == TableColumnType.currency)) {
        hasQtyCol = true;
      }
    }
    if (!hasMatchCol || !hasQtyCol) {
      return;
    }

    final List<TableRowEntity> stockRows =
        await _rowRepository.getByTableId(config.stockTableId);
    for (final TableRowEntity r in stockRows) {
      final String matchCell =
          r.values[config.stockMatchColumnId]?.toString().trim() ?? '';
      if (matchCell != productKey) {
        continue;
      }
      final String rawStock =
          r.values[config.stockQuantityColumnId]?.toString().trim() ?? '';
      final double current = double.tryParse(rawStock) ?? 0;
      final double next = (current - qty).clamp(0, double.infinity).toDouble();
      final Map<String, dynamic> newValues =
          Map<String, dynamic>.from(r.values);
      newValues[config.stockQuantityColumnId] =
          next == next.roundToDouble() && next <= 9007199254740992
              ? next.round()
              : next;
      await _rowRepository.update(
        TableRowEntity(id: r.id, tableId: r.tableId, values: newValues),
      );
      return;
    }
  }
}
