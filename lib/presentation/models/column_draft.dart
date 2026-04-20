import 'package:antwise/domain/validation/table_formula_validator.dart';
import 'package:antwise/domain/entities/table_column_dropdown_source.dart';
import 'package:antwise/domain/entities/table_column_type.dart';
import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/presentation/models/guided_formula_draft_state.dart';
import 'package:antwise/presentation/models/guided_formula_host.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Draft column for Create Table; includes guided formula builder state.
class ColumnDraft implements GuidedFormulaColumnLike {
  ColumnDraft(
    this.id, {
    String? initialName,
    TableColumnType? initialType,
  }) {
    if (initialName != null) {
      nameController.text = initialName;
    }
    if (initialType != null) {
      type.value = initialType;
    }
  }

  @override
  final String id;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController patternController = TextEditingController();
  final TextEditingController dropdownOptionsController =
      TextEditingController();
  final Rx<TableColumnType> type = TableColumnType.text.obs;
  final RxBool includeInCreate = true.obs;
  final RxBool includeInEdit = true.obs;
  final RxBool isRequired = false.obs;
  final RxBool isUnique = false.obs;

  /// When [type] is [TableColumnType.dropdown]: manual list vs linked table column.
  final Rx<TableColumnDropdownSourceKind> dropdownSourceKind =
      TableColumnDropdownSourceKind.manual.obs;
  final RxnString dropdownSourceTableId = RxnString();
  final RxnString dropdownSourceColumnId = RxnString();

  /// Guided (chip) formula builder state for [TableColumnType.formula].
  final GuidedFormulaDraftState guided = GuidedFormulaDraftState();

  void resetDropdownConfiguration() {
    dropdownSourceKind.value = TableColumnDropdownSourceKind.manual;
    dropdownSourceTableId.value = null;
    dropdownSourceColumnId.value = null;
    dropdownOptionsController.clear();
  }

  static List<String> get ifOperatorsAllowed =>
      GuidedFormulaDraftState.ifOperatorsAllowed;

  void clearGuidedFormulaBuilder() {
    guided.clearGuidedFormulaBuilder();
  }

  Map<String, String> validateGuided(
    List<TableSchemaEntity> schemas,
    List<ColumnDraft> siblings,
    List<ColumnNameDraft> formulaColumnNames,
  ) {
    return guided.validateGuided(
      schemas,
      siblings.cast<GuidedFormulaColumnLike>(),
      id,
      formulaColumnNames: formulaColumnNames,
    );
  }

  String guidedFormulaPreview(
    List<TableSchemaEntity> schemas,
    List<ColumnDraft> siblings,
  ) {
    final List<ColumnNameDraft> names = siblings
        .map(
          (ColumnDraft c) =>
              ColumnNameDraft(id: c.id, name: c.nameController.text),
        )
        .toList(growable: false);
    return guided.guidedFormulaPreview(
      schemas,
      siblings.cast<GuidedFormulaColumnLike>(),
      currentColumnId: id,
      formulaColumnNames: names,
    );
  }

  String? composeGuidedFormula(
    List<TableSchemaEntity> schemas,
    List<ColumnDraft> siblings,
    List<ColumnNameDraft> formulaColumnNames,
  ) {
    return guided.composeGuidedFormula(
      schemas,
      siblings.cast<GuidedFormulaColumnLike>(),
      id,
      formulaColumnNames,
    );
  }

  void dispose() {
    nameController.dispose();
    patternController.dispose();
    dropdownOptionsController.dispose();
    guided.dispose();
  }
}
