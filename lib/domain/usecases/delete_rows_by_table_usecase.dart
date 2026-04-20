import 'package:antwise/domain/repositories/table_row_repository.dart';

class DeleteRowsByTableUseCase {
  DeleteRowsByTableUseCase(this._repository);

  final TableRowRepository _repository;

  Future<void> call(String tableId) => _repository.deleteByTableId(tableId);
}
