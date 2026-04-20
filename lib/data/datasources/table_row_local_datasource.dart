import 'package:antwise/core/storage/hive_boxes.dart';
import 'package:antwise/core/storage/hive_service.dart';
import 'package:antwise/data/models/hive/table_row_hive_model.dart';

abstract class TableRowLocalDataSource {
  Future<List<TableRowHiveModel>> readAll();

  Future<void> write(TableRowHiveModel row);

  Future<void> delete(String rowId);

  Future<void> deleteMany(Iterable<String> rowIds);
}

class TableRowLocalDataSourceImpl implements TableRowLocalDataSource {
  TableRowLocalDataSourceImpl(this._hiveService);

  final HiveService _hiveService;

  @override
  Future<List<TableRowHiveModel>> readAll() async {
    return _hiveService
        .box<TableRowHiveModel>(HiveBoxes.rowsBox)
        .values
        .toList(growable: false);
  }

  @override
  Future<void> write(TableRowHiveModel row) async {
    await _hiveService.box<TableRowHiveModel>(HiveBoxes.rowsBox).put(row.id, row);
  }

  @override
  Future<void> delete(String rowId) async {
    await _hiveService.box<TableRowHiveModel>(HiveBoxes.rowsBox).delete(rowId);
  }

  @override
  Future<void> deleteMany(Iterable<String> rowIds) async {
    await _hiveService.box<TableRowHiveModel>(HiveBoxes.rowsBox).deleteAll(rowIds);
  }
}
