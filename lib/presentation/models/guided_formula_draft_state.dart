import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/domain/entities/table_column_entity.dart';
import 'package:antwise/domain/formula/guided_formula_kind.dart';
import 'package:antwise/domain/validation/table_formula_validator.dart';
import 'package:antwise/presentation/models/arithmetic_expression_formula.dart';
import 'package:antwise/presentation/models/formula_value_slot.dart';
import 'package:antwise/presentation/models/guided_formula_host.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Shared guided (chip-based) formula state for create-table and edit-table drafts.
class GuidedFormulaDraftState {
  static const int maxFormulaNestDepth = 10;

  GuidedFormulaDraftState({this.enableConnectorChain = true});

  /// When false, this draft cannot host a [connectorTail] (avoids infinite recursion).
  final bool enableConnectorChain;

  final Rxn<GuidedFormulaKind> guidedFormulaKind = Rxn<GuidedFormulaKind>();

  final RxnString lookupTableSchemaId = RxnString();
  final TextEditingController lookupLookupColumnController =
      TextEditingController();
  final TextEditingController lookupReturnColumnController =
      TextEditingController();

  /// First LOOKUP argument: manual value, sibling column, or nested formula.
  final FormulaValueSlot lookupKeySlot = FormulaValueSlot();

  final RxString ifOperator = '='.obs;
  final FormulaValueSlot ifConditionLeft = FormulaValueSlot();
  final FormulaValueSlot ifConditionRight = FormulaValueSlot();
  final FormulaValueSlot ifTrueSlot = FormulaValueSlot();
  final FormulaValueSlot ifFalseSlot = FormulaValueSlot();

  final RxnString aggregateTableSchemaId = RxnString();
  final TextEditingController aggregateColumnController =
      TextEditingController();

  /// Token tags for [GuidedFormulaKind.expression] (see [ArithmeticExpressionFormula]).
  final RxList<String> expressionTokens = <String>[].obs;
  final RxnString expressionSourceTableId = RxnString();
  final TextEditingController expressionSourceColumnController =
      TextEditingController();

  final TextEditingController expressionNumberController =
      TextEditingController();

  /// Root only: optional second guided segment joined with [connectorOperator].
  final RxBool connectorEnabled = false.obs;
  final RxString connectorOperator = '+'.obs;
  static const List<String> connectorOperatorsAllowed = <String>[
    '+',
    '-',
    '*',
    '/',
  ];
  GuidedFormulaDraftState? _connectorTail;

  /// Optional second segment (root drafts only; lazily allocated).
  GuidedFormulaDraftState get connectorTail {
    if (!enableConnectorChain) {
      throw StateError(
        'connectorTail is only available on the root formula draft.',
      );
    }
    return _connectorTail ??=
        GuidedFormulaDraftState(enableConnectorChain: false);
  }

  static const List<String> ifOperatorsAllowed = <String>[
    '>',
    '<',
    '=',
    '>=',
    '<=',
    '!=',
  ];

  void clearGuidedFormulaBuilder() {
    guidedFormulaKind.value = null;
    lookupTableSchemaId.value = null;
    lookupLookupColumnController.clear();
    lookupReturnColumnController.clear();
    lookupKeySlot.clear();
    ifOperator.value = '=';
    ifConditionLeft.clear();
    ifConditionRight.clear();
    ifTrueSlot.clear();
    ifFalseSlot.clear();
    aggregateTableSchemaId.value = null;
    aggregateColumnController.clear();
    expressionTokens.clear();
    expressionSourceTableId.value = null;
    expressionSourceColumnController.clear();
    expressionNumberController.clear();
    if (enableConnectorChain) {
      connectorEnabled.value = false;
      connectorOperator.value = '+';
      _connectorTail?.clearGuidedFormulaBuilder();
      _connectorTail?.dispose();
      _connectorTail = null;
    }
  }

  /// Field-level errors keyed by stable ids: `kind`, `lookupTable`, …
  Map<String, String> validateGuided(
    List<TableSchemaEntity> schemas,
    List<GuidedFormulaColumnLike> siblings,
    String currentColumnId, {
    required List<ColumnNameDraft> formulaColumnNames,
    int nestDepth = 0,
  }) {
    final Map<String, String> e = <String, String>{};
    if (nestDepth > maxFormulaNestDepth) {
      e['kind'] = 'Too many nested formulas.';
      return e;
    }
    final GuidedFormulaKind? k = guidedFormulaKind.value;
    if (k == null) {
      e['kind'] = 'Select a formula type.';
      return e;
    }

    TableSchemaEntity? schemaById(String? sid) {
      if (sid == null) {
        return null;
      }
      for (final TableSchemaEntity s in schemas) {
        if (s.id == sid) {
          return s;
        }
      }
      return null;
    }

    String? siblingName(String? sid) {
      if (sid == null) {
        return null;
      }
      for (final GuidedFormulaColumnLike c in siblings) {
        if (c.id == sid) {
          return c.nameController.text.trim();
        }
      }
      return null;
    }

    switch (k) {
      case GuidedFormulaKind.expression:
        final String? struct =
            ArithmeticExpressionFormula.validateTagStructure(expressionTokens);
        if (struct != null) {
          e['expression'] = struct;
          break;
        }
        for (final String tag in expressionTokens) {
          if (tag.startsWith(ArithmeticExpressionFormula.prefixColumn)) {
            final String id =
                tag.substring(ArithmeticExpressionFormula.prefixColumn.length);
            if (siblingName(id) == null || siblingName(id)!.isEmpty) {
              e['expression'] =
                  'Each column token must refer to a named column on this table.';
              break;
            }
          } else if (tag.startsWith(ArithmeticExpressionFormula.prefixTableColumn)) {
            final String payload = tag.substring(
              ArithmeticExpressionFormula.prefixTableColumn.length,
            );
            final int sep = payload.indexOf('::');
            if (sep <= 0 || sep >= payload.length - 2) {
              e['expression'] = 'Invalid external column token.';
              break;
            }
            final String tableId = payload.substring(0, sep).trim();
            final String colName = payload.substring(sep + 2).trim();
            final TableSchemaEntity? table = schemaById(tableId);
            if (table == null) {
              e['expression'] = 'Referenced table does not exist.';
              break;
            }
            if (!table.columns.any((c) => c.name.trim() == colName)) {
              e['expression'] = 'Referenced column does not exist.';
              break;
            }
          } else if (tag.startsWith(ArithmeticExpressionFormula.prefixNumber)) {
            final String raw =
                tag.substring(ArithmeticExpressionFormula.prefixNumber.length);
            final String t = raw.trim();
            if (t.isEmpty || double.tryParse(t) == null) {
              e['expression'] = 'Invalid number in expression.';
              break;
            }
          }
        }
        if (e.isNotEmpty) {
          break;
        }
        final String composed = ArithmeticExpressionFormula.compose(
          expressionTokens.toList(growable: false),
          siblings,
          schemas,
        );
        if (composed.trim().isEmpty) {
          e['expression'] = 'Formula is empty.';
          break;
        }
        if (TableFormulaValidator.hasObviousDivisionByZero(composed)) {
          e['expression'] = 'Division by zero is not allowed.';
          break;
        }
        final String? syntax = TableFormulaValidator.validate(
          formula: composed,
          currentColumnId: currentColumnId,
          siblingColumns: formulaColumnNames,
          existingTables: schemas,
        );
        if (syntax != null) {
          e['expression'] = 'Invalid arithmetic formula.';
        }
        break;
      case GuidedFormulaKind.lookup:
        final String? tid = lookupTableSchemaId.value;
        final TableSchemaEntity? table = schemaById(tid);
        if (tid == null || table == null) {
          e['lookupTable'] = 'Select a source table.';
        }
        final String lk = lookupLookupColumnController.text.trim();
        final String rk = lookupReturnColumnController.text.trim();
        if (lk.isEmpty) {
          e['lookupLookupCol'] = 'Lookup column is required.';
        } else if (table != null &&
            !table.columns.any((c) => c.name.trim() == lk)) {
          e['lookupLookupCol'] = 'Referenced column does not exist.';
        }
        if (rk.isEmpty) {
          e['lookupReturnCol'] = 'Return column is required.';
        } else if (table != null &&
            !table.columns.any((c) => c.name.trim() == rk)) {
          e['lookupReturnCol'] = 'Referenced column does not exist.';
        }
        _collectSlotErrors(
          slot: lookupKeySlot,
          errorKeyPrefix: 'lookupKey',
          errorsOut: e,
          schemas: schemas,
          siblings: siblings,
          currentColumnId: currentColumnId,
          formulaColumnNames: formulaColumnNames,
          nestDepth: nestDepth,
        );
        break;
      case GuidedFormulaKind.ifelse:
        _collectSlotErrors(
          slot: ifConditionLeft,
          errorKeyPrefix: 'ifLeft',
          errorsOut: e,
          schemas: schemas,
          siblings: siblings,
          currentColumnId: currentColumnId,
          formulaColumnNames: formulaColumnNames,
          nestDepth: nestDepth,
        );
        if (!ifOperatorsAllowed.contains(ifOperator.value)) {
          e['ifOp'] = 'Unsupported operator.';
        }
        _collectSlotErrors(
          slot: ifConditionRight,
          errorKeyPrefix: 'ifRight',
          errorsOut: e,
          schemas: schemas,
          siblings: siblings,
          currentColumnId: currentColumnId,
          formulaColumnNames: formulaColumnNames,
          nestDepth: nestDepth,
        );
        _collectSlotErrors(
          slot: ifTrueSlot,
          errorKeyPrefix: 'ifTrue',
          errorsOut: e,
          schemas: schemas,
          siblings: siblings,
          currentColumnId: currentColumnId,
          formulaColumnNames: formulaColumnNames,
          nestDepth: nestDepth,
        );
        _collectSlotErrors(
          slot: ifFalseSlot,
          errorKeyPrefix: 'ifFalse',
          errorsOut: e,
          schemas: schemas,
          siblings: siblings,
          currentColumnId: currentColumnId,
          formulaColumnNames: formulaColumnNames,
          nestDepth: nestDepth,
        );
        break;
      case GuidedFormulaKind.sum:
      case GuidedFormulaKind.count:
      case GuidedFormulaKind.avg:
        final String? aid = aggregateTableSchemaId.value;
        final TableSchemaEntity? at = schemaById(aid);
        if (aid == null || at == null) {
          e['aggTable'] = 'Select a table.';
        }
        final String ac = aggregateColumnController.text.trim();
        if (ac.isEmpty) {
          e['aggCol'] = 'Column is required.';
        } else if (at != null && !at.columns.any((c) => c.name.trim() == ac)) {
          e['aggCol'] = 'Referenced column does not exist.';
        }
        break;
    }
    if (nestDepth == 0 &&
        enableConnectorChain &&
        connectorEnabled.value) {
      if (connectorTail.guidedFormulaKind.value == null) {
        e['connector.kind'] = 'Select a formula type for the connected part.';
      } else {
        final Map<String, String> tailErrors = connectorTail.validateGuided(
          schemas,
          siblings,
          currentColumnId,
          formulaColumnNames: formulaColumnNames,
          nestDepth: 0,
        );
        for (final MapEntry<String, String> x in tailErrors.entries) {
          e['connector.${x.key}'] = x.value;
        }
      }
    }
    return e;
  }

  void _collectSlotErrors({
    required FormulaValueSlot slot,
    required String errorKeyPrefix,
    required Map<String, String> errorsOut,
    required List<TableSchemaEntity> schemas,
    required List<GuidedFormulaColumnLike> siblings,
    required String currentColumnId,
    required List<ColumnNameDraft> formulaColumnNames,
    required int nestDepth,
  }) {
    String? siblingNameLocal(String? sid) {
      if (sid == null) {
        return null;
      }
      for (final GuidedFormulaColumnLike c in siblings) {
        if (c.id == sid) {
          return c.nameController.text.trim();
        }
      }
      return null;
    }

    switch (slot.source.value) {
      case FormulaSlotSourceKind.manual:
        if (slot.manualController.text.trim().isEmpty) {
          errorsOut[errorKeyPrefix] = 'Value is required.';
        }
        return;
      case FormulaSlotSourceKind.siblingColumn:
        final String? sid = slot.siblingColumnId.value;
        final String? n = siblingNameLocal(sid);
        if (sid == null || n == null || n.isEmpty) {
          errorsOut[errorKeyPrefix] = 'Select a column.';
        } else if (sid == currentColumnId) {
          errorsOut[errorKeyPrefix] = 'Referenced column does not exist.';
        }
        return;
      case FormulaSlotSourceKind.tableColumn:
        final String? tid = slot.tableSchemaId.value;
        final String col = slot.tableColumnController.text.trim();
        if (tid == null) {
          errorsOut[errorKeyPrefix] = 'Select a table.';
          return;
        }
        TableSchemaEntity? table;
        for (final TableSchemaEntity s in schemas) {
          if (s.id == tid) {
            table = s;
            break;
          }
        }
        if (table == null) {
          errorsOut[errorKeyPrefix] = 'Referenced table does not exist.';
          return;
        }
        if (col.isEmpty) {
          errorsOut[errorKeyPrefix] = 'Select a column.';
          return;
        }
        if (!table.columns.any((TableColumnEntity c) => c.name.trim() == col)) {
          errorsOut[errorKeyPrefix] = 'Referenced column does not exist.';
        }
        return;
      case FormulaSlotSourceKind.nested:
        if (slot.nested.guidedFormulaKind.value == null) {
          errorsOut[errorKeyPrefix] = 'Pick a nested formula type.';
          return;
        }
        final Map<String, String> inner = slot.nested.validateGuided(
          schemas,
          siblings,
          currentColumnId,
          formulaColumnNames: formulaColumnNames,
          nestDepth: nestDepth + 1,
        );
        for (final MapEntry<String, String> x in inner.entries) {
          errorsOut['$errorKeyPrefix.nested.${x.key}'] = x.value;
        }
        return;
    }
  }

  String? _composeSlot(
    FormulaValueSlot slot,
    List<TableSchemaEntity> schemas,
    List<GuidedFormulaColumnLike> siblings,
    String currentColumnId,
    List<ColumnNameDraft> formulaColumnNames,
  ) {
    String siblingNameLocal(String sid) {
      for (final GuidedFormulaColumnLike c in siblings) {
        if (c.id == sid) {
          return c.nameController.text.trim();
        }
      }
      return '';
    }

    switch (slot.source.value) {
      case FormulaSlotSourceKind.manual:
        return _atomLiteral(slot.manualController.text.trim());
      case FormulaSlotSourceKind.siblingColumn:
        final String? sid = slot.siblingColumnId.value;
        if (sid == null) {
          return null;
        }
        final String n = siblingNameLocal(sid);
        if (n.isEmpty) {
          return null;
        }
        return _atomIdentOrQuoted(n);
      case FormulaSlotSourceKind.tableColumn:
        final String? tid = slot.tableSchemaId.value;
        final String col = slot.tableColumnController.text.trim();
        if (tid == null || col.isEmpty) {
          return null;
        }
        TableSchemaEntity? table;
        for (final TableSchemaEntity s in schemas) {
          if (s.id == tid) {
            table = s;
            break;
          }
        }
        if (table == null) {
          return null;
        }
        return '${_atomIdentOrQuoted(table.name.trim())}.${_atomIdentOrQuoted(col)}';
      case FormulaSlotSourceKind.nested:
        return slot.nested.composeGuidedFormula(
          schemas,
          siblings,
          currentColumnId,
          formulaColumnNames,
        );
    }
  }

  String _previewSlot(
    FormulaValueSlot slot,
    List<TableSchemaEntity> schemas,
    List<GuidedFormulaColumnLike> siblings,
    String currentColumnId,
    List<ColumnNameDraft> formulaColumnNames,
  ) {
    final String? c = _composeSlot(
      slot,
      schemas,
      siblings,
      currentColumnId,
      formulaColumnNames,
    );
    if (c == null || c.trim().isEmpty || c == '""') {
      return '?';
    }
    return c;
  }

  String _previewPrimaryFormula(
    List<TableSchemaEntity> schemas,
    List<GuidedFormulaColumnLike> siblings, {
    required String currentColumnId,
    required List<ColumnNameDraft> formulaColumnNames,
  }) {
    final GuidedFormulaKind? k = guidedFormulaKind.value;
    if (k == null) {
      return '';
    }

    TableSchemaEntity? schemaById(String? sid) {
      if (sid == null) {
        return null;
      }
      for (final TableSchemaEntity s in schemas) {
        if (s.id == sid) {
          return s;
        }
      }
      return null;
    }

    String ph(String raw) {
      final String t = raw.trim();
      return t.isEmpty ? '?' : t;
    }

    switch (k) {
      case GuidedFormulaKind.expression:
        if (expressionTokens.isEmpty) {
          return '';
        }
        return ArithmeticExpressionFormula.compose(
          expressionTokens.toList(growable: false),
          siblings,
          schemas,
        );
      case GuidedFormulaKind.lookup:
        final TableSchemaEntity? table = schemaById(lookupTableSchemaId.value);
        final String tn = ph(table?.name ?? '');
        final String lk = ph(lookupLookupColumnController.text);
        final String rk = ph(lookupReturnColumnController.text);
        final String valueExpr = _previewSlot(
          lookupKeySlot,
          schemas,
          siblings,
          currentColumnId,
          formulaColumnNames,
        );
        return 'LOOKUP($valueExpr, ${_atomIdentOrQuoted(tn)}, ${_atomIdentOrQuoted(lk)}, ${_atomIdentOrQuoted(rk)})';
      case GuidedFormulaKind.ifelse:
        final String condLeft = _previewSlot(
          ifConditionLeft,
          schemas,
          siblings,
          currentColumnId,
          formulaColumnNames,
        );
        final String op = ifOperator.value;
        final String cmpAtom = _previewSlot(
          ifConditionRight,
          schemas,
          siblings,
          currentColumnId,
          formulaColumnNames,
        );
        final String tAtom = _previewSlot(
          ifTrueSlot,
          schemas,
          siblings,
          currentColumnId,
          formulaColumnNames,
        );
        final String fAtom = _previewSlot(
          ifFalseSlot,
          schemas,
          siblings,
          currentColumnId,
          formulaColumnNames,
        );
        return 'IF($condLeft $op $cmpAtom, $tAtom, $fAtom)';
      case GuidedFormulaKind.sum:
        return _previewAggregate('SUM', schemas);
      case GuidedFormulaKind.count:
        return _previewAggregate('COUNT', schemas);
      case GuidedFormulaKind.avg:
        return _previewAggregate('AVG', schemas);
    }
  }

  String guidedFormulaPreview(
    List<TableSchemaEntity> schemas,
    List<GuidedFormulaColumnLike> siblings, {
    String currentColumnId = '',
    List<ColumnNameDraft> formulaColumnNames = const <ColumnNameDraft>[],
  }) {
    final String primary = _previewPrimaryFormula(
      schemas,
      siblings,
      currentColumnId: currentColumnId,
      formulaColumnNames: formulaColumnNames,
    );
    if (!enableConnectorChain || !connectorEnabled.value) {
      return primary;
    }
    if (connectorTail.guidedFormulaKind.value == null) {
      return primary.isEmpty
          ? ''
          : '$primary ${connectorOperator.value} …';
    }
    final String tail = connectorTail.guidedFormulaPreview(
      schemas,
      siblings,
      currentColumnId: currentColumnId,
      formulaColumnNames: formulaColumnNames,
    );
    if (primary.isEmpty) {
      return tail;
    }
    return '$primary ${connectorOperator.value} $tail';
  }

  String _previewAggregate(String fn, List<TableSchemaEntity> schemas) {
    TableSchemaEntity? schemaById(String? sid) {
      if (sid == null) {
        return null;
      }
      for (final TableSchemaEntity s in schemas) {
        if (s.id == sid) {
          return s;
        }
      }
      return null;
    }

    final TableSchemaEntity? at = schemaById(aggregateTableSchemaId.value);
    final String tableName =
        (at?.name ?? '').trim().isEmpty ? '?' : at!.name.trim();
    final String ac = aggregateColumnController.text.trim().isEmpty
        ? '?'
        : aggregateColumnController.text.trim();
    return '$fn(${_atomIdentOrQuoted(tableName)}.${_atomIdentOrQuoted(ac)})';
  }

  String? _composePrimaryFormula(
    List<TableSchemaEntity> schemas,
    List<GuidedFormulaColumnLike> siblings,
    String currentColumnId,
    List<ColumnNameDraft> formulaColumnNames,
  ) {
    final GuidedFormulaKind? k = guidedFormulaKind.value;
    if (k == null) {
      return null;
    }

    TableSchemaEntity? schemaById(String? sid) {
      if (sid == null) {
        return null;
      }
      for (final TableSchemaEntity s in schemas) {
        if (s.id == sid) {
          return s;
        }
      }
      return null;
    }

    switch (k) {
      case GuidedFormulaKind.expression:
        return ArithmeticExpressionFormula.compose(
          expressionTokens.toList(growable: false),
          siblings,
          schemas,
        );
      case GuidedFormulaKind.lookup:
        final TableSchemaEntity table = schemaById(lookupTableSchemaId.value)!;
        final String lk = lookupLookupColumnController.text.trim();
        final String rk = lookupReturnColumnController.text.trim();
        final String? valueExprRaw = _composeSlot(
          lookupKeySlot,
          schemas,
          siblings,
          currentColumnId,
          formulaColumnNames,
        );
        if (valueExprRaw == null) {
          return null;
        }
        final String valueExpr = valueExprRaw;
        return 'LOOKUP($valueExpr, ${_atomIdentOrQuoted(table.name.trim())}, ${_atomIdentOrQuoted(lk)}, ${_atomIdentOrQuoted(rk)})';
      case GuidedFormulaKind.ifelse:
        final String? left = _composeSlot(
          ifConditionLeft,
          schemas,
          siblings,
          currentColumnId,
          formulaColumnNames,
        );
        final String? right = _composeSlot(
          ifConditionRight,
          schemas,
          siblings,
          currentColumnId,
          formulaColumnNames,
        );
        final String? t = _composeSlot(
          ifTrueSlot,
          schemas,
          siblings,
          currentColumnId,
          formulaColumnNames,
        );
        final String? f = _composeSlot(
          ifFalseSlot,
          schemas,
          siblings,
          currentColumnId,
          formulaColumnNames,
        );
        if (left == null || right == null || t == null || f == null) {
          return null;
        }
        final String op = ifOperator.value;
        final String cond = '$left $op $right';
        return 'IF($cond, $t, $f)';
      case GuidedFormulaKind.sum:
        return _composeAggregate('SUM', schemas);
      case GuidedFormulaKind.count:
        return _composeAggregate('COUNT', schemas);
      case GuidedFormulaKind.avg:
        return _composeAggregate('AVG', schemas);
    }
  }

  String? composeGuidedFormula(
    List<TableSchemaEntity> schemas,
    List<GuidedFormulaColumnLike> siblings,
    String currentColumnId,
    List<ColumnNameDraft> formulaColumnNames,
  ) {
    if (validateGuided(
          schemas,
          siblings,
          currentColumnId,
          formulaColumnNames: formulaColumnNames,
        ).isNotEmpty) {
      return null;
    }
    final String? primary = _composePrimaryFormula(
      schemas,
      siblings,
      currentColumnId,
      formulaColumnNames,
    );
    if (primary == null) {
      return null;
    }
    if (!enableConnectorChain || !connectorEnabled.value) {
      return primary;
    }
    final String? tail = connectorTail.composeGuidedFormula(
      schemas,
      siblings,
      currentColumnId,
      formulaColumnNames,
    );
    if (tail == null) {
      return null;
    }
    return '$primary ${connectorOperator.value} $tail';
  }

  String _composeAggregate(String fn, List<TableSchemaEntity> schemas) {
    TableSchemaEntity? schemaById(String? sid) {
      if (sid == null) {
        return null;
      }
      for (final TableSchemaEntity s in schemas) {
        if (s.id == sid) {
          return s;
        }
      }
      return null;
    }

    final TableSchemaEntity at = schemaById(aggregateTableSchemaId.value)!;
    final String ac = aggregateColumnController.text.trim();
    return '$fn(${_atomIdentOrQuoted(at.name.trim())}.${_atomIdentOrQuoted(ac)})';
  }

  void dispose() {
    expressionSourceColumnController.dispose();
    expressionNumberController.dispose();
    lookupLookupColumnController.dispose();
    lookupReturnColumnController.dispose();
    lookupKeySlot.dispose();
    ifConditionLeft.dispose();
    ifConditionRight.dispose();
    ifTrueSlot.dispose();
    ifFalseSlot.dispose();
    aggregateColumnController.dispose();
    if (enableConnectorChain) {
      _connectorTail?.dispose();
      _connectorTail = null;
    }
  }

  /// Structured tree for persistence (evaluator still uses composed [formula] string).
  Map<String, dynamic>? exportDefinitionTree() {
    final GuidedFormulaKind? k = guidedFormulaKind.value;
    if (k == null) {
      return null;
    }
    final Map<String, dynamic> m = switch (k) {
      GuidedFormulaKind.expression => <String, dynamic>{
        'type': 'expression',
        'tokens': expressionTokens.toList(growable: false),
      },
      GuidedFormulaKind.lookup => <String, dynamic>{
        'type': 'LOOKUP',
        'lookupKey': lookupKeySlot.toJson(),
        'tableId': lookupTableSchemaId.value,
        'lookupColumn': lookupLookupColumnController.text.trim(),
        'returnColumn': lookupReturnColumnController.text.trim(),
      },
      GuidedFormulaKind.ifelse => <String, dynamic>{
        'type': 'IF',
        'condition': <String, dynamic>{
          'left': ifConditionLeft.toJson(),
          'operator': ifOperator.value,
          'right': ifConditionRight.toJson(),
        },
        'trueValue': ifTrueSlot.toJson(),
        'falseValue': ifFalseSlot.toJson(),
      },
      GuidedFormulaKind.sum => <String, dynamic>{
        'type': 'SUM',
        'tableId': aggregateTableSchemaId.value,
        'column': aggregateColumnController.text.trim(),
      },
      GuidedFormulaKind.count => <String, dynamic>{
        'type': 'COUNT',
        'tableId': aggregateTableSchemaId.value,
        'column': aggregateColumnController.text.trim(),
      },
      GuidedFormulaKind.avg => <String, dynamic>{
        'type': 'AVG',
        'tableId': aggregateTableSchemaId.value,
        'column': aggregateColumnController.text.trim(),
      },
    };
    if (enableConnectorChain && connectorEnabled.value) {
      m['connectorEnabled'] = true;
      m['connectorOperator'] = connectorOperator.value;
      m['connectorSegment'] = connectorTail.exportDefinitionTree();
    }
    return m;
  }

  void _importSlotLoose(dynamic v, FormulaValueSlot slot) {
    if (v == null) {
      slot.clear();
      return;
    }
    if (v is Map<String, dynamic>) {
      slot.importJson(v);
      return;
    }
    if (v is Map) {
      slot.importJson(v.cast<String, dynamic>());
      return;
    }
    slot.clear();
    slot.source.value = FormulaSlotSourceKind.manual;
    slot.manualController.text = v.toString();
  }

  void importDefinitionTree(Map<String, dynamic>? raw) {
    clearGuidedFormulaBuilder();
    if (raw == null) {
      return;
    }
    final String type = (raw['type'] ?? '').toString().toUpperCase();
    switch (type) {
      case 'EXPRESSION':
        guidedFormulaKind.value = GuidedFormulaKind.expression;
        expressionTokens.assignAll(
          ((raw['tokens'] as List?) ?? const <dynamic>[])
              .map((dynamic e) => e.toString())
              .toList(growable: false),
        );
        break;
      case 'LOOKUP':
        guidedFormulaKind.value = GuidedFormulaKind.lookup;
        lookupTableSchemaId.value = raw['tableId']?.toString();
        lookupLookupColumnController.text =
            (raw['lookupColumn'] ?? '').toString();
        lookupReturnColumnController.text =
            (raw['returnColumn'] ?? '').toString();
        lookupKeySlot.importJson(
          (raw['lookupKey'] as Map?)?.cast<String, dynamic>(),
        );
        break;
      case 'IF':
        guidedFormulaKind.value = GuidedFormulaKind.ifelse;
        final Map<String, dynamic>? cond =
            (raw['condition'] as Map?)?.cast<String, dynamic>();
        if (cond != null) {
          ifOperator.value =
              (cond['operator'] ?? '=').toString().trim().isEmpty
                  ? '='
                  : (cond['operator'] ?? '=').toString();
          _importSlotLoose(cond['left'], ifConditionLeft);
          _importSlotLoose(cond['right'], ifConditionRight);
        }
        _importSlotLoose(raw['trueValue'], ifTrueSlot);
        _importSlotLoose(raw['falseValue'], ifFalseSlot);
        break;
      case 'SUM':
      case 'COUNT':
      case 'AVG':
        guidedFormulaKind.value = switch (type) {
          'COUNT' => GuidedFormulaKind.count,
          'AVG' => GuidedFormulaKind.avg,
          _ => GuidedFormulaKind.sum,
        };
        aggregateTableSchemaId.value = raw['tableId']?.toString();
        aggregateColumnController.text = (raw['column'] ?? '').toString();
        break;
      default:
        return;
    }
    _importConnectorFromRaw(raw);
  }

  void _importConnectorFromRaw(Map<String, dynamic> raw) {
    if (!enableConnectorChain || raw['connectorEnabled'] != true) {
      return;
    }
    connectorEnabled.value = true;
    final String op = (raw['connectorOperator'] ?? '+').toString();
    connectorOperator.value =
        connectorOperatorsAllowed.contains(op) ? op : '+';
    connectorTail.importDefinitionTree(
      (raw['connectorSegment'] as Map?)?.cast<String, dynamic>(),
    );
  }
}

bool _isSimpleIdent(String s) =>
    RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(s);

String _atomIdentOrQuoted(String raw) {
  final String t = raw.trim();
  if (t.isEmpty) {
    return '""';
  }
  if (_isSimpleIdent(t)) {
    return t;
  }
  return '"${t.replaceAll('"', r'\"')}"';
}

String _atomLiteral(String raw) {
  final String t = raw.trim();
  if (t.isEmpty) {
    return '""';
  }
  if (double.tryParse(t) != null) {
    return t;
  }
  return _atomIdentOrQuoted(t);
}
