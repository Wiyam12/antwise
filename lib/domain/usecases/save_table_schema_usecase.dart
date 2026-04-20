import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/domain/repositories/table_schema_repository.dart';

class SaveTableSchemaUseCase {
  SaveTableSchemaUseCase(this._repository);

  final TableSchemaRepository _repository;

  Future<void> call(TableSchemaEntity schema) => _repository.save(schema);
}
