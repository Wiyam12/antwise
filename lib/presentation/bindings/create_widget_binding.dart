import 'package:antwise/core/storage/hive_service.dart';
import 'package:antwise/data/datasources/builder_pages_local_datasource.dart';
import 'package:antwise/data/datasources/builder_widget_local_datasource.dart';
import 'package:antwise/data/datasources/table_row_local_datasource.dart';
import 'package:antwise/data/datasources/table_schema_local_datasource.dart';
import 'package:antwise/data/repositories/builder_pages_repository_impl.dart';
import 'package:antwise/data/repositories/builder_widget_repository_impl.dart';
import 'package:antwise/data/repositories/table_row_repository_impl.dart';
import 'package:antwise/data/repositories/table_schema_repository_impl.dart';
import 'package:antwise/domain/repositories/builder_pages_repository.dart';
import 'package:antwise/domain/repositories/builder_widget_repository.dart';
import 'package:antwise/domain/repositories/table_row_repository.dart';
import 'package:antwise/domain/repositories/table_schema_repository.dart';
import 'package:antwise/domain/usecases/get_all_table_schemas_usecase.dart';
import 'package:antwise/domain/usecases/get_all_builder_widgets_usecase.dart';
import 'package:antwise/domain/usecases/get_builder_pages_usecase.dart';
import 'package:antwise/domain/usecases/get_builder_widgets_by_page_usecase.dart';
import 'package:antwise/domain/usecases/get_table_rows_usecase.dart';
import 'package:antwise/domain/usecases/save_builder_widget_usecase.dart';
import 'package:antwise/presentation/controllers/create_widget_controller.dart';
import 'package:get/get.dart';

class CreateWidgetBinding extends Bindings {
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

    if (!Get.isRegistered<BuilderWidgetLocalDataSource>()) {
      Get.lazyPut<BuilderWidgetLocalDataSource>(
        () => BuilderWidgetLocalDataSourceImpl(Get.find<HiveService>()),
      );
    }
    if (!Get.isRegistered<BuilderWidgetRepository>()) {
      Get.lazyPut<BuilderWidgetRepository>(
        () => BuilderWidgetRepositoryImpl(
          Get.find<BuilderWidgetLocalDataSource>(),
        ),
      );
    }
    if (!Get.isRegistered<SaveBuilderWidgetUseCase>()) {
      Get.lazyPut<SaveBuilderWidgetUseCase>(
        () => SaveBuilderWidgetUseCase(Get.find<BuilderWidgetRepository>()),
      );
    }
    if (!Get.isRegistered<GetBuilderWidgetsByPageUseCase>()) {
      Get.lazyPut<GetBuilderWidgetsByPageUseCase>(
        () => GetBuilderWidgetsByPageUseCase(
          Get.find<BuilderWidgetRepository>(),
        ),
      );
    }
    if (!Get.isRegistered<GetAllBuilderWidgetsUseCase>()) {
      Get.lazyPut<GetAllBuilderWidgetsUseCase>(
        () => GetAllBuilderWidgetsUseCase(Get.find<BuilderWidgetRepository>()),
      );
    }

    Get.lazyPut<CreateWidgetController>(
      () => CreateWidgetController(
        Get.find<GetBuilderPagesUseCase>(),
        Get.find<SaveBuilderWidgetUseCase>(),
        Get.find<GetAllTableSchemasUseCase>(),
        Get.find<GetBuilderWidgetsByPageUseCase>(),
        Get.find<GetAllBuilderWidgetsUseCase>(),
        Get.find<GetTableRowsUseCase>(),
      ),
    );
  }
}
