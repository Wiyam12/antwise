import 'package:antwise/domain/entities/builder_widget_entity.dart';
import 'package:antwise/domain/repositories/builder_widget_repository.dart';

class ReplaceBuilderWidgetsUseCase {
  ReplaceBuilderWidgetsUseCase(this._repository);

  final BuilderWidgetRepository _repository;

  Future<void> call(List<BuilderWidgetEntity> widgets) =>
      _repository.replaceAll(widgets);
}
