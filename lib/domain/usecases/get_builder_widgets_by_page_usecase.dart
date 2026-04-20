import 'package:antwise/domain/entities/builder_widget_entity.dart';
import 'package:antwise/domain/repositories/builder_widget_repository.dart';

class GetBuilderWidgetsByPageUseCase {
  GetBuilderWidgetsByPageUseCase(this._repository);

  final BuilderWidgetRepository _repository;

  Future<List<BuilderWidgetEntity>> call(String pageId) =>
      _repository.getByPageId(pageId);
}
