import 'package:antwise/domain/repositories/app_resources_repository.dart';

class CheckResourcesDownloadedUseCase {
  CheckResourcesDownloadedUseCase(this._repository);

  final AppResourcesRepository _repository;

  Future<bool> call() => _repository.areResourcesDownloaded();
}
