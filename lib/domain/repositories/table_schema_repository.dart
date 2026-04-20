import 'package:antwise/domain/entities/table_schema_entity.dart';

abstract class TableSchemaRepository {
  Future<List<TableSchemaEntity>> getAll();

  Future<TableSchemaEntity?> getById(String tableId);

  Future<TableSchemaEntity?> getByPageId(String pageId);

  Future<void> save(TableSchemaEntity schema);

  Future<void> delete(String tableId);
}
