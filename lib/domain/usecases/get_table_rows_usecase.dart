import 'package:antwise/domain/entities/table_row_entity.dart';
import 'package:antwise/domain/repositories/table_row_repository.dart';

class GetTableRowsUseCase {
  GetTableRowsUseCase(this._repository);

  final TableRowRepository _repository;

  Future<List<TableRowEntity>> call(String tableId) =>
      _repository.getByTableId(tableId);
}
