import 'package:antwise/core/storage/hive_boxes.dart';
import 'package:antwise/core/storage/hive_service.dart';
import 'package:antwise/data/models/hive/builder_widget_hive_model.dart';

abstract class BuilderWidgetLocalDataSource {
  Future<List<BuilderWidgetHiveModel>> readAll();

  Future<void> write(BuilderWidgetHiveModel widget);

  Future<void> writeAll(List<BuilderWidgetHiveModel> widgets);

  Future<void> delete(String widgetId);
}

class BuilderWidgetLocalDataSourceImpl implements BuilderWidgetLocalDataSource {
  BuilderWidgetLocalDataSourceImpl(this._hiveService);

  final HiveService _hiveService;

  @override
  Future<List<BuilderWidgetHiveModel>> readAll() async {
    return _hiveService
        .box<BuilderWidgetHiveModel>(HiveBoxes.widgetsBox)
        .values
        .toList(growable: false);
  }

  @override
  Future<void> write(BuilderWidgetHiveModel widget) async {
    await _hiveService
        .box<BuilderWidgetHiveModel>(HiveBoxes.widgetsBox)
        .put(widget.id, widget);
  }

  @override
  Future<void> writeAll(List<BuilderWidgetHiveModel> widgets) async {
    final box = _hiveService.box<BuilderWidgetHiveModel>(HiveBoxes.widgetsBox);
    await box.clear();
    for (final BuilderWidgetHiveModel widget in widgets) {
      await box.put(widget.id, widget);
    }
  }

  @override
  Future<void> delete(String widgetId) async {
    await _hiveService.box<BuilderWidgetHiveModel>(HiveBoxes.widgetsBox).delete(widgetId);
  }
}
