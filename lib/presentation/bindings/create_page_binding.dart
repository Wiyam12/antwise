import 'package:antwise/presentation/controllers/create_page_hub_controller.dart';
import 'package:get/get.dart';

class CreatePageBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CreatePageHubController>(CreatePageHubController.new);
  }
}
