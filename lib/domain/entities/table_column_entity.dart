import 'package:antwise/domain/entities/table_column_dropdown_source.dart';
import 'package:antwise/domain/entities/table_column_type.dart';

class TableColumnEntity {
  const TableColumnEntity({
    required this.id,
    required this.name,
    required this.type,
    this.includeInCreateForm = true,
    this.includeInEditForm = true,
    this.isRequired = false,
    this.isUnique = false,
    this.pattern,
    this.formula,
    this.formulaDefinition,
    this.dropdownOptions = const <String>[],
    this.dropdownSourceKind = TableColumnDropdownSourceKind.manual,
    this.dropdownSourceTableId,
    this.dropdownSourceColumnId,
  });

  final String id;
  final String name;
  final TableColumnType type;
  final bool includeInCreateForm;
  final bool includeInEditForm;
  final bool isRequired;
  final bool isUnique;
  final String? pattern;
  final String? formula;

  /// Optional structured guided-formula tree (IF slots, nested formulas, etc.).
  /// The composed expression is still stored in [formula] for evaluation.
  final Map<String, dynamic>? formulaDefinition;

  final List<String> dropdownOptions;

  /// When [type] is [TableColumnType.dropdown]: manual list vs values from another table column.
  final TableColumnDropdownSourceKind dropdownSourceKind;

  /// Source table id when [dropdownSourceKind] is [TableColumnDropdownSourceKind.table].
  final String? dropdownSourceTableId;

  /// Source column id on [dropdownSourceTableId] when using table-driven options.
  final String? dropdownSourceColumnId;
}
