import 'package:antwise/domain/entities/table_row_entity.dart';

abstract class TableRowRepository {
  Future<List<TableRowEntity>> getAll();

  Future<List<TableRowEntity>> getByTableId(String tableId);

  Future<void> save(TableRowEntity row);

  Future<void> update(TableRowEntity row);

  Future<void> delete(String rowId);

  Future<void> deleteByTableId(String tableId);
}
