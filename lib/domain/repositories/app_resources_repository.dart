/// App-wide resource bootstrap: download state and required assets.
abstract class AppResourcesRepository {
  Future<bool> areResourcesDownloaded();

  Future<void> markResourcesDownloaded();

  /// Performs required downloads; reports progress in [0, 1].
  Future<void> downloadRequiredResources({
    required void Function(double progress) onProgress,
  });
}
