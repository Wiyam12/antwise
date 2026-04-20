import 'package:antwise/domain/repositories/table_schema_repository.dart';

class DeleteTableSchemaUseCase {
  DeleteTableSchemaUseCase(this._repository);

  final TableSchemaRepository _repository;

  Future<void> call(String tableId) => _repository.delete(tableId);
}
