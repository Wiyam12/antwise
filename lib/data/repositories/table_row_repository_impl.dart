import 'package:antwise/data/datasources/table_row_local_datasource.dart';
import 'package:antwise/data/models/hive/table_row_hive_model.dart';
import 'package:antwise/domain/entities/table_row_entity.dart';
import 'package:antwise/domain/repositories/table_row_repository.dart';

class TableRowRepositoryImpl implements TableRowRepository {
  TableRowRepositoryImpl(this._local);

  final TableRowLocalDataSource _local;

  @override
  Future<List<TableRowEntity>> getAll() async {
    final List<TableRowHiveModel> all = await _local.readAll();
    return all
        .map(
          (TableRowHiveModel row) => TableRowEntity(
            id: row.id,
            tableId: row.tableId,
            values: row.values,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<TableRowEntity>> getByTableId(String tableId) async {
    return (await getAll())
        .where((TableRowEntity row) => row.tableId == tableId)
        .toList(growable: false);
  }

  @override
  Future<void> save(TableRowEntity row) async {
    await _local.write(
      TableRowHiveModel(id: row.id, tableId: row.tableId, values: row.values),
    );
  }

  @override
  Future<void> update(TableRowEntity row) async {
    await save(row);
  }

  @override
  Future<void> delete(String rowId) async {
    await _local.delete(rowId);
  }

  @override
  Future<void> deleteByTableId(String tableId) async {
    final List<TableRowHiveModel> all = await _local.readAll();
    final Iterable<String> rowIds = all
        .where((TableRowHiveModel row) => row.tableId == tableId)
        .map((TableRowHiveModel row) => row.id);
    await _local.deleteMany(rowIds);
  }
}
