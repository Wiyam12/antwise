/// High-level list/table presentation design (separate from row delete UX).
enum TableListDesignLayout {
  contact,
  product,
  standard,
  ;

  static TableListDesignLayout fromStorage(String? value) {
    switch (value) {
      case 'contact':
        return TableListDesignLayout.contact;
      case 'product':
        return TableListDesignLayout.product;
      default:
        return TableListDesignLayout.standard;
    }
  }

  String get storageValue => switch (this) {
        TableListDesignLayout.contact => 'contact',
        TableListDesignLayout.product => 'product',
        TableListDesignLayout.standard => 'standard',
      };
}
