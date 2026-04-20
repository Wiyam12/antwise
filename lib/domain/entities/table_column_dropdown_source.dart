/// How a [TableColumnType.dropdown] column obtains its selectable values.
enum TableColumnDropdownSourceKind {
  manual,
  table,
  ;

  static TableColumnDropdownSourceKind fromStorage(String? raw) {
    if (raw == 'table') {
      return TableColumnDropdownSourceKind.table;
    }
    return TableColumnDropdownSourceKind.manual;
  }

  String get storageValue => switch (this) {
        TableColumnDropdownSourceKind.manual => 'manual',
        TableColumnDropdownSourceKind.table => 'table',
      };
}
