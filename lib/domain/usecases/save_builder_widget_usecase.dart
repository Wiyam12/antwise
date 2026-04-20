import 'package:antwise/domain/entities/builder_widget_entity.dart';
import 'package:antwise/domain/repositories/builder_widget_repository.dart';

class SaveBuilderWidgetUseCase {
  SaveBuilderWidgetUseCase(this._repository);

  final BuilderWidgetRepository _repository;

  Future<void> call(BuilderWidgetEntity widget) => _repository.save(widget);
}
