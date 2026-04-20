import 'package:antwise/data/datasources/builder_pages_local_datasource.dart';
import 'package:antwise/data/models/hive/builder_page_hive_model.dart';
import 'package:antwise/domain/entities/builder_page_entity.dart';
import 'package:antwise/domain/repositories/builder_pages_repository.dart';

class BuilderPagesRepositoryImpl implements BuilderPagesRepository {
  BuilderPagesRepositoryImpl(this._local);

  final BuilderPagesLocalDataSource _local;

  @override
  Future<List<BuilderPageEntity>> getPages() async {
    final List<BuilderPageHiveModel> models = await _local.readPages();
    return models.map((BuilderPageHiveModel m) => m.toEntity()).toList();
  }

  @override
  Future<void> savePage(BuilderPageEntity page) async {
    final List<BuilderPageHiveModel> current = await _local.readPages();
    final List<BuilderPageHiveModel> next = <BuilderPageHiveModel>[
      ...current,
      BuilderPageHiveModel.fromEntity(page),
    ];
    await _local.writePages(next);
  }

  @override
  Future<void> replacePages(List<BuilderPageEntity> pages) async {
    final List<BuilderPageHiveModel> next = pages
        .map(BuilderPageHiveModel.fromEntity)
        .toList(growable: false);
    await _local.writePages(next);
  }
}
