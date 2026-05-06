import 'package:antwise/core/services/ai_service.dart';
import 'package:antwise/presentation/controllers/ai_chat_controller.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiChatBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AiChatController>(
      () => AiChatController(
        Get.find<AIService>(),
        Get.find<SharedPreferences>(),
      ),
    );
  }
}
