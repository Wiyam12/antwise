import 'package:antwise/domain/entities/builder_widget_entity.dart';

abstract class BuilderWidgetRepository {
  Future<List<BuilderWidgetEntity>> getAll();

  Future<List<BuilderWidgetEntity>> getByPageId(String pageId);

  Future<void> save(BuilderWidgetEntity widget);

  Future<void> replaceAll(List<BuilderWidgetEntity> widgets);

  Future<void> delete(String widgetId);
}
