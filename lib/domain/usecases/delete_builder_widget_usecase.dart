import 'package:antwise/domain/repositories/builder_widget_repository.dart';

class DeleteBuilderWidgetUseCase {
  DeleteBuilderWidgetUseCase(this._repository);

  final BuilderWidgetRepository _repository;

  Future<void> call(String widgetId) => _repository.delete(widgetId);
}
