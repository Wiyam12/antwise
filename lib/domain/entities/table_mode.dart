enum TableMode {
  crud,
  readOnly,
  ;

  static TableMode fromStorage(String value) {
    return value == 'readOnly' ? TableMode.readOnly : TableMode.crud;
  }

  String get storageValue => switch (this) {
    TableMode.crud => 'crud',
    TableMode.readOnly => 'readOnly',
  };
}
