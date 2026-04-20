import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/domain/validation/table_formula_validator.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Columns that can appear in LOOKUP / IF sibling pickers (create or edit table).
abstract interface class GuidedFormulaColumnLike {
  String get id;

  TextEditingController get nameController;
}

/// Controllers that supply formula-builder state and sibling columns.
abstract interface class GuidedFormulaHost {
  RxInt get formulaErrorsVersion;

  RxInt get formulaPreviewVersion;

  RxList<TableSchemaEntity> get existingTableSchemas;

  RxMap<String, String> get formulaFieldErrors;

  RxMap<String, String> get formulaBuilderFieldErrors;

  String? formulaBuilderFieldError(String columnId, String fieldKey);

  void onGuidedFormulaInteraction(String columnId);

  List<GuidedFormulaColumnLike> siblingColumnsExcluding(String columnId);

  /// Every column on the table (for validating arithmetic expressions).
  List<ColumnNameDraft> allColumnsAsNameDrafts();

  /// Display label for table selectors (e.g. `Orders (Sales Page)`).
  String tableDisplayLabel(TableSchemaEntity schema);
}
