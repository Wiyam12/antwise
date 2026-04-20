import 'package:antwise/domain/entities/table_row_entity.dart';
import 'package:antwise/domain/repositories/table_row_repository.dart';

class UpdateTableRowUseCase {
  UpdateTableRowUseCase(this._repository);

  final TableRowRepository _repository;

  Future<void> call(TableRowEntity row) => _repository.update(row);
}
