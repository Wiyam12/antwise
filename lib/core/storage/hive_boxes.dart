/// Keys inside Hive boxes (single-record stores use fixed keys).
abstract final class HiveKeys {
  static const String appSettings = 'app_settings';
}

abstract final class HiveBoxes {
  static const String pagesBox = 'pages_box';
  static const String widgetsBox = 'widgets_box';
  static const String tablesBox = 'tables_box';
  static const String rowsBox = 'rows_box';
  static const String navigationBox = 'navigation_box';
  static const String settingsBox = 'settings_box';
  static const String aiChatHistoryBox = 'ai_chat_history_box';
}
