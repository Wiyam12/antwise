import 'package:antwise/data/datasources/builder_widget_local_datasource.dart';
import 'package:antwise/data/models/hive/builder_widget_hive_model.dart';
import 'package:antwise/domain/entities/builder_widget_entity.dart';
import 'package:antwise/domain/repositories/builder_widget_repository.dart';

class BuilderWidgetRepositoryImpl implements BuilderWidgetRepository {
  BuilderWidgetRepositoryImpl(this._local);

  final BuilderWidgetLocalDataSource _local;

  @override
  Future<List<BuilderWidgetEntity>> getAll() async {
    final List<BuilderWidgetHiveModel> all = await _local.readAll();
    return all
        .map(
          (BuilderWidgetHiveModel model) => BuilderWidgetEntity(
            id: model.id,
            pageId: model.pageId,
            type: model.type,
            config: model.config,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<BuilderWidgetEntity>> getByPageId(String pageId) async {
    return (await getAll())
        .where((BuilderWidgetEntity model) => model.pageId == pageId)
        .toList(growable: false);
  }

  @override
  Future<void> save(BuilderWidgetEntity widget) async {
    await _local.write(
      BuilderWidgetHiveModel(
        id: widget.id,
        pageId: widget.pageId,
        type: widget.type,
        config: widget.config,
      ),
    );
  }

  @override
  Future<void> replaceAll(List<BuilderWidgetEntity> widgets) async {
    await _local.writeAll(
      widgets
          .map(
            (BuilderWidgetEntity widget) => BuilderWidgetHiveModel(
              id: widget.id,
              pageId: widget.pageId,
              type: widget.type,
              config: widget.config,
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<void> delete(String widgetId) async {
    await _local.delete(widgetId);
  }
}
