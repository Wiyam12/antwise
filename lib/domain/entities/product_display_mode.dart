enum ProductDisplayMode {
  list,
  grid,
  ;

  static ProductDisplayMode fromStorage(String? value) {
    return value == 'grid' ? ProductDisplayMode.grid : ProductDisplayMode.list;
  }

  String get storageValue => switch (this) {
        ProductDisplayMode.list => 'list',
        ProductDisplayMode.grid => 'grid',
      };
}
