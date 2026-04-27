import 'package:antwise/domain/validation/table_formula_validator.dart';
import 'package:antwise/domain/entities/table_column_dropdown_source.dart';
import 'package:antwise/domain/entities/table_column_type.dart';
import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/domain/entities/table_text_validation_kind.dart';
import 'package:antwise/presentation/models/formula_input_mode.dart';
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
  final TextEditingController textHintController = TextEditingController();
  final TextEditingController textCustomRegexController =
      TextEditingController();
  final TextEditingController numberHintController = TextEditingController();
  final TextEditingController numberPrefixController = TextEditingController();
  final TextEditingController numberSuffixController = TextEditingController();
  final TextEditingController numberMinController = TextEditingController();
  final TextEditingController numberMaxController = TextEditingController();
  final TextEditingController numberStepController =
      TextEditingController(text: '1');
  final TextEditingController dropdownOptionsController =
      TextEditingController();
  final Rx<TableColumnType?> type = Rx<TableColumnType?>(null);
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

  /// When [type] is [TableColumnType.formula]: builder UI vs. text editor.
  final Rx<FormulaInputMode> formulaInputMode = FormulaInputMode.guided.obs;

  /// Manual formula text when [formulaInputMode] is [FormulaInputMode.textEditor].
  final TextEditingController formulaTextController = TextEditingController();

  final Rx<TableTextValidationKind> textValidationKind =
      TableTextValidationKind.none.obs;
  final RxnString textPrefixIconKey = RxnString();
  final RxnString textSuffixIconKey = RxnString();
  final RxBool numberAllowDecimals = true.obs;
  final RxBool numberIntegerOnly = false.obs;
  final RxBool numberPositiveOnly = false.obs;
  final RxBool numberShowStepper = false.obs;
  final RxBool numberPrefixUseIcon = false.obs;
  final RxBool numberSuffixUseIcon = false.obs;
  final RxnString numberPrefixIconKey = RxnString();
  final RxnString numberSuffixIconKey = RxnString();

  void resetTextFieldConfiguration() {
    textHintController.clear();
    textCustomRegexController.clear();
    textValidationKind.value = TableTextValidationKind.none;
    textPrefixIconKey.value = null;
    textSuffixIconKey.value = null;
  }

  void resetNumberFieldConfiguration() {
    numberHintController.clear();
    numberPrefixController.clear();
    numberSuffixController.clear();
    numberMinController.clear();
    numberMaxController.clear();
    numberStepController.text = '1';
    numberAllowDecimals.value = true;
    numberIntegerOnly.value = false;
    numberPositiveOnly.value = false;
    numberShowStepper.value = false;
    numberPrefixUseIcon.value = false;
    numberSuffixUseIcon.value = false;
    numberPrefixIconKey.value = null;
    numberSuffixIconKey.value = null;
  }

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
    textHintController.dispose();
    textCustomRegexController.dispose();
    numberHintController.dispose();
    numberPrefixController.dispose();
    numberSuffixController.dispose();
    numberMinController.dispose();
    numberMaxController.dispose();
    numberStepController.dispose();
    dropdownOptionsController.dispose();
    formulaTextController.dispose();
    guided.dispose();
  }
}
