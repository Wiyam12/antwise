/// Formula kinds supported by the guided (no-code) formula builder.
enum GuidedFormulaKind {
  expression,
  lookup,
  ifelse,
  sum,
  count,
  avg,
}

extension GuidedFormulaKindLabels on GuidedFormulaKind {
  String get builderLabel => switch (this) {
        GuidedFormulaKind.expression => 'Expression',
        GuidedFormulaKind.lookup => 'LOOKUP',
        GuidedFormulaKind.ifelse => 'IF',
        GuidedFormulaKind.sum => 'SUM',
        GuidedFormulaKind.count => 'COUNT',
        GuidedFormulaKind.avg => 'AVG',
      };
}
