import 'package:antwise/core/services/ai/ai_build_action_executor.dart';
import 'package:antwise/core/services/ai_service.dart';
import 'package:antwise/core/storage/hive_service.dart';
import 'package:antwise/core/storage/ai_chat_history_repository.dart';
import 'package:antwise/data/datasources/builder_pages_local_datasource.dart';
import 'package:antwise/data/datasources/navigation_config_local_datasource.dart';
import 'package:antwise/data/repositories/builder_pages_repository_impl.dart';
import 'package:antwise/data/repositories/navigation_config_repository_impl.dart';
import 'package:antwise/domain/repositories/builder_pages_repository.dart';
import 'package:antwise/domain/repositories/builder_widget_repository.dart';
import 'package:antwise/domain/repositories/navigation_config_repository.dart';
import 'package:antwise/domain/repositories/table_row_repository.dart';
import 'package:antwise/domain/repositories/table_schema_repository.dart';
import 'package:antwise/domain/usecases/delete_builder_widget_usecase.dart';
import 'package:antwise/domain/usecases/delete_rows_by_table_usecase.dart';
import 'package:antwise/domain/usecases/delete_table_schema_usecase.dart';
import 'package:antwise/domain/usecases/get_all_builder_widgets_usecase.dart';
import 'package:antwise/domain/usecases/get_all_table_schemas_usecase.dart';
import 'package:antwise/domain/usecases/get_builder_pages_usecase.dart';
import 'package:antwise/domain/usecases/get_builder_widgets_by_page_usecase.dart';
import 'package:antwise/domain/usecases/get_navigation_config_usecase.dart';
import 'package:antwise/domain/usecases/replace_builder_pages_usecase.dart';
import 'package:antwise/domain/usecases/save_builder_page_usecase.dart';
import 'package:antwise/domain/usecases/save_builder_widget_usecase.dart';
import 'package:antwise/domain/usecases/save_navigation_config_usecase.dart';
import 'package:antwise/domain/usecases/save_table_schema_usecase.dart';
import 'package:antwise/presentation/bindings/builder_page_runtime_deps.dart';
import 'package:antwise/presentation/controllers/ai_chat_controller.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiChatBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AiChatHistoryRepository>(
      () => AiChatHistoryRepository(
        Get.find<HiveService>(),
        Get.find<SharedPreferences>(),
      ),
    );

    ensureBuilderPageRuntimeDependenciesRegistered();
    _ensureBuilderPageNavRegistered();
    _ensureMutationUseCasesRegistered();

    if (!Get.isRegistered<AiBuildActionExecutor>()) {
      Get.lazyPut<AiBuildActionExecutor>(
        () => AiBuildActionExecutor(
          saveBuilderPage: Get.find<SaveBuilderPageUseCase>(),
          replaceBuilderPages: Get.find<ReplaceBuilderPagesUseCase>(),
          getBuilderPages: Get.find<GetBuilderPagesUseCase>(),
          saveTableSchema: Get.find<SaveTableSchemaUseCase>(),
          getAllTableSchemas: Get.find<GetAllTableSchemasUseCase>(),
          deleteTableSchema: Get.find<DeleteTableSchemaUseCase>(),
          deleteRowsByTable: Get.find<DeleteRowsByTableUseCase>(),
          saveBuilderWidget: Get.find<SaveBuilderWidgetUseCase>(),
          getBuilderWidgetsByPage: Get.find<GetBuilderWidgetsByPageUseCase>(),
          getAllBuilderWidgets: Get.find<GetAllBuilderWidgetsUseCase>(),
          deleteBuilderWidget: Get.find<DeleteBuilderWidgetUseCase>(),
          getNavigationConfig: Get.find<GetNavigationConfigUseCase>(),
          saveNavigationConfig: Get.find<SaveNavigationConfigUseCase>(),
        ),
        fenix: true,
      );
    }

    Get.lazyPut<AiChatController>(
      () => AiChatController(
        Get.find<AIService>(),
        Get.find<AiChatHistoryRepository>(),
        Get.find<AiBuildActionExecutor>(),
      ),
    );
  }

  /// `InitialBinding` already registers these for the home route. When the AI
  /// chat is reached without going through Home (deep link / test harness),
  /// register them lazily here so the executor can resolve its dependencies.
  void _ensureBuilderPageNavRegistered() {
    if (!Get.isRegistered<BuilderPagesLocalDataSource>()) {
      Get.lazyPut<BuilderPagesLocalDataSource>(
        () => BuilderPagesLocalDataSourceImpl(Get.find<HiveService>()),
        fenix: true,
      );
    }
    if (!Get.isRegistered<BuilderPagesRepository>()) {
      Get.lazyPut<BuilderPagesRepository>(
        () =>
            BuilderPagesRepositoryImpl(Get.find<BuilderPagesLocalDataSource>()),
        fenix: true,
      );
    }
    if (!Get.isRegistered<GetBuilderPagesUseCase>()) {
      Get.lazyPut<GetBuilderPagesUseCase>(
        () => GetBuilderPagesUseCase(Get.find<BuilderPagesRepository>()),
        fenix: true,
      );
    }
    if (!Get.isRegistered<SaveBuilderPageUseCase>()) {
      Get.lazyPut<SaveBuilderPageUseCase>(
        () => SaveBuilderPageUseCase(Get.find<BuilderPagesRepository>()),
        fenix: true,
      );
    }
    if (!Get.isRegistered<ReplaceBuilderPagesUseCase>()) {
      Get.lazyPut<ReplaceBuilderPagesUseCase>(
        () => ReplaceBuilderPagesUseCase(Get.find<BuilderPagesRepository>()),
        fenix: true,
      );
    }
    if (!Get.isRegistered<NavigationConfigLocalDataSource>()) {
      Get.lazyPut<NavigationConfigLocalDataSource>(
        () => NavigationConfigLocalDataSourceImpl(Get.find<HiveService>()),
        fenix: true,
      );
    }
    if (!Get.isRegistered<NavigationConfigRepository>()) {
      Get.lazyPut<NavigationConfigRepository>(
        () => NavigationConfigRepositoryImpl(
          Get.find<NavigationConfigLocalDataSource>(),
        ),
        fenix: true,
      );
    }
    if (!Get.isRegistered<GetNavigationConfigUseCase>()) {
      Get.lazyPut<GetNavigationConfigUseCase>(
        () => GetNavigationConfigUseCase(Get.find<NavigationConfigRepository>()),
        fenix: true,
      );
    }
    if (!Get.isRegistered<SaveNavigationConfigUseCase>()) {
      Get.lazyPut<SaveNavigationConfigUseCase>(
        () => SaveNavigationConfigUseCase(Get.find<NavigationConfigRepository>()),
        fenix: true,
      );
    }
  }

  /// Delete-cascade dependencies that the executor needs for `delete_*` and
  /// `update_*` actions. The corresponding repositories were already wired up
  /// by `ensureBuilderPageRuntimeDependenciesRegistered()` (table schema,
  /// table rows, builder widgets), so we just expose the missing use cases.
  void _ensureMutationUseCasesRegistered() {
    if (!Get.isRegistered<DeleteTableSchemaUseCase>()) {
      Get.lazyPut<DeleteTableSchemaUseCase>(
        () => DeleteTableSchemaUseCase(Get.find<TableSchemaRepository>()),
        fenix: true,
      );
    }
    if (!Get.isRegistered<DeleteRowsByTableUseCase>()) {
      Get.lazyPut<DeleteRowsByTableUseCase>(
        () => DeleteRowsByTableUseCase(Get.find<TableRowRepository>()),
        fenix: true,
      );
    }
    if (!Get.isRegistered<GetAllBuilderWidgetsUseCase>()) {
      Get.lazyPut<GetAllBuilderWidgetsUseCase>(
        () => GetAllBuilderWidgetsUseCase(Get.find<BuilderWidgetRepository>()),
        fenix: true,
      );
    }
    if (!Get.isRegistered<DeleteBuilderWidgetUseCase>()) {
      Get.lazyPut<DeleteBuilderWidgetUseCase>(
        () => DeleteBuilderWidgetUseCase(Get.find<BuilderWidgetRepository>()),
        fenix: true,
      );
    }
  }
}
