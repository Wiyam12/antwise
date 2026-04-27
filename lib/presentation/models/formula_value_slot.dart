import 'package:antwise/presentation/models/guided_formula_draft_state.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// How a single IF / LOOKUP parameter is filled.
enum FormulaSlotSourceKind { manual, siblingColumn, tableColumn, nested }

/// One operand position that can hold a literal, a column reference, or a nested guided formula.
final class FormulaValueSlot {
  FormulaValueSlot();

  final Rx<FormulaSlotSourceKind> source = FormulaSlotSourceKind.manual.obs;
  final TextEditingController manualController = TextEditingController();
  final RxnString siblingColumnId = RxnString();
  final RxnString tableSchemaId = RxnString();
  final TextEditingController tableColumnController = TextEditingController();

  GuidedFormulaDraftState? _nested;

  GuidedFormulaDraftState get nested {
    return _nested ??= GuidedFormulaDraftState(enableConnectorChain: false);
  }

  bool get hasNestedInstance => _nested != null;

  void setSourceKind(FormulaSlotSourceKind next) {
    if (source.value == FormulaSlotSourceKind.nested &&
        next != FormulaSlotSourceKind.nested) {
      _nested?.clearGuidedFormulaBuilder();
      _nested?.dispose();
      _nested = null;
    }
    source.value = next;
  }

  void clear() {
    setSourceKind(FormulaSlotSourceKind.manual);
    manualController.clear();
    siblingColumnId.value = null;
    tableSchemaId.value = null;
    tableColumnController.clear();
    _nested?.clearGuidedFormulaBuilder();
    _nested?.dispose();
    _nested = null;
  }

  void dispose() {
    manualController.dispose();
    tableColumnController.dispose();
    _nested?.dispose();
    _nested = null;
  }

  Map<String, dynamic> toJson() {
    switch (source.value) {
      case FormulaSlotSourceKind.manual:
        return <String, dynamic>{
          'kind': 'manual',
          'value': manualController.text.trim(),
        };
      case FormulaSlotSourceKind.siblingColumn:
        return <String, dynamic>{
          'kind': 'column',
          'columnId': siblingColumnId.value,
        };
      case FormulaSlotSourceKind.tableColumn:
        return <String, dynamic>{
          'kind': 'tableColumn',
          'tableId': tableSchemaId.value,
          'columnName': tableColumnController.text.trim(),
        };
      case FormulaSlotSourceKind.nested:
        final Map<String, dynamic>? node = nested.exportDefinitionTree();
        return <String, dynamic>{'kind': 'formula', 'node': node};
    }
  }

  void importJson(Map<String, dynamic>? raw) {
    clear();
    if (raw == null) {
      return;
    }
    final String kind = (raw['kind'] ?? 'manual').toString();
    switch (kind) {
      case 'column':
        source.value = FormulaSlotSourceKind.siblingColumn;
        siblingColumnId.value = raw['columnId']?.toString();
        return;
      case 'tableColumn':
        source.value = FormulaSlotSourceKind.tableColumn;
        tableSchemaId.value = raw['tableId']?.toString();
        tableColumnController.text = (raw['columnName'] ?? '').toString();
        return;
      case 'formula':
        source.value = FormulaSlotSourceKind.nested;
        nested.importDefinitionTree(
          (raw['node'] as Map?)?.cast<String, dynamic>(),
        );
        return;
      default:
        source.value = FormulaSlotSourceKind.manual;
        manualController.text = (raw['value'] ?? '').toString();
    }
  }
}
