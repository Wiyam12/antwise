import 'package:antwise/domain/repositories/table_row_repository.dart';

class DeleteTableRowUseCase {
  DeleteTableRowUseCase(this._repository);

  final TableRowRepository _repository;

  Future<void> call(String rowId) => _repository.delete(rowId);
}
