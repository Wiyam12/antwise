import 'package:antwise/core/services/ai_service.dart';
import 'package:antwise/data/datasources/app_resources_local_datasource.dart';
import 'package:antwise/domain/repositories/app_resources_repository.dart';

class AppResourcesRepositoryImpl implements AppResourcesRepository {
  AppResourcesRepositoryImpl(this._local, this._aiService);

  final AppResourcesLocalDataSource _local;
  final AIService _aiService;

  @override
  Future<bool> areResourcesDownloaded() => _local.readResourcesDownloaded();

  @override
  Future<void> markResourcesDownloaded() =>
      _local.writeResourcesDownloaded(true);

  @override
  Future<void> downloadRequiredResources({
    required void Function(double progress) onProgress,
  }) async {
    final bool alreadyInstalled = await _aiService.checkModelExists();
    if (alreadyInstalled) {
      onProgress(1.0);
      return;
    }
    await _aiService.downloadModel(
      onProgress: (int received, int? total) {
        final int safeTotal = (total == null || total <= 0) ? 1 : total;
        final double ratio =
            (received / safeTotal).clamp(0.0, 1.0).toDouble();
        onProgress(ratio);
      },
    );
  }
}
