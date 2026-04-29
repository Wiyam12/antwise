import 'package:antwise/domain/entities/product_display_mode.dart';
import 'package:antwise/domain/entities/table_column_entity.dart';
import 'package:antwise/domain/entities/table_column_type.dart';
import 'package:antwise/domain/entities/table_data_loading_mode.dart';
import 'package:antwise/domain/entities/table_kind.dart';
import 'package:antwise/domain/entities/table_list_design_layout.dart';
import 'package:antwise/domain/entities/table_mode.dart';
import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/domain/entities/table_summary_config.dart';
import 'package:antwise/presentation/controllers/create_table_controller.dart';
import 'package:antwise/presentation/models/column_draft.dart';
import 'package:antwise/presentation/models/formula_input_mode.dart';
import 'package:antwise/presentation/widgets/dropdown_column_config_body.dart';
import 'package:antwise/presentation/widgets/formula_text_editor_field.dart';
import 'package:antwise/presentation/widgets/guided_formula_builder.dart';
import 'package:antwise/presentation/widgets/number_column_config_section.dart';
import 'package:antwise/presentation/widgets/searchable_dropdown_field.dart';
import 'package:antwise/presentation/widgets/searchable_column_type_field.dart';
import 'package:antwise/presentation/widgets/text_column_config_section.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:reorderables/reorderables.dart';
import 'package:antwise/presentation/widgets/dynamic_builder_page_body.dart';

final List<TableColumnType> _columnTypeOptions = TableColumnType.values.toList(
  growable: false,
);

class CreateTableScreen extends GetView<CreateTableController> {
  const CreateTableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Create Table')),
      body: Obx(() {
        if (controller.isLoadingPages.value) {
          return const Center(child: CircularProgressIndicator());
        }
        final bool isSummary = controller.tableKind.value == TableKind.summary;
        final bool isCrudStandard = controller.isCrudStandardTable;
        final int totalSteps = controller.lastStepIndex + 1;
        final int boundedCurrentStep = controller.currentStep.value.clamp(
          0,
          totalSteps - 1,
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
          child: Stepper(
            key: ValueKey<String>(
              'create-table-stepper-$isSummary-$isCrudStandard-$totalSteps',
            ),
            physics: const NeverScrollableScrollPhysics(),
            type: StepperType.vertical,
            currentStep: boundedCurrentStep,
            stepIconHeight: 28,
            stepIconWidth: 28,
            stepIconBuilder: (int stepIndex, StepState stepState) {
              final bool isCurrent = stepIndex == boundedCurrentStep;
              final String label = '${stepIndex + 1}';
              if (isCurrent) {
                return CircleAvatar(
                  backgroundColor: theme.colorScheme.primary,
                  child: Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.primary,
                    width: 1.6,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            },
            onStepContinue: () async {
              if (controller.currentStep.value == controller.lastStepIndex) {
                await controller.submit();
              } else {
                await controller.goNext();
              }
            },
            onStepCancel: controller.goBack,
            controlsBuilder: (BuildContext context, ControlsDetails details) {
              final int step = controller.currentStep.value;
              final bool isLast = step == controller.lastStepIndex;
              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  children: <Widget>[
                    TextButton(
                      onPressed: details.onStepCancel,
                      child: Text(step == 0 ? 'Cancel' : 'Back'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed:
                          controller.isSaving.value
                              ? null
                              : isLast
                              ? controller.submit
                              : details.onStepContinue,
                      child:
                          controller.isSaving.value
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : Text(isLast ? 'Create Table' : 'Next'),
                    ),
                  ],
                ),
              );
            },
            steps: <Step>[
              Step(
                title: Text(
                  controller.tableKind.value == TableKind.summary
                      ? 'Summary source'
                      : 'Design layout',
                ),
                isActive: controller.currentStep.value >= 0,
                state: StepState.indexed,
                content: _stepDesignLayout(theme),
              ),
              Step(
                title: const Text('Basic information'),
                isActive: controller.currentStep.value >= 1,
                state: StepState.indexed,
                content: _stepBasicInfo(theme),
              ),
              Step(
                title: Text(
                  controller.tableKind.value == TableKind.summary
                      ? 'Access mode'
                      : 'CRUD behavior',
                ),
                isActive: controller.currentStep.value >= 2,
                state: StepState.indexed,
                content: _stepCrud(theme),
              ),
              Step(
                title: Text(
                  controller.tableKind.value == TableKind.summary
                      ? 'Summary structure'
                      : 'Columns',
                ),
                isActive: controller.currentStep.value >= 3,
                state: StepState.indexed,
                content: _stepColumns(theme),
              ),
              if (controller.tableKind.value != TableKind.summary)
                Step(
                  title: const Text('Validation Rules'),
                  isActive: controller.currentStep.value >= 4,
                  state: StepState.indexed,
                  content: _stepValidationRules(theme),
                ),
              if (controller.isCrudStandardTable)
                Step(
                  title: const Text('Affecting tables'),
                  isActive: controller.currentStep.value >= 5,
                  state: StepState.indexed,
                  content: _stepAffectingTables(theme),
                ),
              Step(
                title: const Text('Review'),
                isActive:
                    controller.currentStep.value >=
                    (controller.tableKind.value == TableKind.summary
                        ? 4
                        : (controller.isCrudStandardTable ? 6 : 5)),
                state: StepState.indexed,
                content: _stepReview(theme),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _stepDesignLayout(ThemeData theme) {
    return Obx(() {
      final TableListDesignLayout? selected = controller.selectedDesign.value;
      final bool isSummary = controller.tableKind.value == TableKind.summary;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Table type', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<TableKind>(
            segments: const <ButtonSegment<TableKind>>[
              ButtonSegment<TableKind>(
                value: TableKind.standard,
                label: Text('Standard'),
                icon: Icon(Icons.table_rows),
              ),
              ButtonSegment<TableKind>(
                value: TableKind.summary,
                label: Text('Summary'),
                icon: Icon(Icons.analytics_outlined),
              ),
            ],
            selected: <TableKind>{controller.tableKind.value},
            onSelectionChanged: (Set<TableKind> selection) {
              if (selection.isEmpty) {
                return;
              }
              controller.setTableKind(selection.first);
            },
          ),
          const SizedBox(height: 8),
          Text(
            isSummary
                ? 'Summary tables aggregate rows from an existing table, stay read-only, and refresh automatically when source data changes.'
                : 'Pick a visual template. Next, set the table name and page; then configure columns.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (isSummary) ...<Widget>[
            if (controller.summarySourceTableOptions.isEmpty)
              Text(
                'Save at least one standard table first, then return here to build a summary from it.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              )
            else ...<Widget>[
              Text(
                'Build summary columns dynamically. Each column can target a source table/column, choose grouping, and apply its own aggregation or formula.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              _summaryColumnsEditorSection(theme),
            ],
          ] else ...<Widget>[
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double w = constraints.maxWidth;
                final int crossAxisCount = w >= 720 ? 3 : (w >= 440 ? 2 : 1);
                const double spacing = 12;
                final double childWidth =
                    (w - spacing * (crossAxisCount - 1)) / crossAxisCount;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  alignment: WrapAlignment.start,
                  children: List<Widget>.generate(
                    CreateTableController.visualLayoutKeysOrdered.length,
                    (int index) {
                      final String key =
                          CreateTableController.visualLayoutKeysOrdered[index];
                      final double aspectRatio =
                          CreateTableController
                              .visualLayoutCardAspectRatioByKey[key]!;
                      final bool isSelected =
                          controller.selectedVisualLayoutKey.value == key;
                      return SizedBox(
                        width: childWidth,
                        child: AspectRatio(
                          aspectRatio: aspectRatio,
                          child: _visualLayoutWidgetCard(
                            theme: theme,
                            layoutKey: key,
                            optionIndex: index,
                            selected: isSelected,
                            onTap: () => controller.pickVisualLayout(key),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Option 1: contact list · Option 2: product list/grid · '
                'Option 3: simple table (no preset columns).',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (selected == TableListDesignLayout.product) ...<Widget>[
              const SizedBox(height: 16),
              Text('Product display', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<ProductDisplayMode>(
                segments: const <ButtonSegment<ProductDisplayMode>>[
                  ButtonSegment<ProductDisplayMode>(
                    value: ProductDisplayMode.grid,
                    label: Text('Grid'),
                  ),
                  ButtonSegment<ProductDisplayMode>(
                    value: ProductDisplayMode.list,
                    label: Text('List'),
                  ),
                ],
                selected: <ProductDisplayMode>{
                  controller.productDisplayMode.value,
                },
                onSelectionChanged: (Set<ProductDisplayMode> selection) {
                  if (selection.isEmpty) {
                    return;
                  }
                  controller.setProductDisplayMode(selection.first);
                },
              ),
            ],
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable swipe to delete'),
              subtitle: const Text(
                'When on, swipe left to delete a row. When off, use the delete icon.',
              ),
              value: controller.swipeToDelete.value,
              onChanged: controller.setSwipeToDelete,
            ),
          ],
        ],
      );
    });
  }

  Widget _summaryColumnCard({
    required ThemeData theme,
    required SummaryColumnDraft column,
    required int index,
  }) {
    return Obx(() {
      final List<TableSchemaEntity> tables =
          controller.summarySourceTableOptions;
      TableSchemaEntity? selectedTable;
      final String? tableId = column.sourceTableId.value;
      if (tableId != null) {
        for (final TableSchemaEntity schema in tables) {
          if (schema.id == tableId) {
            selectedTable = schema;
            break;
          }
        }
      }
      final List<TableColumnEntity> sourceColumns = controller
          .summarySourceColumns(column.sourceTableId.value);
      TableColumnEntity? selectedColumn;
      final String? sourceColumnId = column.sourceColumnId.value;
      if (sourceColumnId != null) {
        for (final TableColumnEntity c in sourceColumns) {
          if (c.id == sourceColumnId) {
            selectedColumn = c;
            break;
          }
        }
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Summary Column ${index + 1}',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              IconButton(
                onPressed: () => controller.removeSummaryColumn(column.id),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          TextField(
            controller: column.nameController,
            decoration: const InputDecoration(labelText: 'Column name'),
            onChanged: (_) => controller.summaryColumns.refresh(),
          ),
          const SizedBox(height: 8),
          SearchableDropdownField<TableSchemaEntity>(
            options: tables,
            value: selectedTable,
            label: 'Source table',
            optionLabel:
                (TableSchemaEntity schema) =>
                    controller.tableDisplayLabel(schema),
            onChanged: (TableSchemaEntity selected) {
              column.sourceTableId.value = selected.id;
              column.sourceColumnId.value = null;
            },
          ),
          const SizedBox(height: 8),
          SearchableDropdownField<TableColumnEntity>(
            options: sourceColumns,
            value: selectedColumn,
            label: 'Source column',
            optionLabel: (TableColumnEntity c) => c.name,
            onChanged: (TableColumnEntity selected) {
              column.sourceColumnId.value = selected.id;
            },
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: column.groupBy.value,
            onChanged: (bool? value) => column.groupBy.value = value ?? false,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Use as Group By column'),
          ),
          const SizedBox(height: 8),
          SegmentedButton<SummaryValueMode>(
            showSelectedIcon: false,
            segments: const <ButtonSegment<SummaryValueMode>>[
              ButtonSegment(
                value: SummaryValueMode.groupedValue,
                label: Text('Grouped'),
              ),
              ButtonSegment(
                value: SummaryValueMode.uniqueValue,
                label: Text('Unique'),
              ),
              ButtonSegment(
                value: SummaryValueMode.aggregation,
                label: Text('Aggregate'),
              ),
              ButtonSegment(
                value: SummaryValueMode.formula,
                label: Text('Formula'),
              ),
            ],
            selected: <SummaryValueMode>{column.valueMode.value},
            onSelectionChanged: (Set<SummaryValueMode> next) {
              if (next.isEmpty) {
                return;
              }
              column.valueMode.value = next.first;
            },
          ),
          if (column.valueMode.value ==
              SummaryValueMode.aggregation) ...<Widget>[
            const SizedBox(height: 8),
            DropdownButtonFormField<SummaryAggregationOperation>(
              value: column.aggregation.value,
              decoration: const InputDecoration(labelText: 'Aggregation'),
              items: SummaryAggregationOperation.values
                  .map(
                    (SummaryAggregationOperation op) =>
                        DropdownMenuItem<SummaryAggregationOperation>(
                          value: op,
                          child: Text(op.name.toUpperCase()),
                        ),
                  )
                  .toList(growable: false),
              onChanged: (SummaryAggregationOperation? value) {
                if (value != null) {
                  column.aggregation.value = value;
                }
              },
            ),
          ],
          if (column.valueMode.value == SummaryValueMode.formula) ...<Widget>[
            const SizedBox(height: 8),
            TextField(
              controller: column.formulaController,
              decoration: const InputDecoration(
                labelText: 'Formula',
                hintText: 'SUM(Table1.Amount)',
              ),
            ),
          ],
        ],
      );
    });
  }

  Widget _summaryAggregationPreview(ThemeData theme) {
    final List<String> headers = controller.summaryColumns
        .map((SummaryColumnDraft c) {
          final String name = c.nameController.text.trim();
          return name.isEmpty ? 'Column' : name;
        })
        .take(3)
        .toList(growable: false);
    if (headers.isEmpty) {
      headers.add('Column');
    }
    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Output preview', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(
              'Rows are generated by the selected Group By summary columns. '
              'Each output column applies its own mode (grouped/unique/aggregate/formula).',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                border: TableBorder.all(
                  color: theme.colorScheme.outlineVariant,
                ),
                defaultColumnWidth: const IntrinsicColumnWidth(),
                children: <TableRow>[
                  TableRow(
                    children: headers
                        .map(
                          (String header) =>
                              _previewCell(theme, header, header: true),
                        )
                        .toList(growable: false),
                  ),
                  TableRow(
                    children: headers
                        .map((String _) => _previewCell(theme, '…'))
                        .toList(growable: false),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryColumnsEditorSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: controller.summaryColumns.length,
          onReorder: controller.moveSummaryColumn,
          itemBuilder: (BuildContext context, int index) {
            final SummaryColumnDraft column = controller.summaryColumns[index];
            return Card(
              key: ValueKey<String>('summary-col-${column.id}'),
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _summaryColumnCard(
                  theme: theme,
                  column: column,
                  index: index,
                ),
              ),
            );
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: controller.addSummaryColumn,
            icon: const Icon(Icons.add),
            label: const Text('Add Column'),
          ),
        ),
        const SizedBox(height: 16),
        _summaryAggregationPreview(theme),
      ],
    );
  }

  Widget _previewCell(ThemeData theme, String text, {bool header = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        text,
        style:
            header
                ? theme.textTheme.labelLarge
                : theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
      ),
    );
  }

  Widget _visualLayoutWidgetCard({
    required ThemeData theme,
    required String layoutKey,
    required int optionIndex,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final ColorScheme cs = theme.colorScheme;
    const double radius = 14;
    final TableListDesignLayout layout =
        CreateTableController.designForVisualLayoutKey(layoutKey);
    return Semantics(
      button: true,
      label: 'Layout template ${optionIndex + 1}',
      selected: selected,
      child: Material(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        elevation: selected ? 4 : 0,
        shadowColor: cs.primary.withValues(alpha: 0.35),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          splashColor: cs.primary.withValues(alpha: 0.12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: selected ? cs.primary : cs.outlineVariant,
                width: selected ? 3 : 1,
              ),
              boxShadow:
                  selected
                      ? <BoxShadow>[
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.28),
                          blurRadius: 12,
                          spreadRadius: 0,
                          offset: const Offset(0, 4),
                        ),
                      ]
                      : null,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(radius - 1),
                  child: ColoredBox(
                    color: cs.surfaceContainerHighest,
                    child: IgnorePointer(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: TableLayoutOptionPreview(
                          key: ValueKey<String>('layout-preview-$layoutKey'),
                          layout: layout,
                          productDisplayMode:
                              controller.productDisplayMode.value,
                        ),
                      ),
                    ),
                  ),
                ),
                if (selected)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.92),
                        shape: BoxShape.circle,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: cs.shadow.withValues(alpha: 0.2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.check_circle,
                          color: cs.primary,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepColumns(ThemeData theme) {
    return Obx(() {
      if (controller.tableKind.value == TableKind.summary) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Edit your summary columns here: choose source table/column, grouping, '
              'and aggregation or formula per output column.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            _summaryColumnsEditorSection(theme),
          ],
        );
      }
      if (controller.selectedDesign.value == null) {
        return const Text('Go back and select a layout first.');
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            controller.selectedDesign.value == TableListDesignLayout.contact
                ? 'Edit labels and optional settings. Column types are fixed for this layout.'
                : controller.selectedDesign.value ==
                    TableListDesignLayout.product
                ? 'Image, product name, and price are required: those three columns cannot be removed '
                    'and their data types are fixed. You may add more columns below.'
                : 'No columns are added for this layout. Use Add Column to define '
                    'your fields, types, and validation.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          ReorderableColumn(
            needsLongPressDraggable: true,
            onReorder: controller.reorderColumns,
            children: controller.columns
                .map(
                  (ColumnDraft column) => Container(
                    key: ValueKey<String>('create-column-${column.id}'),
                    child: _columnCard(theme, column),
                  ),
                )
                .toList(growable: false),
          ),
          if (controller.showAddColumnButton)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: controller.addColumn,
                icon: const Icon(Icons.add),
                label: const Text('Add Column'),
              ),
            ),
        ],
      );
    });
  }

  Widget _stepValidationRules(ThemeData theme) {
    return Obx(() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Optional pre-save rules. All enabled rules must pass before row add/update.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          if (controller.validationRules.isEmpty)
            Text(
              'No validation rules yet. Add one to enforce business logic such as stock checks.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...controller.validationRules.map((TableValidationRuleDraft rule) {
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              'Validation rule',
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                          Switch(
                            value: rule.enabled.value,
                            onChanged:
                                (bool value) => rule.enabled.value = value,
                          ),
                          IconButton(
                            onPressed:
                                () => controller.removeValidationRule(rule.id),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                      TextField(
                        controller: rule.nameController,
                        decoration: const InputDecoration(
                          labelText: 'Validation name',
                          hintText: 'Stock Check',
                        ),
                      ),
                      const SizedBox(height: 8),
                      FormulaTextEditorField(
                        controller: rule.conditionController,
                        schemas: controller.existingTableSchemas.toList(
                          growable: false,
                        ),
                        currentColumnNames: controller.columns
                            .map((ColumnDraft c) => c.nameController.text)
                            .toList(growable: false),
                        hintText:
                            'LOOKUP(Product, "Products", "Product Name", "Stocks") >= Qty',
                        errorText: null,
                        onChanged: () {},
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: rule.errorMessageController,
                        decoration: const InputDecoration(
                          labelText: 'Error message',
                          hintText: 'Quantity exceeds available stock',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: controller.addValidationRule,
              icon: const Icon(Icons.add),
              label: const Text('Add Validation Rule'),
            ),
          ),
        ],
      );
    });
  }

  Widget _columnCard(ThemeData theme, ColumnDraft column) {
    return Obx(() {
      final bool lockType = !controller.canEditColumnType(column);
      final bool showRemove = controller.canRemoveColumn(column);
      final String title =
          column.nameController.text.trim().isEmpty
              ? 'Column'
              : column.nameController.text.trim();
      return Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ExpansionTile(
          initiallyExpanded: false,
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall,
          ),
          leading: const Icon(Icons.drag_indicator),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (showRemove)
                IconButton(
                  onPressed: () => controller.removeColumn(column.id),
                  icon: const Icon(Icons.delete_outline),
                ),
              const Icon(Icons.expand_more),
            ],
          ),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: <Widget>[
            TextField(
              controller: column.nameController,
              decoration: const InputDecoration(labelText: 'Column label'),
            ),
            const SizedBox(height: 8),
            if (lockType)
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data type',
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  column.type.value != null
                      ? columnDataTypeLabel(column.type.value!)
                      : '',
                ),
              )
            else
              Obx(
                () => SearchableColumnTypeField(
                  selectedType: column.type.value,
                  allowedTypes: _columnTypeOptions,
                  onChanged: (TableColumnType value) {
                    final TableColumnType? previous = column.type.value;
                    controller.onColumnDataTypeChanged(
                      column.id,
                      previous,
                      value,
                    );
                    column.type.value = value;
                  },
                ),
              ),
            const SizedBox(height: 8),
            Obx(() {
              if (column.type.value == TableColumnType.text) {
                return TextColumnConfigSection(
                  theme: theme,
                  hintController: column.textHintController,
                  customPatternController: column.textCustomRegexController,
                  validationKind: column.textValidationKind,
                  prefixIconKey: column.textPrefixIconKey,
                  suffixIconKey: column.textSuffixIconKey,
                );
              }
              if (column.type.value == TableColumnType.number) {
                return NumberColumnConfigSection(
                  theme: theme,
                  hintController: column.numberHintController,
                  prefixController: column.numberPrefixController,
                  suffixController: column.numberSuffixController,
                  minController: column.numberMinController,
                  maxController: column.numberMaxController,
                  stepController: column.numberStepController,
                  prefixUseIcon: column.numberPrefixUseIcon,
                  suffixUseIcon: column.numberSuffixUseIcon,
                  prefixIconKey: column.numberPrefixIconKey,
                  suffixIconKey: column.numberSuffixIconKey,
                  allowDecimals: column.numberAllowDecimals,
                  integerOnly: column.numberIntegerOnly,
                  positiveOnly: column.numberPositiveOnly,
                  showStepper: column.numberShowStepper,
                );
              }
              if (column.type.value == TableColumnType.date) {
                return Obx(
                  () => SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: const <ButtonSegment<bool>>[
                      ButtonSegment<bool>(
                        value: false,
                        label: Text('No default'),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        label: Text('Default today'),
                      ),
                    ],
                    selected: <bool>{column.dateDefaultToday.value},
                    onSelectionChanged: (Set<bool> selection) {
                      if (selection.isEmpty) {
                        return;
                      }
                      column.dateDefaultToday.value = selection.first;
                    },
                  ),
                );
              }
              if (lockType) {
                return const SizedBox.shrink();
              }
              if (column.type.value == TableColumnType.autoGenerated) {
                return _patternConfigSection(
                  theme: theme,
                  controller: column.patternController,
                );
              }
              if (column.type.value == TableColumnType.formula) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Formula input mode',
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Obx(
                      () => SegmentedButton<FormulaInputMode>(
                        showSelectedIcon: false,
                        segments: const <ButtonSegment<FormulaInputMode>>[
                          ButtonSegment<FormulaInputMode>(
                            value: FormulaInputMode.guided,
                            label: Text('Guided builder'),
                            icon: Icon(Icons.tune, size: 18),
                          ),
                          ButtonSegment<FormulaInputMode>(
                            value: FormulaInputMode.textEditor,
                            label: Text('Text editor'),
                            icon: Icon(Icons.edit_note, size: 18),
                          ),
                        ],
                        selected: <FormulaInputMode>{
                          column.formulaInputMode.value,
                        },
                        onSelectionChanged: (Set<FormulaInputMode> next) {
                          if (next.isEmpty) {
                            return;
                          }
                          column.formulaInputMode.value = next.first;
                          controller.onFormulaInputModeChanged(column.id);
                        },
                        emptySelectionAllowed: false,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Obx(() {
                      controller.formulaErrorsVersion.value;
                      if (column.formulaInputMode.value ==
                          FormulaInputMode.textEditor) {
                        return FormulaTextEditorField(
                          controller: column.formulaTextController,
                          schemas: controller.existingTableSchemas.toList(
                            growable: false,
                          ),
                          currentColumnNames: controller.columns
                              .map((ColumnDraft c) => c.nameController.text)
                              .toList(growable: false),
                          errorText: controller.formulaFieldErrors[column.id],
                          onChanged: () {
                            controller.onFormulaTextEditorInteraction(
                              column.id,
                            );
                          },
                        );
                      }
                      return GuidedFormulaBuilder(
                        key: ValueKey<String>('formula-${column.id}'),
                        host: controller,
                        guided: column.guided,
                        columnId: column.id,
                        theme: theme,
                      );
                    }),
                  ],
                );
              }
              if (column.type.value == TableColumnType.dropdown) {
                return Obx(() {
                  final String? err = controller.dropdownFieldErrors[column.id];
                  return DropdownColumnConfigBody(
                    sourceKind: column.dropdownSourceKind,
                    sourceTableId: column.dropdownSourceTableId,
                    sourceColumnId: column.dropdownSourceColumnId,
                    manualLinesController: column.dropdownOptionsController,
                    allSchemas: controller.existingTableSchemas,
                    errorText: err,
                  );
                });
              }
              return const SizedBox.shrink();
            }),
            const SizedBox(height: 8),
            Obx(
              () => CheckboxListTile(
                value: column.isRequired.value,
                onChanged: (bool? v) => column.isRequired.value = v ?? false,
                title: const Text('Required field'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
            Obx(
              () => CheckboxListTile(
                value: column.isUnique.value,
                onChanged: (bool? v) => column.isUnique.value = v ?? false,
                title: const Text('Unique value'),
                subtitle: const Text('Prevent duplicate values in this column'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _patternConfigSection({
    required ThemeData theme,
    required TextEditingController controller,
  }) {
    const List<String> tokens = <String>[
      '(DAY)',
      '(MONTH)',
      '(YEAR)',
      '(YEAR-2dig)',
      '(SEQ)',
      '(HOUR)',
      '(MIN)',
      '(USER)',
      '(BRANCH)',
    ];
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (BuildContext context, TextEditingValue value, Widget? child) {
        final String preview = _buildPatternPreview(value.text);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Pattern template',
                hintText: 'REF-(MONTH)-(YEAR-2dig)-(SEQ)',
              ),
            ),
            const SizedBox(height: 8),
            Text('Pattern tokens', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tokens
                  .map(
                    (String token) => ActionChip(
                      label: Text(token),
                      onPressed: () {
                        final TextEditingValue current = controller.value;
                        final String updated = current.text.replaceRange(
                          current.selection.start < 0
                              ? current.text.length
                              : current.selection.start,
                          current.selection.end < 0
                              ? current.text.length
                              : current.selection.end,
                          token,
                        );
                        final int caret =
                            (current.selection.start < 0
                                ? current.text.length
                                : current.selection.start) +
                            token.length;
                        controller.value = TextEditingValue(
                          text: updated,
                          selection: TextSelection.collapsed(offset: caret),
                        );
                      },
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 10),
            Text('Preview', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.outlineVariant),
                color: theme.colorScheme.surfaceContainerLow,
              ),
              child: Text(preview),
            ),
          ],
        );
      },
    );
  }

  String _buildPatternPreview(String rawPattern) {
    final DateTime now = DateTime.now();
    String pattern = rawPattern.trim();
    if (pattern.isEmpty) {
      pattern = 'REF-(MONTH)-(YEAR-2dig)-(SEQ)';
    }
    return pattern
        .replaceAll('(DAY)', now.day.toString().padLeft(2, '0'))
        .replaceAll('(MONTH)', now.month.toString().padLeft(2, '0'))
        .replaceAll('(YEAR-2dig)', (now.year % 100).toString().padLeft(2, '0'))
        .replaceAll('(YEAR)', now.year.toString())
        .replaceAll('(SEQ)', '0001')
        .replaceAll('(HOUR)', now.hour.toString().padLeft(2, '0'))
        .replaceAll('(MIN)', now.minute.toString().padLeft(2, '0'))
        .replaceAll('(USER)', 'USER')
        .replaceAll('(BRANCH)', 'MAIN');
  }

  Widget _stepBasicInfo(ThemeData theme) {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            controller: controller.tableNameController,
            decoration: const InputDecoration(
              labelText: 'Table name',
              hintText: 'e.g. Inventory',
            ),
          ),
          const SizedBox(height: 10),
          SearchableDropdownField<PageOption>(
            options: controller.pageOptions.toList(growable: false),
            value: controller.pageOptions.firstWhereOrNull(
              (PageOption p) => p.id == controller.selectedPageId.value,
            ),
            optionLabel: (PageOption p) => p.name,
            label: 'Assign page',
            hintText: 'Search page…',
            onChanged: (PageOption selected) {
              controller.selectedPageId.value = selected.id;
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller.descriptionController,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepCrud(ThemeData theme) {
    return Obx(() {
      final bool summary = controller.tableKind.value == TableKind.summary;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (summary) ...<Widget>[
            Text(
              'Summary tables are always read-only. Add, edit, and delete actions are disabled at runtime; '
              'rows are derived from the source table.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
          ],
          if (!summary) ...<Widget>[
            Text('Form fields', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(
              'Choose which columns appear on create and edit forms, and which are required in the form.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            ...controller.columns.map((ColumnDraft column) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: column.nameController,
                        builder: (
                          BuildContext context,
                          TextEditingValue value,
                          Widget? child,
                        ) {
                          final String label =
                              value.text.trim().isEmpty
                                  ? 'Column'
                                  : value.text.trim();
                          return Text(label, style: theme.textTheme.labelLarge);
                        },
                      ),
                      Obx(
                        () => CheckboxListTile(
                          value: column.includeInCreate.value,
                          onChanged:
                              (bool? v) =>
                                  column.includeInCreate.value = v ?? false,
                          title: const Text('Include in create form'),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ),
                      Obx(
                        () => CheckboxListTile(
                          value: column.includeInEdit.value,
                          onChanged:
                              (bool? v) =>
                                  column.includeInEdit.value = v ?? false,
                          title: const Text('Include in edit form'),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
          if (!summary) ...<Widget>[
            const SizedBox(height: 16),
            Text('Table View Options', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable Search Bar'),
              subtitle: const Text('Show search input above table rows'),
              value: controller.searchEnabled.value,
              onChanged: controller.setSearchEnabled,
            ),
            const SizedBox(height: 8),
            SegmentedButton<TableDataLoadingMode>(
              segments: const <ButtonSegment<TableDataLoadingMode>>[
                ButtonSegment<TableDataLoadingMode>(
                  value: TableDataLoadingMode.lazy,
                  label: Text('Lazy Loading'),
                ),
                ButtonSegment<TableDataLoadingMode>(
                  value: TableDataLoadingMode.pagination,
                  label: Text('Pagination'),
                ),
              ],
              selected: <TableDataLoadingMode>{
                controller.dataLoadingMode.value,
              },
              onSelectionChanged: (Set<TableDataLoadingMode> selection) {
                if (selection.isEmpty) {
                  return;
                }
                controller.setDataLoadingMode(selection.first);
              },
            ),
            const SizedBox(height: 8),
            if (controller.dataLoadingMode.value == TableDataLoadingMode.lazy)
              DropdownButtonFormField<int>(
                value: controller.lazyInitialLoad.value,
                decoration: const InputDecoration(
                  labelText: 'Initial rows loaded',
                ),
                items: const <int>[5, 10, 20, 30]
                    .map(
                      (int value) => DropdownMenuItem<int>(
                        value: value,
                        child: Text(value.toString()),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (int? value) {
                  if (value == null) {
                    return;
                  }
                  controller.setLazyInitialLoad(value);
                },
              )
            else
              DropdownButtonFormField<int>(
                value: controller.pageSize.value,
                decoration: const InputDecoration(
                  labelText: 'Show data per page',
                ),
                items: const <int>[5, 10, 20, 50]
                    .map(
                      (int value) => DropdownMenuItem<int>(
                        value: value,
                        child: Text(value.toString()),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (int? value) {
                  if (value == null) {
                    return;
                  }
                  controller.setPageSize(value);
                },
              ),
          ],
        ],
      );
    });
  }

  Widget _stepReview(ThemeData theme) {
    return Obx(() {
      final bool summary = controller.tableKind.value == TableKind.summary;
      final TableListDesignLayout? d = controller.selectedDesign.value;
      final String layoutReview =
          controller.selectedVisualLayoutKey.value ??
          (d == null ? '—' : CreateTableController.visualLayoutKeyForDesign(d));
      final String? pageId = controller.selectedPageId.value;
      final String pageName =
          pageId == null
              ? '—'
              : controller.pageOptions
                  .firstWhere(
                    (PageOption p) => p.id == pageId,
                    orElse: () => const PageOption(id: '', name: '—'),
                  )
                  .name;
      final String cols = controller.columns
          .map((c) => c.nameController.text.trim())
          .where((s) => s.isNotEmpty)
          .join(', ');
      final List<String> summaryColumnNames = controller.summaryColumns
          .map((SummaryColumnDraft c) => c.nameController.text.trim())
          .where((String name) => name.isNotEmpty)
          .toList(growable: false);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _reviewRow(
            theme,
            'Kind',
            summary ? 'Summary (aggregated)' : 'Standard',
          ),
          if (summary) ...<Widget>[
            _reviewRow(
              theme,
              'Summary columns',
              summaryColumnNames.isEmpty ? '—' : summaryColumnNames.join(', '),
            ),
          ] else ...<Widget>[
            _reviewRow(theme, 'Layout', layoutReview),
            _reviewRow(
              theme,
              'Swipe to delete',
              controller.swipeToDelete.value ? 'On' : 'Off',
            ),
            if (d == TableListDesignLayout.product)
              _reviewRow(
                theme,
                'Product display',
                controller.productDisplayMode.value == ProductDisplayMode.grid
                    ? 'Grid'
                    : 'List',
              ),
          ],
          _reviewRow(theme, 'Table name', controller.tableNameController.text),
          _reviewRow(theme, 'Page', pageName),
          _reviewRow(
            theme,
            'Mode',
            controller.mode.value == TableMode.crud ? 'CRUD' : 'Read only',
          ),
          if (!summary)
            _reviewRow(
              theme,
              'Search',
              controller.searchEnabled.value ? 'Enabled' : 'Disabled',
            ),
          if (!summary)
            _reviewRow(
              theme,
              'Loading',
              controller.dataLoadingMode.value == TableDataLoadingMode.lazy
                  ? 'Lazy (${controller.lazyInitialLoad.value} initial rows)'
                  : 'Pagination (${controller.pageSize.value} rows/page)',
            ),
          if (!summary) _reviewRow(theme, 'Columns', cols.isEmpty ? '—' : cols),
          if (summary)
            _reviewRow(
              theme,
              'Columns',
              summaryColumnNames.isEmpty ? '—' : summaryColumnNames.join(', '),
            ),
        ],
      );
    });
  }

  Widget _stepAffectingTables(ThemeData theme) {
    return Obx(() {
      if (!controller.isCrudStandardTable) {
        return const Text(
          'Affecting tables automation is available only for CRUD tables.',
        );
      }
      final List<TableSchemaEntity> targetTables =
          controller.affectingTargetTableOptions;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Configure row-level updates on related tables.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          ...controller.affectingTables.map((AffectingTableDraft affecting) {
            TableSchemaEntity? selectedTable;
            if (affecting.targetTableId.value != null) {
              for (final TableSchemaEntity schema in targetTables) {
                if (schema.id == affecting.targetTableId.value) {
                  selectedTable = schema;
                  break;
                }
              }
            }
            final List<TableColumnEntity> targetColumns =
                selectedTable?.columns ?? const <TableColumnEntity>[];
            TableColumnEntity? selectedMatchTarget;
            if (affecting.matchTargetColumnId.value != null) {
              for (final TableColumnEntity col in targetColumns) {
                if (col.id == affecting.matchTargetColumnId.value) {
                  selectedMatchTarget = col;
                  break;
                }
              }
            }
            ColumnDraft? selectedSourceMatch;
            if (affecting.matchSourceColumnId.value != null) {
              for (final ColumnDraft col in controller.columns) {
                if (col.id == affecting.matchSourceColumnId.value) {
                  selectedSourceMatch = col;
                  break;
                }
              }
            }
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Affected table rule',
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        IconButton(
                          onPressed:
                              () => controller.removeAffectingTableRule(
                                affecting.id,
                              ),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                    SearchableDropdownField<TableSchemaEntity>(
                      options: targetTables,
                      value: selectedTable,
                      label: 'Affected table',
                      optionLabel:
                          (TableSchemaEntity schema) =>
                              controller.tableDisplayLabel(schema),
                      onChanged: (TableSchemaEntity selected) {
                        affecting.targetTableId.value = selected.id;
                        affecting.matchTargetColumnId.value = null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Text('Match row by', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 6),
                    SearchableDropdownField<TableColumnEntity>(
                      options: targetColumns,
                      value: selectedMatchTarget,
                      label: 'Affected table column',
                      optionLabel: (TableColumnEntity col) => col.name,
                      onChanged: (TableColumnEntity selected) {
                        affecting.matchTargetColumnId.value = selected.id;
                      },
                    ),
                    const SizedBox(height: 8),
                    SearchableDropdownField<ColumnDraft>(
                      options: controller.columns.toList(growable: false),
                      value: selectedSourceMatch,
                      label: 'Current CRUD table column',
                      optionLabel:
                          (ColumnDraft col) =>
                              col.nameController.text.trim().isEmpty
                                  ? '(unnamed column)'
                                  : col.nameController.text.trim(),
                      onChanged: (ColumnDraft selected) {
                        affecting.matchSourceColumnId.value = selected.id;
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Column update rules',
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    ...affecting.rules.map((AffectingColumnRuleDraft rule) {
                      TableColumnEntity? selectedRuleColumn;
                      if (rule.targetColumnId.value != null) {
                        for (final TableColumnEntity col in targetColumns) {
                          if (col.id == rule.targetColumnId.value) {
                            selectedRuleColumn = col;
                            break;
                          }
                        }
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: SearchableDropdownField<
                                    TableColumnEntity
                                  >(
                                    options: targetColumns,
                                    value: selectedRuleColumn,
                                    label: 'Affected column',
                                    optionLabel:
                                        (TableColumnEntity col) => col.name,
                                    onChanged: (TableColumnEntity selected) {
                                      rule.targetColumnId.value = selected.id;
                                    },
                                  ),
                                ),
                                IconButton(
                                  onPressed:
                                      () =>
                                          controller.removeAffectingColumnRule(
                                            affecting.id,
                                            rule.id,
                                          ),
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            FormulaTextEditorField(
                              controller: rule.formulaController,
                              schemas: controller.existingTableSchemas.toList(
                                growable: false,
                              ),
                              currentColumnNames: controller.columns
                                  .map((ColumnDraft c) => c.nameController.text)
                                  .toList(growable: false),
                              errorText:
                                  controller
                                      .affectingFormulaErrors['${affecting.id}|${rule.id}'],
                              onChanged: () {},
                            ),
                          ],
                        ),
                      );
                    }),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed:
                            () =>
                                controller.addAffectingColumnRule(affecting.id),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Column Update Rule'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: controller.addAffectingTableRule,
              icon: const Icon(Icons.add),
              label: const Text('Add Affected Table'),
            ),
          ),
        ],
      );
    });
  }

  Widget _reviewRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
