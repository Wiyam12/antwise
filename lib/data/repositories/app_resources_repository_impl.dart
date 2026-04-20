import 'package:antwise/data/datasources/app_resources_local_datasource.dart';
import 'package:antwise/domain/repositories/app_resources_repository.dart';

class AppResourcesRepositoryImpl implements AppResourcesRepository {
  AppResourcesRepositoryImpl(this._local);

  final AppResourcesLocalDataSource _local;

  @override
  Future<bool> areResourcesDownloaded() => _local.readResourcesDownloaded();

  @override
  Future<void> markResourcesDownloaded() =>
      _local.writeResourcesDownloaded(true);

  @override
  Future<void> downloadRequiredResources({
    required void Function(double progress) onProgress,
  }) async {
    const int steps = 24;
    for (var i = 1; i <= steps; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 45));
      onProgress(i / steps);
    }
  }
}
