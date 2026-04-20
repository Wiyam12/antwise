import 'package:antwise/presentation/routes/app_routes.dart';
import 'package:get/get.dart';

class CreatePageHubController extends GetxController {
  void openNewPage() {
    Get.toNamed<void>(AppRoutes.createNewPage);
  }

  void openCreateTable() {
    Get.toNamed<void>(AppRoutes.createTable);
  }

  void openCreateWidget() {
    Get.toNamed<void>(AppRoutes.createWidget);
  }
}
