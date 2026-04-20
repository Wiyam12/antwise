import 'package:antwise/domain/entities/table_column_entity.dart';
import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/domain/formula/guided_formula_kind.dart';
import 'package:antwise/domain/validation/table_formula_validator.dart';
import 'package:antwise/presentation/models/arithmetic_expression_formula.dart';
import 'package:antwise/presentation/models/formula_value_slot.dart';
import 'package:antwise/presentation/models/guided_formula_draft_state.dart';
import 'package:antwise/presentation/models/guided_formula_host.dart';
import 'package:antwise/presentation/widgets/searchable_dropdown_field.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Step-based guided formula UI for [TableColumnType.formula] (create or edit table).
class GuidedFormulaBuilder extends StatelessWidget {
  const GuidedFormulaBuilder({
    super.key,
    required this.host,
    required this.guided,
    required this.columnId,
    required this.theme,
    this.errorKeyPrefix = '',
    this.nestingDepth = 0,
    this.showPreview,
    this.isConnectorSegment = false,
  });

  final GuidedFormulaHost host;
  final GuidedFormulaDraftState guided;
  final String columnId;
  final ThemeData theme;

  /// Prefix for [GuidedFormulaHost.formulaBuilderFieldError] keys (nested IF / LOOKUP).
  final String errorKeyPrefix;

  /// Depth of nested formula builders (limits further nesting).
  final int nestingDepth;

  /// When null, preview is shown only for the column root (not nested slots or connector segment).
  final bool? showPreview;

  /// Second root segment builder: no duplicate preview panel.
  final bool isConnectorSegment;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      host.formulaErrorsVersion.value;
      host.formulaPreviewVersion.value;
      host.existingTableSchemas.length;
      guided.guidedFormulaKind.value;
      guided.lookupTableSchemaId.value;
      guided.lookupKeySlot.source.value;
      guided.expressionTokens.length;
      guided.expressionSourceTableId.value;
      guided.ifConditionLeft.source.value;
      guided.ifConditionRight.source.value;
      guided.ifTrueSlot.source.value;
      guided.ifFalseSlot.source.value;
      guided.ifOperator.value;
      guided.aggregateTableSchemaId.value;
      if (guided.enableConnectorChain) {
        guided.connectorEnabled.value;
        guided.connectorOperator.value;
        if (guided.connectorEnabled.value) {
          guided.connectorTail.guidedFormulaKind.value;
        }
      }

      final List<TableSchemaEntity> schemas =
          host.existingTableSchemas.toList(growable: false);
      final List<GuidedFormulaColumnLike> siblingColumns =
          host.siblingColumnsExcluding(columnId);
      final List<ColumnNameDraft> formulaColumnNames =
          host.allColumnsAsNameDrafts();
      final String? columnFormulaError = host.formulaFieldErrors[columnId];
      final String preview = guided.guidedFormulaPreview(
        schemas,
        siblingColumns,
        currentColumnId: columnId,
        formulaColumnNames: formulaColumnNames,
      );
      final String? composed = guided.composeGuidedFormula(
        schemas,
        siblingColumns,
        columnId,
        formulaColumnNames,
      );
      final bool previewIsFinal = composed != null && composed.isNotEmpty;

      final bool previewPanel =
          showPreview ?? (!isConnectorSegment && nestingDepth == 0);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (isConnectorSegment)
            Text('Connected formula', style: theme.textTheme.titleSmall)
          else if (nestingDepth > 0)
            Text('Nested formula', style: theme.textTheme.titleSmall)
          else
            Text('Formula builder', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(
            '1. Formula type',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final GuidedFormulaKind k in GuidedFormulaKind.values)
                ChoiceChip(
                  label: Text(k.builderLabel),
                  selected: guided.guidedFormulaKind.value == k,
                  onSelected: (bool selected) {
                    if (!selected) {
                      return;
                    }
                    if (guided.guidedFormulaKind.value != k) {
                      guided.clearGuidedFormulaBuilder();
                      guided.guidedFormulaKind.value = k;
                    }
                    host.onGuidedFormulaInteraction(columnId);
                  },
                ),
            ],
          ),
          _fieldError(theme, 'kind', columnId, host, errorKeyPrefix),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: guided.guidedFormulaKind.value == null
                ? const SizedBox.shrink(key: ValueKey<String>('formula-none'))
                : KeyedSubtree(
                    key: ValueKey<GuidedFormulaKind>(
                      guided.guidedFormulaKind.value!,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          '2. Parameters',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _kindFields(schemas, siblingColumns),
                      ],
                    ),
                  ),
          ),
          if (errorKeyPrefix.isEmpty &&
              nestingDepth == 0 &&
              !isConnectorSegment &&
              guided.enableConnectorChain) ...<Widget>[
            const SizedBox(height: 12),
            Obx(() {
              guided.connectorEnabled.value;
              guided.connectorOperator.value;
              guided.connectorTail.guidedFormulaKind.value;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Add connected formula'),
                    subtitle: const Text(
                      'Combine the main formula with another using +, −, ×, or ÷.',
                    ),
                    value: guided.connectorEnabled.value,
                    onChanged: (bool v) {
                      if (v) {
                        guided.connectorEnabled.value = true;
                      } else {
                        guided.connectorEnabled.value = false;
                        guided.connectorTail.clearGuidedFormulaBuilder();
                      }
                      host.onGuidedFormulaInteraction(columnId);
                    },
                  ),
                  if (guided.connectorEnabled.value) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      'Operator between formulas',
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value:
                          GuidedFormulaDraftState.connectorOperatorsAllowed
                                  .contains(guided.connectorOperator.value)
                              ? guided.connectorOperator.value
                              : GuidedFormulaDraftState
                                  .connectorOperatorsAllowed
                                  .first,
                      decoration: const InputDecoration(
                        labelText: 'Connect with',
                      ),
                      items: <DropdownMenuItem<String>>[
                        for (final String op
                            in GuidedFormulaDraftState
                                .connectorOperatorsAllowed)
                          DropdownMenuItem<String>(
                            value: op,
                            child: Text(op),
                          ),
                      ],
                      onChanged: (String? op) {
                        if (op == null) {
                          return;
                        }
                        guided.connectorOperator.value = op;
                        host.onGuidedFormulaInteraction(columnId);
                      },
                    ),
                    const SizedBox(height: 12),
                    GuidedFormulaBuilder(
                      host: host,
                      guided: guided.connectorTail,
                      columnId: columnId,
                      theme: theme,
                      errorKeyPrefix: 'connector.',
                      nestingDepth: 0,
                      showPreview: false,
                      isConnectorSegment: true,
                    ),
                  ],
                ],
              );
            }),
          ],
          if (previewPanel) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              'Preview',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 6),
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.35,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: SelectableText(
                  preview.isEmpty ? '—' : preview,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    color: previewIsFinal
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
          if (previewPanel && columnFormulaError != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              columnFormulaError,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      );
    });
  }

  Widget _kindFields(
    List<TableSchemaEntity> schemas,
    List<GuidedFormulaColumnLike> siblingColumns,
  ) {
    switch (guided.guidedFormulaKind.value!) {
      case GuidedFormulaKind.expression:
        return _expressionFields(theme, schemas, siblingColumns);
      case GuidedFormulaKind.lookup:
        return _lookupFields(schemas, siblingColumns);
      case GuidedFormulaKind.ifelse:
        return _ifFields(schemas, siblingColumns);
      case GuidedFormulaKind.sum:
      case GuidedFormulaKind.count:
      case GuidedFormulaKind.avg:
        return _aggregateFields(schemas);
    }
  }

  Widget _formulaSlotEditor({
    required String label,
    required FormulaValueSlot slot,
    required String slotErrorBase,
    required List<GuidedFormulaColumnLike> siblingColumns,
    required List<TableSchemaEntity> schemas,
  }) {
    final bool allowNested =
        nestingDepth < GuidedFormulaDraftState.maxFormulaNestDepth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(label, style: theme.textTheme.labelMedium),
        const SizedBox(height: 6),
        Obx(() {
          slot.source.value;
          return Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              ChoiceChip(
                label: const Text('Manual'),
                selected: slot.source.value == FormulaSlotSourceKind.manual,
                onSelected: (bool s) {
                  if (s) {
                    slot.setSourceKind(FormulaSlotSourceKind.manual);
                    host.onGuidedFormulaInteraction(columnId);
                  }
                },
              ),
              ChoiceChip(
                label: const Text('Column'),
                selected: slot.source.value == FormulaSlotSourceKind.siblingColumn,
                onSelected: (bool s) {
                  if (s) {
                    slot.setSourceKind(FormulaSlotSourceKind.siblingColumn);
                    host.onGuidedFormulaInteraction(columnId);
                  }
                },
              ),
              ChoiceChip(
                label: const Text('Formula'),
                selected: slot.source.value == FormulaSlotSourceKind.nested,
                onSelected:
                    allowNested
                        ? (bool s) {
                          if (s) {
                            slot.setSourceKind(FormulaSlotSourceKind.nested);
                            host.onGuidedFormulaInteraction(columnId);
                          }
                        }
                        : null,
              ),
            ],
          );
        }),
        const SizedBox(height: 8),
        Obx(() {
          switch (slot.source.value) {
            case FormulaSlotSourceKind.manual:
              return TextField(
                controller: slot.manualController,
                decoration: const InputDecoration(
                  labelText: 'Value',
                  hintText: 'Number or text',
                ),
                onChanged: (_) => host.onGuidedFormulaInteraction(columnId),
              );
            case FormulaSlotSourceKind.siblingColumn:
              if (siblingColumns.isEmpty) {
                return Text(
                  'Add another column on this table to reference it here.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              }
              return AnimatedBuilder(
                animation: Listenable.merge(
                  <Listenable>[
                    for (final GuidedFormulaColumnLike c in siblingColumns)
                      c.nameController,
                  ],
                ),
                builder: (BuildContext context, Widget? _) {
                  return DropdownButtonFormField<String>(
                    value: _validDropdownValue(
                      slot.siblingColumnId.value,
                      siblingColumns,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Column on this table',
                    ),
                    items: <DropdownMenuItem<String>>[
                      for (final GuidedFormulaColumnLike c in siblingColumns)
                        DropdownMenuItem<String>(
                          value: c.id,
                          child: Text(
                            c.nameController.text.trim().isEmpty
                                ? '(unnamed)'
                                : c.nameController.text.trim(),
                          ),
                        ),
                    ],
                    onChanged: (String? id) {
                      slot.siblingColumnId.value = id;
                      host.onGuidedFormulaInteraction(columnId);
                    },
                  );
                },
              );
            case FormulaSlotSourceKind.nested:
              final String nestedPrefix = '$errorKeyPrefix$slotErrorBase.nested.';
              return Padding(
                padding: EdgeInsets.only(left: nestingDepth == 0 ? 0 : 10),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: GuidedFormulaBuilder(
                      host: host,
                      guided: slot.nested,
                      columnId: columnId,
                      theme: theme,
                      errorKeyPrefix: nestedPrefix,
                      nestingDepth: nestingDepth + 1,
                    ),
                  ),
                ),
              );
          }
        }),
        _fieldError(theme, slotErrorBase, columnId, host, errorKeyPrefix),
      ],
    );
  }

  Widget _expressionFields(
    ThemeData theme,
    List<TableSchemaEntity> schemas,
    List<GuidedFormulaColumnLike> siblingColumns,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Build expression (tokens are applied left to right)',
          style: theme.textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        Obx(() {
          final List<String> tags =
              guided.expressionTokens.toList(growable: false);
          if (tags.isEmpty) {
            return Text(
              'Add columns, numbers, or operators below.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            );
          }
          return Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (int i = 0; i < tags.length; i++)
                InputChip(
                  label: Text(
                    ArithmeticExpressionFormula.displayLabel(
                      tags[i],
                      siblingColumns,
                      schemas,
                    ),
                  ),
                  onDeleted: () {
                    guided.expressionTokens.removeAt(i);
                    host.onGuidedFormulaInteraction(columnId);
                  },
                ),
            ],
          );
        }),
        const SizedBox(height: 10),
        Text('Operators', style: theme.textTheme.labelSmall),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            for (final String op in ArithmeticExpressionFormula.binaryOperators)
              FilledButton.tonal(
                onPressed: () {
                  guided.expressionTokens.add(
                    ArithmeticExpressionFormula.tagOperator(op),
                  );
                  host.onGuidedFormulaInteraction(columnId);
                },
                child: Text(op),
              ),
            FilledButton.tonal(
              onPressed: () {
                guided.expressionTokens.add(
                  ArithmeticExpressionFormula.tagOpenParen,
                );
                host.onGuidedFormulaInteraction(columnId);
              },
              child: const Text('('),
            ),
            FilledButton.tonal(
              onPressed: () {
                guided.expressionTokens.add(
                  ArithmeticExpressionFormula.tagCloseParen,
                );
                host.onGuidedFormulaInteraction(columnId);
              },
              child: const Text(')'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Columns', style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        if (siblingColumns.isEmpty)
          Text(
            'Add other columns to this table first, then pick them here.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          AnimatedBuilder(
            animation: Listenable.merge(
              <Listenable>[
                for (final GuidedFormulaColumnLike c in siblingColumns)
                  c.nameController,
              ],
            ),
            builder: (BuildContext context, Widget? _) {
              return Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final GuidedFormulaColumnLike c in siblingColumns)
                    ActionChip(
                      label: Text(
                        c.nameController.text.trim().isEmpty
                            ? '(unnamed)'
                            : c.nameController.text.trim(),
                      ),
                      onPressed: () {
                        guided.expressionTokens.add(
                          ArithmeticExpressionFormula.tagColumn(c.id),
                        );
                        host.onGuidedFormulaInteraction(columnId);
                      },
                    ),
                ],
              );
            },
          ),
        const SizedBox(height: 12),
        Text('Other table columns', style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        if (schemas.isEmpty)
          Text(
            'No other tables yet. Create another table first.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else ...<Widget>[
          SearchableDropdownField<String>(
            key: ValueKey<String?>(guided.expressionSourceTableId.value),
            options: <String>[for (final TableSchemaEntity s in schemas) s.id],
            value: _validSchemaId(guided.expressionSourceTableId.value, schemas),
            optionLabel: (String id) {
              final TableSchemaEntity? s = _schemaById(schemas, id);
              return s == null ? id : host.tableDisplayLabel(s);
            },
            label: 'Select table',
            hintText: 'Search tables…',
            onChanged: (String tableId) {
              guided.expressionSourceTableId.value = tableId;
              guided.expressionSourceColumnController.clear();
              host.onGuidedFormulaInteraction(columnId);
            },
          ),
          const SizedBox(height: 8),
          _columnDropdown(
            tableColumns:
                _schemaById(schemas, guided.expressionSourceTableId.value)
                    ?.columns ??
                const <TableColumnEntity>[],
            controller: guided.expressionSourceColumnController,
            hint: 'Select column',
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonal(
              onPressed: () {
                final String? tableId = guided.expressionSourceTableId.value;
                if (tableId == null) {
                  return;
                }
                final String colName =
                    guided.expressionSourceColumnController.text.trim();
                if (colName.isEmpty) {
                  return;
                }
                guided.expressionTokens.add(
                  ArithmeticExpressionFormula.tagTableColumn(
                    tableId: tableId,
                    columnName: colName,
                  ),
                );
                host.onGuidedFormulaInteraction(columnId);
              },
              child: const Text('Add table column'),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text('Number', style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: guided.expressionNumberController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Value',
                  hintText: 'e.g. 12 or 3.5',
                ),
                onChanged: (_) => host.onGuidedFormulaInteraction(columnId),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                final String raw =
                    guided.expressionNumberController.text.trim();
                if (raw.isEmpty || double.tryParse(raw) == null) {
                  return;
                }
                guided.expressionTokens.add(
                  ArithmeticExpressionFormula.tagNumber(raw),
                );
                guided.expressionNumberController.clear();
                host.onGuidedFormulaInteraction(columnId);
              },
              child: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Obx(() {
          final bool empty = guided.expressionTokens.isEmpty;
          return Wrap(
            spacing: 8,
            children: <Widget>[
              TextButton(
                onPressed:
                    empty
                        ? null
                        : () {
                          guided.expressionTokens.removeLast();
                          host.onGuidedFormulaInteraction(columnId);
                        },
                child: const Text('Delete last'),
              ),
              TextButton(
                onPressed:
                    empty
                        ? null
                        : () {
                          guided.expressionTokens.clear();
                          host.onGuidedFormulaInteraction(columnId);
                        },
                child: const Text('Clear all'),
              ),
            ],
          );
        }),
        _fieldError(theme, 'expression', columnId, host, errorKeyPrefix),
      ],
    );
  }

  Widget _lookupFields(
    List<TableSchemaEntity> schemas,
    List<GuidedFormulaColumnLike> siblingColumns,
  ) {
    final TableSchemaEntity? selectedTable = _schemaById(
      schemas,
      guided.lookupTableSchemaId.value,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Source table', style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        if (schemas.isEmpty)
          Text(
            'No other tables yet. Create a table first to use LOOKUP.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          )
        else
          SearchableDropdownField<String>(
            key: ValueKey<String?>(guided.lookupTableSchemaId.value),
            options: <String>[for (final TableSchemaEntity s in schemas) s.id],
            value: _validSchemaId(guided.lookupTableSchemaId.value, schemas),
            optionLabel: (String id) {
              final TableSchemaEntity? s = _schemaById(schemas, id);
              return s == null ? id : host.tableDisplayLabel(s);
            },
            label: 'Search tables',
            hintText: 'Search tables…',
            onChanged: (String id) {
              guided.lookupTableSchemaId.value = id;
              guided.lookupLookupColumnController.clear();
              guided.lookupReturnColumnController.clear();
              host.onGuidedFormulaInteraction(columnId);
            },
          ),
        _fieldError(theme, 'lookupTable', columnId, host, errorKeyPrefix),
        const SizedBox(height: 12),
        Text('Lookup column', style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        _columnDropdown(
          tableColumns: selectedTable?.columns ?? const [],
          controller: guided.lookupLookupColumnController,
          hint: 'Column to match (e.g. id)',
        ),
        _fieldError(theme, 'lookupLookupCol', columnId, host, errorKeyPrefix),
        const SizedBox(height: 12),
        Text('Return column', style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        _columnDropdown(
          tableColumns: selectedTable?.columns ?? const [],
          controller: guided.lookupReturnColumnController,
          hint: 'Column to return (e.g. name)',
        ),
        _fieldError(theme, 'lookupReturnCol', columnId, host, errorKeyPrefix),
        const SizedBox(height: 12),
        _formulaSlotEditor(
          label: 'Lookup key (match value)',
          slot: guided.lookupKeySlot,
          slotErrorBase: 'lookupKey',
          siblingColumns: siblingColumns,
          schemas: schemas,
        ),
      ],
    );
  }

  Widget _ifFields(
    List<TableSchemaEntity> schemas,
    List<GuidedFormulaColumnLike> siblingColumns,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _formulaSlotEditor(
          label: 'Condition — left side',
          slot: guided.ifConditionLeft,
          slotErrorBase: 'ifLeft',
          siblingColumns: siblingColumns,
          schemas: schemas,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value:
              GuidedFormulaDraftState.ifOperatorsAllowed.contains(
                    guided.ifOperator.value,
                  )
                  ? guided.ifOperator.value
                  : GuidedFormulaDraftState.ifOperatorsAllowed.first,
          decoration: const InputDecoration(labelText: 'Operator'),
          items: <DropdownMenuItem<String>>[
            for (final String op in GuidedFormulaDraftState.ifOperatorsAllowed)
              DropdownMenuItem<String>(value: op, child: Text(op)),
          ],
          onChanged: (String? op) {
            if (op == null) {
              return;
            }
            guided.ifOperator.value = op;
            host.onGuidedFormulaInteraction(columnId);
          },
        ),
        _fieldError(theme, 'ifOp', columnId, host, errorKeyPrefix),
        const SizedBox(height: 12),
        _formulaSlotEditor(
          label: 'Condition — right side',
          slot: guided.ifConditionRight,
          slotErrorBase: 'ifRight',
          siblingColumns: siblingColumns,
          schemas: schemas,
        ),
        const SizedBox(height: 12),
        _formulaSlotEditor(
          label: 'When true',
          slot: guided.ifTrueSlot,
          slotErrorBase: 'ifTrue',
          siblingColumns: siblingColumns,
          schemas: schemas,
        ),
        const SizedBox(height: 12),
        _formulaSlotEditor(
          label: 'When false',
          slot: guided.ifFalseSlot,
          slotErrorBase: 'ifFalse',
          siblingColumns: siblingColumns,
          schemas: schemas,
        ),
      ],
    );
  }

  Widget _aggregateFields(List<TableSchemaEntity> schemas) {
    final TableSchemaEntity? selectedTable = _schemaById(
      schemas,
      guided.aggregateTableSchemaId.value,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Table', style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        if (schemas.isEmpty)
          Text(
            'No other tables yet.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          )
        else
          SearchableDropdownField<String>(
            key: ValueKey<String?>(guided.aggregateTableSchemaId.value),
            options: <String>[for (final TableSchemaEntity s in schemas) s.id],
            value: _validSchemaId(guided.aggregateTableSchemaId.value, schemas),
            optionLabel: (String id) {
              final TableSchemaEntity? s = _schemaById(schemas, id);
              return s == null ? id : host.tableDisplayLabel(s);
            },
            label: 'Search tables',
            hintText: 'Search tables…',
            onChanged: (String id) {
              guided.aggregateTableSchemaId.value = id;
              guided.aggregateColumnController.clear();
              host.onGuidedFormulaInteraction(columnId);
            },
          ),
        _fieldError(theme, 'aggTable', columnId, host, errorKeyPrefix),
        const SizedBox(height: 12),
        Text('Column', style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        _columnDropdown(
          tableColumns: selectedTable?.columns ?? const [],
          controller: guided.aggregateColumnController,
          hint: 'Column to aggregate',
        ),
        _fieldError(theme, 'aggCol', columnId, host, errorKeyPrefix),
      ],
    );
  }

  Widget _columnDropdown({
    required List<TableColumnEntity> tableColumns,
    required TextEditingController controller,
    required String hint,
  }) {
    if (tableColumns.isEmpty) {
      return TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: hint,
          hintText: 'Select a table first',
        ),
        enabled: false,
      );
    }
    final List<String> names = <String>[
      for (final TableColumnEntity col in tableColumns) col.name.trim(),
    ].where((String n) => n.isNotEmpty).toList();

    final String current = controller.text.trim();
    final String? value = names.contains(current) ? current : null;

    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: hint),
      items: <DropdownMenuItem<String>>[
        for (final String n in names)
          DropdownMenuItem<String>(value: n, child: Text(n)),
      ],
      onChanged: (String? name) {
        controller.text = name ?? '';
        host.onGuidedFormulaInteraction(columnId);
      },
    );
  }
}

TableSchemaEntity? _schemaById(List<TableSchemaEntity> schemas, String? id) {
  if (id == null) {
    return null;
  }
  for (final TableSchemaEntity s in schemas) {
    if (s.id == id) {
      return s;
    }
  }
  return null;
}

String? _validDropdownValue(
  String? value,
  List<GuidedFormulaColumnLike> options,
) {
  if (value == null) {
    return null;
  }
  if (options.any((GuidedFormulaColumnLike c) => c.id == value)) {
    return value;
  }
  return null;
}

String? _validSchemaId(String? value, List<TableSchemaEntity> schemas) {
  if (value == null) {
    return null;
  }
  if (schemas.any((TableSchemaEntity s) => s.id == value)) {
    return value;
  }
  return null;
}

Widget _fieldError(
  ThemeData theme,
  String fieldKey,
  String columnId,
  GuidedFormulaHost host,
  String errorKeyPrefix,
) {
  final String? msg =
      host.formulaBuilderFieldError(columnId, '$errorKeyPrefix$fieldKey');
  if (msg == null) {
    return const SizedBox.shrink();
  }
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      msg,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.error,
      ),
    ),
  );
}
