import 'package:antwise/core/storage/hive_service.dart';
import 'package:antwise/data/datasources/builder_pages_local_datasource.dart';
import 'package:antwise/data/repositories/builder_pages_repository_impl.dart';
import 'package:antwise/domain/repositories/builder_pages_repository.dart';
import 'package:antwise/domain/usecases/get_builder_pages_usecase.dart';
import 'package:antwise/domain/usecases/save_builder_page_usecase.dart';
import 'package:antwise/presentation/controllers/create_new_page_controller.dart';
import 'package:get/get.dart';

class CreateNewPageBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<BuilderPagesLocalDataSource>()) {
      Get.lazyPut<BuilderPagesLocalDataSource>(
        () => BuilderPagesLocalDataSourceImpl(Get.find<HiveService>()),
      );
    }
    if (!Get.isRegistered<BuilderPagesRepository>()) {
      Get.lazyPut<BuilderPagesRepository>(
        () =>
            BuilderPagesRepositoryImpl(Get.find<BuilderPagesLocalDataSource>()),
      );
    }
    if (!Get.isRegistered<GetBuilderPagesUseCase>()) {
      Get.lazyPut<GetBuilderPagesUseCase>(
        () => GetBuilderPagesUseCase(Get.find<BuilderPagesRepository>()),
      );
    }
    if (!Get.isRegistered<SaveBuilderPageUseCase>()) {
      Get.lazyPut<SaveBuilderPageUseCase>(
        () => SaveBuilderPageUseCase(Get.find<BuilderPagesRepository>()),
      );
    }
    Get.lazyPut<CreateNewPageController>(
      () => CreateNewPageController(
        Get.find<SaveBuilderPageUseCase>(),
        Get.find<GetBuilderPagesUseCase>(),
      ),
    );
  }
}
