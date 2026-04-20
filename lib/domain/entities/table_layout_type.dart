enum TableLayoutType {
  vertical,
  swipe,
  ;

  static TableLayoutType fromStorage(String? value) {
    return value == 'swipe' ? TableLayoutType.swipe : TableLayoutType.vertical;
  }

  String get storageValue => switch (this) {
    TableLayoutType.vertical => 'vertical',
    TableLayoutType.swipe => 'swipe',
  };
}
