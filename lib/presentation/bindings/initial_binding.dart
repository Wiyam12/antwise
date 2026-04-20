import 'package:antwise/core/storage/hive_service.dart';
import 'package:antwise/core/services/logger_service.dart';
import 'package:antwise/data/datasources/app_resources_local_datasource.dart';
import 'package:antwise/data/datasources/builder_pages_local_datasource.dart';
import 'package:antwise/data/datasources/navigation_config_local_datasource.dart';
import 'package:antwise/data/repositories/app_resources_repository_impl.dart';
import 'package:antwise/data/repositories/builder_pages_repository_impl.dart';
import 'package:antwise/data/repositories/navigation_config_repository_impl.dart';
import 'package:antwise/domain/repositories/app_resources_repository.dart';
import 'package:antwise/domain/repositories/builder_pages_repository.dart';
import 'package:antwise/domain/repositories/navigation_config_repository.dart';
import 'package:antwise/domain/usecases/check_resources_downloaded_usecase.dart';
import 'package:antwise/domain/usecases/download_app_resources_usecase.dart';
import 'package:antwise/domain/usecases/get_builder_pages_usecase.dart';
import 'package:antwise/domain/usecases/get_navigation_config_usecase.dart';
import 'package:antwise/domain/usecases/mark_resources_downloaded_usecase.dart';
import 'package:antwise/domain/usecases/replace_builder_pages_usecase.dart';
import 'package:antwise/domain/usecases/save_builder_page_usecase.dart';
import 'package:antwise/domain/usecases/save_navigation_config_usecase.dart';
import 'package:antwise/presentation/bindings/builder_page_runtime_deps.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide singletons and initialization dependencies.
///
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<LoggerService>(DebugLoggerService(), permanent: true);

    Get.lazyPut<AppResourcesLocalDataSource>(
      () => AppResourcesLocalDataSourceImpl(Get.find<SharedPreferences>()),
    );
    Get.lazyPut<AppResourcesRepository>(
      () => AppResourcesRepositoryImpl(Get.find<AppResourcesLocalDataSource>()),
    );
    Get.lazyPut<CheckResourcesDownloadedUseCase>(
      () => CheckResourcesDownloadedUseCase(Get.find<AppResourcesRepository>()),
    );
    Get.lazyPut<MarkResourcesDownloadedUseCase>(
      () => MarkResourcesDownloadedUseCase(Get.find<AppResourcesRepository>()),
    );
    Get.lazyPut<DownloadAppResourcesUseCase>(
      () => DownloadAppResourcesUseCase(Get.find<AppResourcesRepository>()),
    );

    Get.lazyPut<BuilderPagesLocalDataSource>(
      () => BuilderPagesLocalDataSourceImpl(Get.find<HiveService>()),
    );
    Get.lazyPut<BuilderPagesRepository>(
      () => BuilderPagesRepositoryImpl(Get.find<BuilderPagesLocalDataSource>()),
    );
    Get.lazyPut<GetBuilderPagesUseCase>(
      () => GetBuilderPagesUseCase(Get.find<BuilderPagesRepository>()),
    );
    Get.lazyPut<SaveBuilderPageUseCase>(
      () => SaveBuilderPageUseCase(Get.find<BuilderPagesRepository>()),
    );
    Get.lazyPut<ReplaceBuilderPagesUseCase>(
      () => ReplaceBuilderPagesUseCase(Get.find<BuilderPagesRepository>()),
    );

    Get.lazyPut<NavigationConfigLocalDataSource>(
      () => NavigationConfigLocalDataSourceImpl(Get.find<HiveService>()),
    );
    Get.lazyPut<NavigationConfigRepository>(
      () => NavigationConfigRepositoryImpl(
        Get.find<NavigationConfigLocalDataSource>(),
      ),
    );
    Get.lazyPut<GetNavigationConfigUseCase>(
      () => GetNavigationConfigUseCase(Get.find<NavigationConfigRepository>()),
    );
    Get.lazyPut<SaveNavigationConfigUseCase>(
      () => SaveNavigationConfigUseCase(Get.find<NavigationConfigRepository>()),
    );

    ensureBuilderPageRuntimeDependenciesRegistered();
  }
}
