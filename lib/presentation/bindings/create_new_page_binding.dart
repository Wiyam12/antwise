import 'package:antwise/core/storage/hive_service.dart';
import 'package:antwise/data/datasources/builder_pages_local_datasource.dart';
import 'package:antwise/data/repositories/builder_pages_repository_impl.dart';
import 'package:antwise/data/datasources/navigation_config_local_datasource.dart';
import 'package:antwise/data/repositories/builder_widget_repository_impl.dart';
import 'package:antwise/data/datasources/builder_widget_local_datasource.dart';
import 'package:antwise/data/repositories/navigation_config_repository_impl.dart';
import 'package:antwise/domain/repositories/builder_pages_repository.dart';
import 'package:antwise/domain/repositories/builder_widget_repository.dart';
import 'package:antwise/domain/repositories/navigation_config_repository.dart';
import 'package:antwise/domain/usecases/get_builder_pages_usecase.dart';
import 'package:antwise/domain/usecases/get_builder_widgets_by_page_usecase.dart';
import 'package:antwise/domain/usecases/get_navigation_config_usecase.dart';
import 'package:antwise/domain/usecases/get_table_schema_by_page_usecase.dart';
import 'package:antwise/domain/usecases/replace_builder_pages_usecase.dart';
import 'package:antwise/domain/usecases/save_builder_page_usecase.dart';
import 'package:antwise/domain/usecases/save_navigation_config_usecase.dart';
import 'package:antwise/presentation/bindings/builder_page_runtime_deps.dart';
import 'package:antwise/presentation/controllers/create_new_page_controller.dart';
import 'package:get/get.dart';

class CreateNewPageBinding extends Bindings {
  @override
  void dependencies() {
    ensureBuilderPageRuntimeDependenciesRegistered();
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
    if (!Get.isRegistered<ReplaceBuilderPagesUseCase>()) {
      Get.lazyPut<ReplaceBuilderPagesUseCase>(
        () => ReplaceBuilderPagesUseCase(Get.find<BuilderPagesRepository>()),
      );
    }
    if (!Get.isRegistered<NavigationConfigLocalDataSource>()) {
      Get.lazyPut<NavigationConfigLocalDataSource>(
        () => NavigationConfigLocalDataSourceImpl(Get.find<HiveService>()),
      );
    }
    if (!Get.isRegistered<NavigationConfigRepository>()) {
      Get.lazyPut<NavigationConfigRepository>(
        () => NavigationConfigRepositoryImpl(
          Get.find<NavigationConfigLocalDataSource>(),
        ),
      );
    }
    if (!Get.isRegistered<GetNavigationConfigUseCase>()) {
      Get.lazyPut<GetNavigationConfigUseCase>(
        () => GetNavigationConfigUseCase(Get.find<NavigationConfigRepository>()),
      );
    }
    if (!Get.isRegistered<SaveNavigationConfigUseCase>()) {
      Get.lazyPut<SaveNavigationConfigUseCase>(
        () => SaveNavigationConfigUseCase(
          Get.find<NavigationConfigRepository>(),
        ),
      );
    }
    if (!Get.isRegistered<BuilderWidgetLocalDataSource>()) {
      Get.lazyPut<BuilderWidgetLocalDataSource>(
        () => BuilderWidgetLocalDataSourceImpl(Get.find<HiveService>()),
      );
    }
    if (!Get.isRegistered<BuilderWidgetRepository>()) {
      Get.lazyPut<BuilderWidgetRepository>(
        () => BuilderWidgetRepositoryImpl(Get.find<BuilderWidgetLocalDataSource>()),
      );
    }
    if (!Get.isRegistered<GetBuilderWidgetsByPageUseCase>()) {
      Get.lazyPut<GetBuilderWidgetsByPageUseCase>(
        () => GetBuilderWidgetsByPageUseCase(Get.find<BuilderWidgetRepository>()),
      );
    }
    Get.lazyPut<CreateNewPageController>(
      () => CreateNewPageController(
        Get.find<SaveBuilderPageUseCase>(),
        Get.find<GetBuilderPagesUseCase>(),
        Get.find<ReplaceBuilderPagesUseCase>(),
        Get.find<GetBuilderWidgetsByPageUseCase>(),
        Get.find<GetTableSchemaByPageUseCase>(),
      ),
    );
  }
}
