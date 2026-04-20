import 'package:antwise/domain/usecases/download_app_resources_usecase.dart';
import 'package:antwise/domain/usecases/mark_resources_downloaded_usecase.dart';
import 'package:antwise/presentation/controllers/download_resources_controller.dart';
import 'package:get/get.dart';

class DownloadResourcesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DownloadResourcesController>(
      () => DownloadResourcesController(
        Get.find<MarkResourcesDownloadedUseCase>(),
        Get.find<DownloadAppResourcesUseCase>(),
      ),
    );
  }
}
