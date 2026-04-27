import 'package:antwise/core/storage/hive_service.dart';
import 'package:antwise/data/datasources/builder_widget_local_datasource.dart';
import 'package:antwise/data/datasources/table_row_local_datasource.dart';
import 'package:antwise/data/datasources/table_schema_local_datasource.dart';
import 'package:antwise/data/repositories/builder_widget_repository_impl.dart';
import 'package:antwise/data/repositories/table_row_repository_impl.dart';
import 'package:antwise/data/repositories/table_schema_repository_impl.dart';
import 'package:antwise/domain/repositories/builder_widget_repository.dart';
import 'package:antwise/domain/repositories/table_row_repository.dart';
import 'package:antwise/domain/repositories/table_schema_repository.dart';
import 'package:antwise/domain/usecases/apply_affecting_tables_usecase.dart';
import 'package:antwise/domain/usecases/apply_inventory_deduction_usecase.dart';
import 'package:antwise/domain/usecases/delete_table_row_usecase.dart';
import 'package:antwise/domain/usecases/get_builder_widgets_by_page_usecase.dart';
import 'package:antwise/domain/usecases/get_table_rows_usecase.dart';
import 'package:antwise/domain/usecases/get_all_table_schemas_usecase.dart';
import 'package:antwise/domain/usecases/get_table_schema_by_id_usecase.dart';
import 'package:antwise/domain/usecases/get_table_schema_by_page_usecase.dart';
import 'package:antwise/domain/usecases/save_builder_widget_usecase.dart';
import 'package:antwise/domain/usecases/save_table_row_usecase.dart';
import 'package:antwise/domain/usecases/save_table_schema_usecase.dart';
import 'package:antwise/domain/usecases/update_table_row_usecase.dart';
import 'package:get/get.dart';

/// Table schema, table rows, and builder-widget graph used by
/// [DynamicBuilderPageBody] and related flows.
///
/// Registrations use [fenix] so GetX keeps the factory when the route that
/// first materialized a dependency is disposed (e.g. after [Get.offAllNamed]),
/// instead of dropping the type from the container.
void ensureBuilderPageRuntimeDependenciesRegistered() {
  if (!Get.isRegistered<TableSchemaLocalDataSource>()) {
    Get.lazyPut<TableSchemaLocalDataSource>(
      () => TableSchemaLocalDataSourceImpl(Get.find<HiveService>()),
      fenix: true,
    );
  }
  if (!Get.isRegistered<TableSchemaRepository>()) {
    Get.lazyPut<TableSchemaRepository>(
      () => TableSchemaRepositoryImpl(Get.find<TableSchemaLocalDataSource>()),
      fenix: true,
    );
  }
  if (!Get.isRegistered<SaveTableSchemaUseCase>()) {
    Get.lazyPut<SaveTableSchemaUseCase>(
      () => SaveTableSchemaUseCase(Get.find<TableSchemaRepository>()),
      fenix: true,
    );
  }
  if (!Get.isRegistered<GetTableSchemaByPageUseCase>()) {
    Get.lazyPut<GetTableSchemaByPageUseCase>(
      () => GetTableSchemaByPageUseCase(Get.find<TableSchemaRepository>()),
      fenix: true,
    );
  }
  if (!Get.isRegistered<GetTableSchemaByIdUseCase>()) {
    Get.lazyPut<GetTableSchemaByIdUseCase>(
      () => GetTableSchemaByIdUseCase(Get.find<TableSchemaRepository>()),
      fenix: true,
    );
  }
  if (!Get.isRegistered<GetAllTableSchemasUseCase>()) {
    Get.lazyPut<GetAllTableSchemasUseCase>(
      () => GetAllTableSchemasUseCase(Get.find<TableSchemaRepository>()),
      fenix: true,
    );
  }

  if (!Get.isRegistered<TableRowLocalDataSource>()) {
    Get.lazyPut<TableRowLocalDataSource>(
      () => TableRowLocalDataSourceImpl(Get.find<HiveService>()),
      fenix: true,
    );
  }
  if (!Get.isRegistered<TableRowRepository>()) {
    Get.lazyPut<TableRowRepository>(
      () => TableRowRepositoryImpl(Get.find<TableRowLocalDataSource>()),
      fenix: true,
    );
  }
  if (!Get.isRegistered<GetTableRowsUseCase>()) {
    Get.lazyPut<GetTableRowsUseCase>(
      () => GetTableRowsUseCase(Get.find<TableRowRepository>()),
      fenix: true,
    );
  }
  if (!Get.isRegistered<SaveTableRowUseCase>()) {
    Get.lazyPut<SaveTableRowUseCase>(
      () => SaveTableRowUseCase(Get.find<TableRowRepository>()),
      fenix: true,
    );
  }
  if (!Get.isRegistered<UpdateTableRowUseCase>()) {
    Get.lazyPut<UpdateTableRowUseCase>(
      () => UpdateTableRowUseCase(Get.find<TableRowRepository>()),
      fenix: true,
    );
  }
  if (!Get.isRegistered<DeleteTableRowUseCase>()) {
    Get.lazyPut<DeleteTableRowUseCase>(
      () => DeleteTableRowUseCase(Get.find<TableRowRepository>()),
      fenix: true,
    );
  }
  if (!Get.isRegistered<ApplyInventoryDeductionUseCase>()) {
    Get.lazyPut<ApplyInventoryDeductionUseCase>(
      () => ApplyInventoryDeductionUseCase(Get.find<TableRowRepository>()),
      fenix: true,
    );
  }
  if (!Get.isRegistered<ApplyAffectingTablesUseCase>()) {
    Get.lazyPut<ApplyAffectingTablesUseCase>(
      () => ApplyAffectingTablesUseCase(Get.find<TableRowRepository>()),
      fenix: true,
    );
  }

  if (!Get.isRegistered<BuilderWidgetLocalDataSource>()) {
    Get.lazyPut<BuilderWidgetLocalDataSource>(
      () => BuilderWidgetLocalDataSourceImpl(Get.find<HiveService>()),
      fenix: true,
    );
  }
  if (!Get.isRegistered<BuilderWidgetRepository>()) {
    Get.lazyPut<BuilderWidgetRepository>(
      () =>
          BuilderWidgetRepositoryImpl(Get.find<BuilderWidgetLocalDataSource>()),
      fenix: true,
    );
  }
  if (!Get.isRegistered<SaveBuilderWidgetUseCase>()) {
    Get.lazyPut<SaveBuilderWidgetUseCase>(
      () => SaveBuilderWidgetUseCase(Get.find<BuilderWidgetRepository>()),
      fenix: true,
    );
  }
  if (!Get.isRegistered<GetBuilderWidgetsByPageUseCase>()) {
    Get.lazyPut<GetBuilderWidgetsByPageUseCase>(
      () => GetBuilderWidgetsByPageUseCase(Get.find<BuilderWidgetRepository>()),
      fenix: true,
    );
  }
}
