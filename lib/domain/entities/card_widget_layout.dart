/// Visual layout preset for builder `card` widgets.
enum CardWidgetLayout {
  simple,
  info,
  kpi,
  customizable,
  hero,
  percent;

  String get storageValue => name;

  static CardWidgetLayout fromStorage(String? raw) {
    return switch (raw) {
      'info' => CardWidgetLayout.info,
      'kpi' => CardWidgetLayout.kpi,
      'customizable' => CardWidgetLayout.customizable,
      'hero' => CardWidgetLayout.hero,
      'percent' => CardWidgetLayout.percent,
      _ => CardWidgetLayout.simple,
    };
  }
}
