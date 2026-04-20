import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/domain/repositories/table_schema_repository.dart';

class GetAllTableSchemasUseCase {
  GetAllTableSchemasUseCase(this._repository);

  final TableSchemaRepository _repository;

  Future<List<TableSchemaEntity>> call() => _repository.getAll();
}
