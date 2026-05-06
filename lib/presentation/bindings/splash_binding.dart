import 'package:antwise/domain/usecases/check_resources_downloaded_usecase.dart';
import 'package:antwise/presentation/controllers/splash_controller.dart';
import 'package:get/get.dart';

class SplashBinding extends Bindings {
  @override
  void dependencies() {
    // Eager registration so lifecycle + navigation run reliably on first route.
    Get.put<SplashController>(
      SplashController(
        Get.find<CheckResourcesDownloadedUseCase>(),
      ),
    );
  }
}
