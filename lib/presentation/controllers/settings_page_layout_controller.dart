import 'package:antwise/domain/entities/builder_page_entity.dart';
import 'package:antwise/domain/usecases/get_builder_pages_usecase.dart';
import 'package:antwise/presentation/routes/app_routes.dart';
import 'package:get/get.dart';

class SettingsPageLayoutController extends GetxController {
  SettingsPageLayoutController(this._getPages);

  final GetBuilderPagesUseCase _getPages;

  final RxBool isLoading = true.obs;
  final RxList<BuilderPageEntity> pages = <BuilderPageEntity>[].obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      final List<BuilderPageEntity> all = await _getPages();
      pages.assignAll(
        all.where((BuilderPageEntity p) => !p.isDeleted).toList(growable: false),
      );
    } finally {
      isLoading.value = false;
    }
  }

  void openPageLayout(String pageId) {
    Get.toNamed<void>(AppRoutes.settingsPageLayoutEdit, arguments: pageId)?.then(
      (_) => load(),
    );
  }
}
