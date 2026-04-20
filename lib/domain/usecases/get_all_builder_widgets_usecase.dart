import 'package:antwise/domain/entities/builder_widget_entity.dart';
import 'package:antwise/domain/repositories/builder_widget_repository.dart';

class GetAllBuilderWidgetsUseCase {
  GetAllBuilderWidgetsUseCase(this._repository);

  final BuilderWidgetRepository _repository;

  Future<List<BuilderWidgetEntity>> call() => _repository.getAll();
}
