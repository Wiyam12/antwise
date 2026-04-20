import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/domain/repositories/table_schema_repository.dart';

class GetTableSchemaByPageUseCase {
  GetTableSchemaByPageUseCase(this._repository);

  final TableSchemaRepository _repository;

  Future<TableSchemaEntity?> call(String pageId) => _repository.getByPageId(pageId);
}
