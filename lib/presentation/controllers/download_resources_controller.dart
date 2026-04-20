import 'package:antwise/core/services/logger_service.dart';
import 'package:antwise/domain/usecases/download_app_resources_usecase.dart';
import 'package:antwise/domain/usecases/mark_resources_downloaded_usecase.dart';
import 'package:antwise/presentation/routes/app_routes.dart';
import 'package:get/get.dart';

/// Downloads required resources, then persists completion and opens home.
class DownloadResourcesController extends GetxController {
  DownloadResourcesController(this._markDownloaded, this._downloadResources);

  final MarkResourcesDownloadedUseCase _markDownloaded;
  final DownloadAppResourcesUseCase _downloadResources;

  final RxDouble progress = 0.0.obs;
  final RxString statusMessage = 'Preparing download…'.obs;
  final RxBool isComplete = false.obs;
  final RxnString errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    _startDownload();
  }

  Future<void> _startDownload() async {
    errorMessage.value = null;
    try {
      await _downloadResources(
        onProgress: (double value) {
          progress.value = value;
          statusMessage.value =
              'Downloading resources… ${(value * 100).toStringAsFixed(0)}%';
        },
      );
      statusMessage.value = 'Finalizing…';
      await _markDownloaded();
      isComplete.value = true;
      statusMessage.value = 'Ready';
      await Future<void>.delayed(const Duration(milliseconds: 400));
      Get.offAllNamed<void>(AppRoutes.home);
    } catch (e, st) {
      Get.find<LoggerService>().d('Resource download failed', e, st);
      errorMessage.value = 'Download failed. Please restart the app.';
      statusMessage.value = 'Error';
    }
  }
}
