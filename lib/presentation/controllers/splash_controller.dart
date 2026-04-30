import 'dart:convert';
import 'dart:io';

import 'package:antwise/core/services/logger_service.dart';
import 'package:antwise/core/storage/hive_boxes.dart';
import 'package:antwise/data/models/hive/builder_page_hive_model.dart';
import 'package:antwise/data/models/hive/builder_widget_hive_model.dart';
import 'package:antwise/data/models/hive/navigation_config_hive_model.dart';
import 'package:antwise/data/models/hive/table_schema_hive_model.dart';
import 'package:antwise/domain/usecases/check_resources_downloaded_usecase.dart';
import 'package:antwise/presentation/routes/app_routes.dart';
import 'package:flutter/scheduler.dart';
import 'package:hive/hive.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

/// Runs startup checks and routes to download flow or home.
class SplashController extends GetxController {
  SplashController(this._checkResourcesDownloaded);

  final CheckResourcesDownloadedUseCase _checkResourcesDownloaded;

  /// Shown on splash while waiting for minimum display; 0 = countdown finished.
  final RxInt splashSecondsLeft = 0.obs;

  static const Duration _minDisplayDuration = Duration(seconds: 2);
  static const Duration _checkTimeout = Duration(seconds: 8);

  @override
  void onInit() {
    super.onInit();
    // Ensures the navigator is mounted before [Get.offAllNamed] (avoids stuck splash).
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _runFlow();
    });
  }

  Future<void> _runFlow() async {
    try {
      final Future<bool> checkFuture = _safeCheck();
      final Future<void> minDisplayFuture = _runSplashCountdown();

      final bool downloaded = await checkFuture;
      await minDisplayFuture;
      // await _writeStartupSnapshotJsonFile();

      if (downloaded) {
        Get.offAllNamed<void>(AppRoutes.home);
      } else {
        Get.offAllNamed<void>(AppRoutes.downloadResources);
      }
    } catch (e, st) {
      if (Get.isRegistered<LoggerService>()) {
        Get.find<LoggerService>().d('Splash navigation failed', e, st);
      }
      Get.offAllNamed<void>(AppRoutes.downloadResources);
    }
  }

  Future<bool> _safeCheck() async {
    try {
      return await _checkResourcesDownloaded().timeout(_checkTimeout);
    } catch (e, st) {
      if (Get.isRegistered<LoggerService>()) {
        Get.find<LoggerService>().d('Splash resource check failed', e, st);
      }
      return false;
    }
  }

  Future<void> _runSplashCountdown() async {
    final int totalSeconds = _minDisplayDuration.inSeconds;
    if (totalSeconds <= 0) {
      return;
    }
    for (int s = totalSeconds; s > 0; s--) {
      splashSecondsLeft.value = s;
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    splashSecondsLeft.value = 0;
  }

  Future<void> _writeStartupSnapshotJsonFile() async {
    final List<Map<String, dynamic>> pages = <Map<String, dynamic>>[];
    if (Hive.isBoxOpen(HiveBoxes.pagesBox)) {
      final Box<BuilderPageHiveModel> pagesBox = Hive.box<BuilderPageHiveModel>(
        HiveBoxes.pagesBox,
      );
      pages.addAll(
        pagesBox.values.map((BuilderPageHiveModel page) {
          return <String, dynamic>{
            'id': page.id,
            'name': page.name,
            'icon': page.icon,
            'navigationType': page.navigationType,
            'isDeleted': page.isDeleted,
            'isDrawerParentContainer': page.isDrawerParentContainer,
            'parentPageId': page.parentPageId,
            'nestedDisplayType': page.nestedDisplayType,
            'nestedRootContentTabName': page.nestedRootContentTabName,
            'widgetGridCount': page.widgetGridCount,
            'layoutOrder': page.layoutOrder,
            'widgetOrder': page.widgetOrder,
          };
        }),
      );
    }

    final List<Map<String, dynamic>> tables = <Map<String, dynamic>>[];
    if (Hive.isBoxOpen(HiveBoxes.tablesBox)) {
      final Box<TableSchemaHiveModel> tablesBox =
          Hive.box<TableSchemaHiveModel>(HiveBoxes.tablesBox);
      tables.addAll(
        tablesBox.values.map((TableSchemaHiveModel schema) {
          return <String, dynamic>{
            'id': schema.id,
            'pageId': schema.pageId,
            'name': schema.name,
            'description': schema.description,
            'mode': schema.mode,
            'layoutType': schema.layoutType,
            'listDesignLayout': schema.listDesignLayout,
            'swipeToDelete': schema.swipeToDelete,
            'productDisplayMode': schema.productDisplayMode,
            'tableKind': schema.tableKind,
            'summaryConfig': _jsonSafe(schema.summaryConfig),
            'inventoryDeduction': _jsonSafe(schema.inventoryDeduction),
            'affectingTables': _jsonSafe(schema.affectingTables),
            'validationRules': _jsonSafe(schema.validationRules),
            'searchEnabled': schema.searchEnabled,
            'dataLoadingMode': schema.dataLoadingMode,
            'pageSize': schema.pageSize,
            'lazyInitialLoad': schema.lazyInitialLoad,
            'columns': schema.columns
                .map((Map<String, dynamic> col) => _jsonSafe(col))
                .toList(growable: false),
          };
        }),
      );
    }

    final List<Map<String, dynamic>> widgets = <Map<String, dynamic>>[];
    if (Hive.isBoxOpen(HiveBoxes.widgetsBox)) {
      final Box<BuilderWidgetHiveModel> widgetsBox =
          Hive.box<BuilderWidgetHiveModel>(HiveBoxes.widgetsBox);
      widgets.addAll(
        widgetsBox.values.map((BuilderWidgetHiveModel widget) {
          return <String, dynamic>{
            'id': widget.id,
            'pageId': widget.pageId,
            'type': widget.type,
            'config': _jsonSafe(widget.config),
          };
        }),
      );
    }

    final Map<String, dynamic> navigation = <String, dynamic>{};
    if (Hive.isBoxOpen(HiveBoxes.navigationBox)) {
      final Box<NavigationConfigHiveModel> box =
          Hive.box<NavigationConfigHiveModel>(HiveBoxes.navigationBox);
      if (box.isNotEmpty) {
        final NavigationConfigHiveModel first = box.values.first;
        navigation.addAll(<String, dynamic>{
          'bottomPageIds': first.bottomPageIds,
          'drawerPageIds': first.drawerPageIds,
          'activePageId': first.activePageId,
          'mainPageId': first.mainPageId,
          'bottomNavLayout': first.bottomNavLayout,
          'bottomNavCenterPageId': first.bottomNavCenterPageId,
          'bottomNavShowLabels': first.bottomNavShowLabels,
          'drawerNavLayout': first.drawerNavLayout,
          // Additional grouped metadata for richer restore while staying compatible.
          'bottomNav': <String, dynamic>{
            'layoutType': first.bottomNavLayout,
            'layoutOptionId': first.bottomNavLayout,
            'centerPageId': first.bottomNavCenterPageId,
            'showLabels': first.bottomNavShowLabels,
            'displayConfig': <String, dynamic>{
              'showLabels': first.bottomNavShowLabels,
              'centerPageId': first.bottomNavCenterPageId,
            },
          },
          'drawerNav': <String, dynamic>{
            'layoutType': first.drawerNavLayout,
            'layoutOptionId': first.drawerNavLayout,
            'displayConfig': <String, dynamic>{},
          },
        });
      }
    }

    final Map<String, dynamic> snapshot = <String, dynamic>{
      'event': 'startup_snapshot',
      'schemaVersion': 2,
      'counts': <String, dynamic>{
        'pages': pages.length,
        'tables': tables.length,
        'widgets': widgets.length,
      },
      'pages': pages,
      'tables': tables,
      'widgets': widgets,
      'navigation': navigation,
    };

    final Directory directory = await getApplicationDocumentsDirectory();
    final String timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final File file = File(
      '${directory.path}/startup_snapshot_$timestamp.json',
    );
    const JsonEncoder pretty = JsonEncoder.withIndent('  ');
    await file.writeAsString(pretty.convert(snapshot), flush: true);
    if (Get.isRegistered<LoggerService>()) {
      Get.find<LoggerService>().d(
        'Startup snapshot JSON saved to ${file.path}',
      );
    }
  }

  dynamic _jsonSafe(dynamic value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is List) {
      return value.map(_jsonSafe).toList(growable: false);
    }
    if (value is Map) {
      return value.map<String, dynamic>(
        (dynamic key, dynamic mapValue) =>
            MapEntry<String, dynamic>(key.toString(), _jsonSafe(mapValue)),
      );
    }
    return value.toString();
  }
}
