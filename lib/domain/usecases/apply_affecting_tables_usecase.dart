import 'package:antwise/domain/entities/table_affecting_config.dart';
import 'package:antwise/domain/entities/table_column_entity.dart';
import 'package:antwise/domain/entities/table_column_type.dart';
import 'package:antwise/domain/entities/table_mode.dart';
import 'package:antwise/domain/entities/table_row_entity.dart';
import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/domain/formula/table_formula_evaluator.dart';
import 'package:antwise/domain/repositories/table_row_repository.dart';

/// Applies CRUD side-effect rules on other tables using row matching and formula updates.
class ApplyAffectingTablesUseCase {
  ApplyAffectingTablesUseCase(this._rowRepository);

  final TableRowRepository _rowRepository;

  Future<void> call({
    required TableSchemaEntity sourceSchema,
    required List<TableAffectingConfig> configs,
    required List<TableSchemaEntity> allSchemas,
    required Map<String, dynamic> lineValues,
  }) async {
    if (configs.isEmpty) {
      return;
    }
    final Map<String, TableSchemaEntity> schemasById = <String, TableSchemaEntity>{
      for (final TableSchemaEntity schema in allSchemas) schema.id: schema,
    };
    final Map<String, List<TableRowEntity>> rowsByTableId =
        <String, List<TableRowEntity>>{};
    for (final TableSchemaEntity schema in allSchemas) {
      rowsByTableId[schema.id] = await _rowRepository.getByTableId(schema.id);
    }

    for (final TableAffectingConfig config in configs) {
      final TableSchemaEntity? targetSchema = schemasById[config.targetTableId];
      if (targetSchema == null) {
        continue;
      }
      final String sourceMatchValue =
          lineValues[config.match.sourceColumnId]?.toString().trim() ?? '';
      if (sourceMatchValue.isEmpty) {
        continue;
      }
      final List<TableRowEntity> targetRows =
          rowsByTableId[targetSchema.id] ?? const <TableRowEntity>[];
      int matchedIndex = -1;
      for (int i = 0; i < targetRows.length; i++) {
        final TableRowEntity row = targetRows[i];
        final Map<String, dynamic> resolved = TableFormulaEvaluator.resolveRowValues(
          schema: targetSchema,
          row: row,
          allSchemas: allSchemas,
          rowsByTableId: rowsByTableId,
        );
        final String targetMatchValue =
            (resolved[config.match.targetColumnId] ??
                    row.values[config.match.targetColumnId] ??
                    '')
                .toString()
                .trim();
        if (targetMatchValue == sourceMatchValue) {
          matchedIndex = i;
          break;
        }
      }
      if (matchedIndex < 0) {
        continue;
      }
      final TableRowEntity matched = targetRows[matchedIndex];
      final Map<String, dynamic> updatedValues = Map<String, dynamic>.from(
        matched.values,
      );
      for (final TableAffectedColumnRule rule in config.rules) {
        final TableColumnEntity? targetColumn = _columnById(
          targetSchema.columns,
          rule.targetColumnId,
        );
        if (targetColumn == null) {
          continue;
        }
        final String computed = _computeRuleValue(
          formula: rule.formula,
          sourceSchema: sourceSchema,
          sourceValues: lineValues,
          targetSchema: targetSchema,
          targetValues: updatedValues,
          allSchemas: allSchemas,
          rowsByTableId: rowsByTableId,
        );
        updatedValues[targetColumn.id] = _coerceForColumnType(
          computed,
          targetColumn.type,
        );
      }
      final TableRowEntity updated = TableRowEntity(
        id: matched.id,
        tableId: matched.tableId,
        values: updatedValues,
      );
      await _rowRepository.update(updated);
      targetRows[matchedIndex] = updated;
      rowsByTableId[targetSchema.id] = targetRows;
    }
  }

  String _computeRuleValue({
    required String formula,
    required TableSchemaEntity sourceSchema,
    required Map<String, dynamic> sourceValues,
    required TableSchemaEntity targetSchema,
    required Map<String, dynamic> targetValues,
    required List<TableSchemaEntity> allSchemas,
    required Map<String, List<TableRowEntity>> rowsByTableId,
  }) {
    final List<TableColumnEntity> contextColumns = <TableColumnEntity>[];
    final Map<String, dynamic> contextValues = <String, dynamic>{};
    for (final TableColumnEntity sourceCol in sourceSchema.columns) {
      contextColumns.add(
        TableColumnEntity(
          id: sourceCol.id,
          name: sourceCol.name,
          type: sourceCol.type,
          includeInCreateForm: false,
          includeInEditForm: false,
          isRequired: false,
          dropdownOptions: const <String>[],
          dropdownSourceKind: sourceCol.dropdownSourceKind,
        ),
      );
      contextValues[sourceCol.id] = sourceValues[sourceCol.id];
    }

    String normalizedFormula = formula;
    for (int i = 0; i < targetSchema.columns.length; i++) {
      final TableColumnEntity targetCol = targetSchema.columns[i];
      // Keep token parser-safe (letters/digits/underscore only).
      final String tokenId = '__target_col_$i';
      contextColumns.add(
        TableColumnEntity(
          id: tokenId,
          name: tokenId,
          type: targetCol.type,
          includeInCreateForm: false,
          includeInEditForm: false,
          isRequired: false,
          dropdownOptions: const <String>[],
          dropdownSourceKind: targetCol.dropdownSourceKind,
        ),
      );
      contextValues[tokenId] = targetValues[targetCol.id];
      final String tableName = targetSchema.name.trim();
      final String colName = targetCol.name.trim();
      normalizedFormula = normalizedFormula
          .replaceAll('$tableName.$colName', tokenId)
          .replaceAll('$tableName."$colName"', tokenId)
          .replaceAll('"$tableName".$colName', tokenId)
          .replaceAll('"$tableName"."$colName"', tokenId);
    }

    final TableSchemaEntity contextSchema = TableSchemaEntity(
      id: '__affecting_ctx__',
      pageId: '',
      name: '__affecting_ctx__',
      description: '',
      mode: TableMode.crud,
      columns: contextColumns,
    );
    return TableFormulaEvaluator.evaluate(
      formula: normalizedFormula,
      currentSchema: contextSchema,
      workingRowByColId: contextValues,
      allSchemas: allSchemas,
      rowsByTableId: rowsByTableId,
    );
  }

  dynamic _coerceForColumnType(String computed, TableColumnType targetType) {
    final String trimmed = computed.trim();
    if (targetType != TableColumnType.number) {
      return computed;
    }
    final double? numeric = double.tryParse(trimmed);
    if (numeric == null) {
      return computed;
    }
    if (numeric == numeric.roundToDouble() &&
        numeric <= 9007199254740992 &&
        numeric >= -9007199254740992) {
      return numeric.round();
    }
    return numeric;
  }

  TableColumnEntity? _columnById(List<TableColumnEntity> columns, String id) {
    for (final TableColumnEntity column in columns) {
      if (column.id == id) {
        return column;
      }
    }
    return null;
  }
}
