enum TableDataLoadingMode {
  lazy,
  pagination;

  static TableDataLoadingMode fromStorage(String? value) {
    return value == 'pagination'
        ? TableDataLoadingMode.pagination
        : TableDataLoadingMode.lazy;
  }

  String get storageValue => switch (this) {
    TableDataLoadingMode.lazy => 'lazy',
    TableDataLoadingMode.pagination => 'pagination',
  };
}
