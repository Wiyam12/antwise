import 'package:antwise/domain/entities/builder_widget_entity.dart';
import 'package:antwise/domain/entities/table_column_entity.dart';
import 'package:antwise/domain/entities/table_column_type.dart';
import 'package:antwise/domain/entities/table_row_entity.dart';
import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/domain/formula/table_formula_evaluator.dart';

/// Table/column labels in formulas must be quoted when they contain spaces or
/// other non-identifier characters; otherwise the lexer treats them as invalid
/// (e.g. `SUM(My Sales.Amount)` → syntax error).
String _formulaNameLiteral(String raw) {
  final String s = raw.trim().replaceAll('"', "'");
  return '"$s"';
}

/// Qualified `Table.Column` fragment for the formula engine (both sides quoted).
String _formulaQualifiedTableColumn(String tableName, String columnName) {
  return '${_formulaNameLiteral(tableName)}.${_formulaNameLiteral(columnName)}';
}

/// Builds the formula string used to render a card (user formula or derived from column).
String cardEffectiveDisplayFormula({
  required TableSchemaEntity table,
  required TableColumnEntity column,
  String? userFormula,
}) {
  final String trimmed = userFormula?.trim() ?? '';
  if (trimmed.isNotEmpty) {
    return trimmed;
  }
  final String qualified = _formulaQualifiedTableColumn(table.name, column.name);
  switch (column.type) {
    case TableColumnType.number:
    case TableColumnType.formula:
      return 'SUM($qualified)';
    default:
      return qualified;
  }
}

/// Resolves the single display string for a persisted card widget.
String computeCardWidgetDisplayValue({
  required BuilderWidgetEntity widget,
  required List<TableSchemaEntity> allSchemas,
  required Map<String, List<TableRowEntity>> rowsByTableId,
}) {
  if (widget.type != 'card') {
    return '';
  }
  final String? tableId = widget.config['tableId']?.toString();
  final String? columnId = widget.config['columnId']?.toString();
  if (tableId == null ||
      tableId.isEmpty ||
      columnId == null ||
      columnId.isEmpty) {
    return '—';
  }
  TableSchemaEntity? table;
  for (final TableSchemaEntity s in allSchemas) {
    if (s.id == tableId) {
      table = s;
      break;
    }
  }
  if (table == null) {
    return '—';
  }
  TableColumnEntity? column;
  for (final TableColumnEntity c in table.columns) {
    if (c.id == columnId) {
      column = c;
      break;
    }
  }
  if (column == null) {
    return '—';
  }
  final String? userFormula = widget.config['formula']?.toString();
  final String effective = cardEffectiveDisplayFormula(
    table: table,
    column: column,
    userFormula: userFormula,
  );
  return TableFormulaEvaluator.evaluate(
    formula: effective,
    currentSchema: table,
    workingRowByColId: const <String, dynamic>{},
    allSchemas: allSchemas,
    rowsByTableId: rowsByTableId,
    forColumnId: '_card',
  );
}
