import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/domain/repositories/table_schema_repository.dart';

class GetTableSchemaByIdUseCase {
  GetTableSchemaByIdUseCase(this._repository);

  final TableSchemaRepository _repository;

  Future<TableSchemaEntity?> call(String tableId) => _repository.getById(tableId);
}
