import 'package:antwise/core/storage/hive_boxes.dart';
import 'package:antwise/core/storage/hive_service.dart';
import 'package:antwise/data/models/hive/table_schema_hive_model.dart';

abstract class TableSchemaLocalDataSource {
  Future<List<TableSchemaHiveModel>> readAll();

  Future<void> write(TableSchemaHiveModel schema);

  Future<void> delete(String tableId);
}

class TableSchemaLocalDataSourceImpl implements TableSchemaLocalDataSource {
  TableSchemaLocalDataSourceImpl(this._hiveService);

  final HiveService _hiveService;

  @override
  Future<List<TableSchemaHiveModel>> readAll() async {
    return _hiveService
        .box<TableSchemaHiveModel>(HiveBoxes.tablesBox)
        .values
        .toList(growable: false);
  }

  @override
  Future<void> write(TableSchemaHiveModel schema) async {
    await _hiveService
        .box<TableSchemaHiveModel>(HiveBoxes.tablesBox)
        .put(schema.id, schema);
  }

  @override
  Future<void> delete(String tableId) async {
    await _hiveService.box<TableSchemaHiveModel>(HiveBoxes.tablesBox).delete(tableId);
  }
}
