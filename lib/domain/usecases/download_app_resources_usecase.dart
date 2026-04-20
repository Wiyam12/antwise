import 'package:antwise/domain/repositories/app_resources_repository.dart';

class DownloadAppResourcesUseCase {
  DownloadAppResourcesUseCase(this._repository);

  final AppResourcesRepository _repository;

  Future<void> call({
    required void Function(double progress) onProgress,
  }) =>
      _repository.downloadRequiredResources(onProgress: onProgress);
}
