/// Whether a table is a normal data table or a derived summary (aggregated) table.
enum TableKind {
  standard,
  summary;

  String get storageValue => name;

  static TableKind fromStorage(String? raw) {
    if (raw == TableKind.summary.name) {
      return TableKind.summary;
    }
    return TableKind.standard;
  }
}
