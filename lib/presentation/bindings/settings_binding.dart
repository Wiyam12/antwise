import 'package:antwise/core/storage/hive_service.dart';
import 'package:antwise/data/datasources/builder_pages_local_datasource.dart';
import 'package:antwise/data/datasources/navigation_config_local_datasource.dart';
import 'package:antwise/data/datasources/builder_widget_local_datasource.dart';
import 'package:antwise/data/datasources/table_row_local_datasource.dart';
import 'package:antwise/data/datasources/table_schema_local_datasource.dart';
import 'package:antwise/data/repositories/builder_pages_repository_impl.dart';
import 'package:antwise/data/repositories/builder_widget_repository_impl.dart';
import 'package:antwise/data/repositories/navigation_config_repository_impl.dart';
import 'package:antwise/data/repositories/table_row_repository_impl.dart';
import 'package:antwise/data/repositories/table_schema_repository_impl.dart';
import 'package:antwise/domain/repositories/builder_widget_repository.dart';
import 'package:antwise/domain/repositories/builder_pages_repository.dart';
import 'package:antwise/domain/repositories/navigation_config_repository.dart';
import 'package:antwise/domain/repositories/table_row_repository.dart';
import 'package:antwise/domain/repositories/table_schema_repository.dart';
import 'package:antwise/domain/usecases/delete_builder_widget_usecase.dart';
import 'package:antwise/domain/usecases/delete_rows_by_table_usecase.dart';
import 'package:antwise/domain/usecases/delete_table_schema_usecase.dart';
import 'package:antwise/domain/usecases/get_all_builder_widgets_usecase.dart';
import 'package:antwise/domain/usecases/get_all_table_schemas_usecase.dart';
import 'package:antwise/domain/usecases/get_builder_pages_usecase.dart';
import 'package:antwise/domain/usecases/get_navigation_config_usecase.dart';
import 'package:antwise/domain/usecases/get_table_rows_usecase.dart';
import 'package:antwise/domain/usecases/get_table_schema_by_id_usecase.dart';
import 'package:antwise/domain/usecases/replace_builder_pages_usecase.dart';
import 'package:antwise/domain/usecases/replace_builder_widgets_usecase.dart';
import 'package:antwise/domain/usecases/save_builder_widget_usecase.dart';
import 'package:antwise/domain/usecases/save_navigation_config_usecase.dart';
import 'package:antwise/domain/usecases/save_table_schema_usecase.dart';
import 'package:antwise/presentation/controllers/edit_table_controller.dart';
import 'package:antwise/presentation/controllers/settings_page_layout_controller.dart';
import 'package:antwise/presentation/controllers/settings_page_layout_edit_controller.dart';
import 'package:antwise/presentation/controllers/settings_controller.dart';
import 'package:antwise/presentation/controllers/settings_widget_edit_controller.dart';
import 'package:antwise/presentation/controllers/settings_tables_controller.dart';
import 'package:antwise/presentation/controllers/settings_widgets_controller.dart';
import 'package:get/get.dart';

class SettingsBinding extends Bindings {
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
        () =>
            GetNavigationConfigUseCase(Get.find<NavigationConfigRepository>()),
      );
    }
    if (!Get.isRegistered<SaveNavigationConfigUseCase>()) {
      Get.lazyPut<SaveNavigationConfigUseCase>(
        () =>
            SaveNavigationConfigUseCase(Get.find<NavigationConfigRepository>()),
      );
    }
    if (!Get.isRegistered<ReplaceBuilderPagesUseCase>()) {
      Get.lazyPut<ReplaceBuilderPagesUseCase>(
        () => ReplaceBuilderPagesUseCase(Get.find()),
      );
    }
    if (!Get.isRegistered<TableSchemaLocalDataSource>()) {
      Get.lazyPut<TableSchemaLocalDataSource>(
        () => TableSchemaLocalDataSourceImpl(Get.find<HiveService>()),
      );
    }
    if (!Get.isRegistered<TableSchemaRepository>()) {
      Get.lazyPut<TableSchemaRepository>(
        () => TableSchemaRepositoryImpl(Get.find<TableSchemaLocalDataSource>()),
      );
    }
    if (!Get.isRegistered<GetAllTableSchemasUseCase>()) {
      Get.lazyPut<GetAllTableSchemasUseCase>(
        () => GetAllTableSchemasUseCase(Get.find<TableSchemaRepository>()),
      );
    }
    if (!Get.isRegistered<GetTableSchemaByIdUseCase>()) {
      Get.lazyPut<GetTableSchemaByIdUseCase>(
        () => GetTableSchemaByIdUseCase(Get.find<TableSchemaRepository>()),
      );
    }
    if (!Get.isRegistered<SaveTableSchemaUseCase>()) {
      Get.lazyPut<SaveTableSchemaUseCase>(
        () => SaveTableSchemaUseCase(Get.find<TableSchemaRepository>()),
      );
    }
    if (!Get.isRegistered<DeleteTableSchemaUseCase>()) {
      Get.lazyPut<DeleteTableSchemaUseCase>(
        () => DeleteTableSchemaUseCase(Get.find<TableSchemaRepository>()),
      );
    }
    if (!Get.isRegistered<TableRowLocalDataSource>()) {
      Get.lazyPut<TableRowLocalDataSource>(
        () => TableRowLocalDataSourceImpl(Get.find<HiveService>()),
      );
    }
    if (!Get.isRegistered<TableRowRepository>()) {
      Get.lazyPut<TableRowRepository>(
        () => TableRowRepositoryImpl(Get.find<TableRowLocalDataSource>()),
      );
    }
    if (!Get.isRegistered<GetTableRowsUseCase>()) {
      Get.lazyPut<GetTableRowsUseCase>(
        () => GetTableRowsUseCase(Get.find<TableRowRepository>()),
      );
    }
    if (!Get.isRegistered<DeleteRowsByTableUseCase>()) {
      Get.lazyPut<DeleteRowsByTableUseCase>(
        () => DeleteRowsByTableUseCase(Get.find<TableRowRepository>()),
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
    if (!Get.isRegistered<GetAllBuilderWidgetsUseCase>()) {
      Get.lazyPut<GetAllBuilderWidgetsUseCase>(
        () => GetAllBuilderWidgetsUseCase(Get.find<BuilderWidgetRepository>()),
      );
    }
    if (!Get.isRegistered<ReplaceBuilderWidgetsUseCase>()) {
      Get.lazyPut<ReplaceBuilderWidgetsUseCase>(
        () => ReplaceBuilderWidgetsUseCase(Get.find<BuilderWidgetRepository>()),
      );
    }
    if (!Get.isRegistered<DeleteBuilderWidgetUseCase>()) {
      Get.lazyPut<DeleteBuilderWidgetUseCase>(
        () => DeleteBuilderWidgetUseCase(Get.find<BuilderWidgetRepository>()),
      );
    }

    Get.lazyPut<SettingsController>(
      () => SettingsController(
        Get.find<GetBuilderPagesUseCase>(),
        Get.find<ReplaceBuilderPagesUseCase>(),
        Get.find<GetNavigationConfigUseCase>(),
        Get.find<SaveNavigationConfigUseCase>(),
      ),
    );
    Get.lazyPut<SettingsTablesController>(
      () => SettingsTablesController(
        Get.find<GetBuilderPagesUseCase>(),
        Get.find<GetAllTableSchemasUseCase>(),
        Get.find<GetAllBuilderWidgetsUseCase>(),
        Get.find<GetTableRowsUseCase>(),
        Get.find<ReplaceBuilderWidgetsUseCase>(),
        Get.find<DeleteTableSchemaUseCase>(),
        Get.find<DeleteRowsByTableUseCase>(),
        Get.find<DeleteBuilderWidgetUseCase>(),
      ),
    );
    Get.lazyPut<SettingsPageLayoutController>(
      () => SettingsPageLayoutController(Get.find<GetBuilderPagesUseCase>()),
    );
    Get.lazyPut<SettingsPageLayoutEditController>(
      () => SettingsPageLayoutEditController(
        Get.find<GetBuilderPagesUseCase>(),
        Get.find<ReplaceBuilderPagesUseCase>(),
        Get.find<GetAllTableSchemasUseCase>(),
        Get.find<GetAllBuilderWidgetsUseCase>(),
      ),
      fenix: true,
    );
    Get.lazyPut<SettingsWidgetsController>(
      () => SettingsWidgetsController(
        Get.find<GetBuilderPagesUseCase>(),
        Get.find<GetAllBuilderWidgetsUseCase>(),
        Get.find<DeleteBuilderWidgetUseCase>(),
      ),
      fenix: true,
    );
    if (!Get.isRegistered<SaveBuilderWidgetUseCase>()) {
      Get.lazyPut<SaveBuilderWidgetUseCase>(
        () => SaveBuilderWidgetUseCase(Get.find<BuilderWidgetRepository>()),
      );
    }
    Get.lazyPut<SettingsWidgetEditController>(
      () => SettingsWidgetEditController(
        Get.find<GetAllBuilderWidgetsUseCase>(),
        Get.find<GetAllTableSchemasUseCase>(),
        Get.find<GetBuilderPagesUseCase>(),
        Get.find<SaveBuilderWidgetUseCase>(),
      ),
      fenix: true,
    );
    Get.lazyPut<EditTableController>(
      () => EditTableController(
        Get.find<GetTableSchemaByIdUseCase>(),
        Get.find<SaveTableSchemaUseCase>(),
        Get.find<GetAllTableSchemasUseCase>(),
      ),
      fenix: true,
    );
  }
}
