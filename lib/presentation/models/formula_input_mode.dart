/// How a formula column composes and validates its expression in Create Table.
enum FormulaInputMode {
  /// Structured slots (IF, SUM, LOOKUP, etc.).
  guided,

  /// Free-typed expression with live autocomplete.
  textEditor,
}
