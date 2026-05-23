import 'package:antwise/core/storage/hive_boxes.dart';
import 'package:antwise/data/models/hive/ai_chat_message_hive_model.dart';
import 'package:antwise/data/models/hive/ai_chat_session_hive_model.dart';
import 'package:antwise/data/models/hive/app_settings_hive_model.dart';
import 'package:antwise/data/models/hive/builder_page_hive_model.dart';
import 'package:antwise/data/models/hive/builder_widget_hive_model.dart';
import 'package:antwise/data/models/hive/navigation_config_hive_model.dart';
import 'package:antwise/data/models/hive/table_row_hive_model.dart';
import 'package:antwise/data/models/hive/table_schema_hive_model.dart';
import 'package:hive/hive.dart';

class HiveService {
  Future<void> init() async {
    _registerAdapters();
    await _openBoxes();
  }

  Box<T> box<T>(String name) => Hive.box<T>(name);

  Future<void> put<T>(String boxName, dynamic key, T value) async {
    await box<T>(boxName).put(key, value);
  }

  T? get<T>(String boxName, dynamic key) {
    return box<T>(boxName).get(key);
  }

  Future<void> delete(String boxName, dynamic key) async {
    await Hive.box(boxName).delete(key);
  }

  Future<void> clear(String boxName) async {
    await Hive.box(boxName).clear();
  }

  void _registerAdapters() {
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(BuilderPageHiveModelAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(AppSettingsHiveModelAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(BuilderWidgetHiveModelAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(TableSchemaHiveModelAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(TableRowHiveModelAdapter());
    }
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(NavigationConfigHiveModelAdapter());
    }
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(AiChatMessageHiveModelAdapter());
    }
    if (!Hive.isAdapterRegistered(8)) {
      Hive.registerAdapter(AiChatSessionHiveModelAdapter());
    }
  }

  Future<void> _openBoxes() async {
    if (!Hive.isBoxOpen(HiveBoxes.pagesBox)) {
      await Hive.openBox<BuilderPageHiveModel>(HiveBoxes.pagesBox);
    }
    if (!Hive.isBoxOpen(HiveBoxes.widgetsBox)) {
      await Hive.openBox<BuilderWidgetHiveModel>(HiveBoxes.widgetsBox);
    }
    if (!Hive.isBoxOpen(HiveBoxes.tablesBox)) {
      await Hive.openBox<TableSchemaHiveModel>(HiveBoxes.tablesBox);
    }
    if (!Hive.isBoxOpen(HiveBoxes.rowsBox)) {
      await Hive.openBox<TableRowHiveModel>(HiveBoxes.rowsBox);
    }
    if (!Hive.isBoxOpen(HiveBoxes.navigationBox)) {
      await Hive.openBox<NavigationConfigHiveModel>(HiveBoxes.navigationBox);
    }
    if (!Hive.isBoxOpen(HiveBoxes.settingsBox)) {
      await Hive.openBox<AppSettingsHiveModel>(HiveBoxes.settingsBox);
    }
    if (!Hive.isBoxOpen(HiveBoxes.aiChatHistoryBox)) {
      await Hive.openBox<AiChatSessionHiveModel>(HiveBoxes.aiChatHistoryBox);
    }
  }
}
