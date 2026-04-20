/// Visual layout preset for builder `card` widgets.
enum CardWidgetLayout {
  simple,
  info,
  kpi;

  String get storageValue => name;

  static CardWidgetLayout fromStorage(String? raw) {
    return switch (raw) {
      'info' => CardWidgetLayout.info,
      'kpi' => CardWidgetLayout.kpi,
      _ => CardWidgetLayout.simple,
    };
  }
}
