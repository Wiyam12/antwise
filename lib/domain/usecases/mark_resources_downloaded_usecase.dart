import 'package:antwise/domain/repositories/app_resources_repository.dart';

class MarkResourcesDownloadedUseCase {
  MarkResourcesDownloadedUseCase(this._repository);

  final AppResourcesRepository _repository;

  Future<void> call() => _repository.markResourcesDownloaded();
}
