import 'package:antwise/core/storage/hive_boxes.dart';
import 'package:antwise/core/storage/hive_service.dart';
import 'package:antwise/data/models/hive/builder_page_hive_model.dart';

abstract class BuilderPagesLocalDataSource {
  Future<List<BuilderPageHiveModel>> readPages();

  Future<void> writePages(List<BuilderPageHiveModel> pages);
}

class BuilderPagesLocalDataSourceImpl implements BuilderPagesLocalDataSource {
  BuilderPagesLocalDataSourceImpl(this._hiveService);

  final HiveService _hiveService;

  @override
  Future<List<BuilderPageHiveModel>> readPages() async {
    return _hiveService
        .box<BuilderPageHiveModel>(HiveBoxes.pagesBox)
        .values
        .toList(growable: false);
  }

  @override
  Future<void> writePages(List<BuilderPageHiveModel> pages) async {
    final box = _hiveService.box<BuilderPageHiveModel>(HiveBoxes.pagesBox);
    await box.clear();
    for (final BuilderPageHiveModel page in pages) {
      await box.put(page.id, page);
    }
  }
}
