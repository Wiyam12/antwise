import 'package:antwise/domain/entities/product_display_mode.dart';
import 'package:antwise/domain/entities/table_column_entity.dart';
import 'package:antwise/domain/entities/table_column_type.dart';
import 'package:antwise/domain/entities/table_data_loading_mode.dart';
import 'package:antwise/domain/entities/table_kind.dart';
import 'package:antwise/domain/entities/table_list_design_layout.dart';
import 'package:antwise/domain/entities/table_mode.dart';
import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/domain/entities/table_summary_config.dart';
import 'package:antwise/presentation/controllers/create_table_controller.dart'
    show CreateTableController;
import 'package:antwise/presentation/controllers/edit_table_controller.dart';
import 'package:antwise/presentation/models/formula_input_mode.dart';
import 'package:antwise/presentation/widgets/dropdown_column_config_body.dart';
import 'package:antwise/presentation/widgets/formula_text_editor_field.dart';
import 'package:antwise/presentation/widgets/guided_formula_builder.dart';
import 'package:antwise/presentation/widgets/number_column_config_section.dart';
import 'package:antwise/presentation/widgets/controlled_expansion_tile.dart';
import 'package:antwise/presentation/widgets/searchable_column_type_field.dart';
import 'package:antwise/presentation/widgets/searchable_dropdown_field.dart';
import 'package:antwise/presentation/widgets/text_column_config_section.dart';
import 'package:antwise/presentation/widgets/dynamic_builder_page_body.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:reorderables/reorderables.dart';

final List<TableColumnType> _columnTypeOptions = TableColumnType.values.toList(
  growable: false,
);

class EditTableScreen extends GetView<EditTableController> {
  const EditTableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Table')),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        final bool isSummary = controller.isSummaryTable;
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
              'edit-table-stepper-$isSummary-$isCrudStandard-$totalSteps',
            ),
            physics: const NeverScrollableScrollPhysics(),
            type: StepperType.vertical,
            currentStep: boundedCurrentStep,
            onStepTapped: (int step) {
              FocusScope.of(context).unfocus();
              controller.jumpToStep(step);
            },
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
                await controller.saveChanges();
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
                              ? controller.saveChanges
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
                              : Text(isLast ? 'Save' : 'Next'),
                    ),
                  ],
                ),
              );
            },
            steps: <Step>[
              Step(
                title: Text(
                  controller.isSummaryTable
                      ? 'Summary source'
                      : 'Design layout',
                ),
                isActive: controller.currentStep.value >= 0,
                state: StepState.indexed,
                content: _stepDesignLayout(theme, context),
              ),
              Step(
                title: const Text('Basic information'),
                isActive: controller.currentStep.value >= 1,
                state: StepState.indexed,
                content: _stepBasicInfo(theme),
              ),
              Step(
                title: Text(
                  controller.isSummaryTable ? 'Access mode' : 'CRUD behavior',
                ),
                isActive: controller.currentStep.value >= 2,
                state: StepState.indexed,
                content: _stepCrud(theme, context),
              ),
              Step(
                title: Text(
                  controller.isSummaryTable ? 'Summary structure' : 'Columns',
                ),
                isActive: controller.currentStep.value >= 3,
                state: StepState.indexed,
                content: _stepColumns(theme, context),
              ),
              if (!controller.isSummaryTable)
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
                    (controller.isSummaryTable
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

  Widget _stepDesignLayout(ThemeData theme, BuildContext context) {
    final bool isSummary = controller.isSummaryTable;
    if (isSummary) {
      return _summaryDesignEditable(theme);
    }
    final TableListDesignLayout? d = controller.persistedListDesign;
    final String? key = controller.selectedVisualLayoutKey.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Table type', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Opacity(
          opacity: 0.72,
          child: AbsorbPointer(
            child: SegmentedButton<TableKind>(
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
              showSelectedIcon: false,
              selected: <TableKind>{TableKind.standard},
              onSelectionChanged: (_) {},
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Table type, layout, and product display are fixed after creation. '
          'You can still adjust swipe to delete (standard tables).',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        if (d != null) ...<Widget>[
          Text('Visual template', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Opacity(
            opacity: 0.9,
            child: AbsorbPointer(
              child: LayoutBuilder(
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
                        final String k =
                            CreateTableController
                                .visualLayoutKeysOrdered[index];
                        final double ar =
                            CreateTableController
                                .visualLayoutCardAspectRatioByKey[k]!;
                        final bool selected = key == k;
                        return SizedBox(
                          width: childWidth,
                          child: AspectRatio(
                            aspectRatio: ar,
                            child: _visualLayoutWidgetCard(
                              theme: theme,
                              layoutKey: k,
                              optionIndex: index,
                              selected: selected,
                              onTap: () {},
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
          if (d == TableListDesignLayout.product) ...<Widget>[
            const SizedBox(height: 16),
            Text('Product display', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Opacity(
              opacity: 0.75,
              child: AbsorbPointer(
                child: SegmentedButton<ProductDisplayMode>(
                  showSelectedIcon: false,
                  segments: const <ButtonSegment<ProductDisplayMode>>[
                    ButtonSegment<ProductDisplayMode>(
                      value: ProductDisplayMode.list,
                      label: Text('List'),
                    ),
                    ButtonSegment<ProductDisplayMode>(
                      value: ProductDisplayMode.grid,
                      label: Text('Grid'),
                    ),
                  ],
                  selected: <ProductDisplayMode>{
                    controller.productDisplayMode.value ??
                        ProductDisplayMode.list,
                  },
                  onSelectionChanged: (_) {},
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Obx(
            () => SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable swipe to delete'),
              subtitle: const Text(
                'When on, swipe left on a row to delete. When off, use the delete icon.',
              ),
              value: controller.swipeToDelete.value,
              onChanged: controller.setSwipeToDelete,
            ),
          ),
        ],
      ],
    );
  }

  Widget _summaryDesignEditable(ThemeData theme) {
    final TableSchemaEntity? s = controller.editingSchema;
    if (s == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Table type', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Opacity(
          opacity: 0.75,
          child: AbsorbPointer(
            child: SegmentedButton<TableKind>(
              segments: const <ButtonSegment<TableKind>>[
                ButtonSegment<TableKind>(
                  value: TableKind.standard,
                  label: Text('Standard'),
                ),
                ButtonSegment<TableKind>(
                  value: TableKind.summary,
                  label: Text('Summary'),
                ),
              ],
              showSelectedIcon: false,
              selected: <TableKind>{TableKind.summary},
              onSelectionChanged: (_) {},
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Build summary columns dynamically. Each column can target a source '
          'table/column, choose grouping, and apply its own aggregation or formula.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        _summaryColumnsEditorSection(theme),
      ],
    );
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

  Widget _summaryColumnsEditorSection(ThemeData theme) {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: controller.summaryColumns.length,
            onReorder: controller.moveSummaryColumn,
            itemBuilder: (BuildContext context, int index) {
              final SummaryColumnDraft column =
                  controller.summaryColumns[index];
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
          _summaryAggregationPreviewForEdit(theme),
        ],
      ),
    );
  }

  Widget _stepBasicInfo(ThemeData theme) {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: 5),
          TextField(
            controller: controller.tableNameController,
            decoration: const InputDecoration(
              labelText: 'Table name',
              hintText: 'e.g. Inventory',
            ),
          ),
          const SizedBox(height: 10),
          AbsorbPointer(
            absorbing: true,
            child: Opacity(
              opacity: 0.7,
              child: DropdownButtonFormField<String>(
                value: controller.selectedPageId.value,
                decoration: const InputDecoration(
                  labelText: 'Page (read-only after creation)',
                ),
                items: controller.pageOptions
                    .map<DropdownMenuItem<String>>(
                      (PageOption p) => DropdownMenuItem<String>(
                        value: p.id,
                        child: Text(p.name),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (_) {},
              ),
            ),
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

  Widget _stepCrud(ThemeData theme, BuildContext context) {
    final bool summary = controller.isSummaryTable;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (summary) ...<Widget>[
          Text(
            'Summary tables are always read-only. Add, edit, and delete actions '
            'are disabled at runtime; rows are derived from the source table.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
        ],
        if (!summary) ...<Widget>[
          Text('Table behavior', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<TableMode>(
            segments: const <ButtonSegment<TableMode>>[
              ButtonSegment<TableMode>(
                value: TableMode.crud,
                label: Text('CRUD'),
              ),
              ButtonSegment<TableMode>(
                value: TableMode.readOnly,
                label: Text('Read only'),
              ),
            ],
            showSelectedIcon: false,
            selected: <TableMode>{controller.mode.value},
            onSelectionChanged: (Set<TableMode> selection) {
              if (selection.isEmpty) return;
              controller.setMode(selection.first);
            },
          ),
          const SizedBox(height: 6),
          Text(
            controller.mode.value == TableMode.crud
                ? 'Allow creating, editing, and deleting rows from the builder.'
                : 'Rows are shown for reference only; add, edit, and delete are hidden.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          if (controller.mode.value == TableMode.crud) ...<Widget>[
            Text('Form fields', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(
              'Choose which columns appear on create and edit forms, and which are required in the form.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            ...controller.columns.map((EditColumnDraft column) {
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
                      Obx(() {
                        if (column.type.value != TableColumnType.formula) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            'Formula values are read-only on create and edit forms.',
                            style: theme.textTheme.bodySmall,
                          ),
                        );
                      }),
                      Obx(
                        () => CheckboxListTile(
                          value: column.includeInCreate.value,
                          onChanged: (bool? v) {
                            if (v != null) {
                              column.includeInCreate.value = v;
                            }
                          },
                          title: const Text('Include in create form'),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ),
                      Obx(
                        () => CheckboxListTile(
                          value: column.includeInEdit.value,
                          onChanged: (bool? v) {
                            if (v != null) {
                              column.includeInEdit.value = v;
                            }
                          },
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
            showSelectedIcon: false,
            selected: <TableDataLoadingMode>{controller.dataLoadingMode.value},
            onSelectionChanged: (Set<TableDataLoadingMode> selection) {
              if (selection.isEmpty) return;
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
                if (value == null) return;
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
                if (value == null) return;
                controller.setPageSize(value);
              },
            ),
          if (controller.isReadOnlyTable) ...<Widget>[
            const SizedBox(height: 16),
            _readOnlyRowsSection(context),
          ],
        ],
      ],
    );
  }

  Widget _stepColumns(ThemeData theme, BuildContext context) {
    return Obx(() {
      // Ensure this Obx always tracks at least one observable across all branches.
      final int _ = controller.currentStep.value;
      if (controller.isSummaryTable) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Columns are generated for you: the group-by field keeps its label from '
              'the source table, and a "Total" column is added as an auto-calculated formula field.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            _summaryAggregationPreviewForEdit(theme),
            const SizedBox(height: 8),
            Text(
              'The summary structure is fixed; column definitions come from the stored schema.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            ...controller.columns.map(
              (EditColumnDraft column) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.view_column_outlined),
                title: Text(
                  column.nameController.text.trim().isEmpty
                      ? '(unnamed)'
                      : column.nameController.text.trim(),
                ),
                subtitle: Obx(() => Text(column.type.value.storageValue)),
              ),
            ),
          ],
        );
      }
      if (controller.persistedListDesign == null) {
        return const Text('Missing layout in schema.');
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            controller.persistedListDesign == TableListDesignLayout.contact
                ? 'Edit labels and optional settings. Column types are fixed for this layout.'
                : controller.persistedListDesign ==
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
                  (EditColumnDraft column) => Container(
                    key: ValueKey<String>('edit-column-${column.id}'),
                    child: _editColumnCard(theme, column, context),
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
                            .map((EditColumnDraft c) => c.nameController.text)
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

  Widget _summaryAggregationPreviewForEdit(ThemeData theme) {
    final bool useSummaryDrafts = controller.isSummaryTable;
    List<String> headers = (useSummaryDrafts
            ? controller.summaryColumns
                .map((SummaryColumnDraft c) => c.nameController.text.trim())
                .toList(growable: false)
            : controller.columns
                .map((EditColumnDraft c) => c.nameController.text.trim())
                .toList(growable: false))
        .map((String n) {
          return n.isEmpty ? 'Column' : n;
        })
        .take(3)
        .toList(growable: false);
    if (headers.isEmpty) {
      headers = <String>['Column'];
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
                        .map((String h) => _previewCell(theme, h, header: true))
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

  Widget _editColumnCard(
    ThemeData theme,
    EditColumnDraft column,
    BuildContext context,
  ) {
    return Obx(() {
      final bool lockType = !controller.canEditColumnType(column);
      final bool showRemove = controller.canRemoveColumn(column);
      final String title =
          column.nameController.text.trim().isEmpty
              ? 'Column'
              : column.nameController.text.trim();
      return Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ControlledExpansionTile(
          expanded: controller.expandedColumnId.value == column.id,
          onExpansionChanged: (bool expanded) {
            if (expanded) {
              controller.expandedColumnId.value = column.id;
            } else if (controller.expandedColumnId.value == column.id) {
              controller.expandedColumnId.value = null;
            }
          },
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
            const SizedBox(height: 8),
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
                child: Text(columnDataTypeLabel(column.type.value)),
              )
            else
              SearchableColumnTypeField(
                selectedType: column.type.value,
                allowedTypes: _columnTypeOptions,
                onChanged: (TableColumnType value) {
                  final TableColumnType previous = column.type.value;
                  controller.onColumnDataTypeChanged(
                    column.id,
                    previous,
                    value,
                  );
                  column.type.value = value;
                },
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
                          if (next.isEmpty) return;
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
                              .map((EditColumnDraft c) => c.nameController.text)
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
                    const SizedBox(height: 12),
                    Obx(() {
                      if (controller.mode.value != TableMode.crud) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          CheckboxListTile(
                            value: column.includeInCreate.value,
                            onChanged: (bool? v) {
                              if (v != null) {
                                column.includeInCreate.value = v;
                              }
                            },
                            title: const Text('Include in create form'),
                            subtitle: const Text(
                              'Shown as read-only on the add-row form',
                            ),
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                          CheckboxListTile(
                            value: column.includeInEdit.value,
                            onChanged: (bool? v) {
                              if (v != null) {
                                column.includeInEdit.value = v;
                              }
                            },
                            title: const Text('Include in edit form'),
                            subtitle: const Text(
                              'Shown as read-only on the edit-row form',
                            ),
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        ],
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
                    excludeTableId: controller.editingTableId,
                  );
                });
              }
              return const SizedBox.shrink();
            }),
            const SizedBox(height: 8),
            if (controller.mode.value == TableMode.crud) ...<Widget>[
              Obx(
                () => CheckboxListTile(
                  value: column.isRequired.value,
                  onChanged: (bool? v) {
                    if (v != null) column.isRequired.value = v;
                  },
                  title: const Text('Required field'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
              Obx(
                () => CheckboxListTile(
                  value: column.isUnique.value,
                  onChanged: (bool? v) {
                    if (v != null) column.isUnique.value = v;
                  },
                  title: const Text('Unique value'),
                  subtitle: const Text(
                    'Prevent duplicate values in this column',
                  ),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
            ],
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

  Widget _stepAffectingTables(ThemeData theme) {
    return Obx(() {
      if (!controller.isCrudStandardTable) {
        return const Text(
          'Affecting tables apply only to CRUD standard tables.',
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
            EditColumnDraft? selectedSourceMatch;
            if (affecting.matchSourceColumnId.value != null) {
              for (final EditColumnDraft col in controller.columns) {
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
                      optionLabel: (TableSchemaEntity schema) {
                        return controller.tableDisplayLabel(schema);
                      },
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
                    SearchableDropdownField<EditColumnDraft>(
                      options: controller.columns.toList(growable: false),
                      value: selectedSourceMatch,
                      label: 'Current CRUD table column',
                      optionLabel: (EditColumnDraft col) {
                        return col.nameController.text.trim().isEmpty
                            ? '(unnamed column)'
                            : col.nameController.text.trim();
                      },
                      onChanged: (EditColumnDraft selected) {
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
                                  onPressed: () {
                                    controller.removeAffectingColumnRule(
                                      affecting.id,
                                      rule.id,
                                    );
                                  },
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
                                  .map(
                                    (EditColumnDraft c) =>
                                        c.nameController.text,
                                  )
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

  Widget _stepReview(ThemeData theme) {
    return Obx(() {
      final bool summary = controller.isSummaryTable;
      final TableListDesignLayout? d = controller.persistedListDesign;
      final String layoutReview =
          controller.selectedVisualLayoutKey.value ??
          (d == null ? '—' : CreateTableController.visualLayoutKeyForDesign(d));
      final String? pageId = controller.selectedPageId.value;
      String pageName = '—';
      if (pageId != null) {
        for (final PageOption p in controller.pageOptions) {
          if (p.id == pageId) {
            pageName = p.name;
            break;
          }
        }
      }
      final String cols = controller.columns
          .map((c) => c.nameController.text.trim())
          .where((s) => s.isNotEmpty)
          .join(', ');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _reviewRow(
            theme,
            'Kind',
            summary ? 'Summary (aggregated)' : 'Standard',
          ),
          if (!summary) ...<Widget>[
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
                (controller.productDisplayMode.value ??
                            ProductDisplayMode.list) ==
                        ProductDisplayMode.grid
                    ? 'Grid'
                    : 'List',
              ),
          ],
          _reviewRow(theme, 'Table name', controller.tableNameController.text),
          _reviewRow(theme, 'Page', pageName),
          _reviewRow(
            theme,
            'Mode',
            summary
                ? 'Read only (summary)'
                : (controller.mode.value == TableMode.crud
                    ? 'CRUD'
                    : 'Read only'),
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
          _reviewRow(theme, 'Columns', cols.isEmpty ? '—' : cols),
        ],
      );
    });
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
                              controller.productDisplayMode.value ??
                              ProductDisplayMode.list,
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

  Widget _readOnlyRowsSection(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Obx(() {
      final bool manual =
          controller.readOnlyPopulationMode.value ==
          EditReadOnlyRowPopulationMode.manual;
      final List<TableSchemaEntity> sourceTables = controller
          .existingTableSchemas
          .where((TableSchemaEntity s) => s.tableKind != TableKind.summary)
          .toList(growable: false);
      TableSchemaEntity? selectedKeySchema;
      final String? selectedKeyTableId =
          controller.readOnlyPopulateMapping.uniqueKeyTableId.value;
      if (selectedKeyTableId != null) {
        for (final TableSchemaEntity s in sourceTables) {
          if (s.id == selectedKeyTableId) {
            selectedKeySchema = s;
            break;
          }
        }
      }
      final List<TableColumnEntity> keyColumns =
          selectedKeySchema?.columns ?? const <TableColumnEntity>[];
      TableColumnEntity? selectedKeyColumn;
      final String? selectedKeyColumnId =
          controller.readOnlyPopulateMapping.uniqueKeyColumnId.value;
      if (selectedKeyColumnId != null) {
        for (final TableColumnEntity c in keyColumns) {
          if (c.id == selectedKeyColumnId) {
            selectedKeyColumn = c;
            break;
          }
        }
      }
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Read-only rows data', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              SegmentedButton<EditReadOnlyRowPopulationMode>(
                segments: const <ButtonSegment<EditReadOnlyRowPopulationMode>>[
                  ButtonSegment(
                    value: EditReadOnlyRowPopulationMode.manual,
                    label: Text('Manual Row Entry'),
                  ),
                  ButtonSegment(
                    value: EditReadOnlyRowPopulationMode.sourceMap,
                    label: Text('Populate From Source Table'),
                  ),
                ],
                selected: <EditReadOnlyRowPopulationMode>{
                  controller.readOnlyPopulationMode.value,
                },
                onSelectionChanged: (Set<EditReadOnlyRowPopulationMode> sel) {
                  if (sel.isEmpty) return;
                  controller.setReadOnlyPopulationMode(sel.first);
                },
              ),
              const SizedBox(height: 10),
              if (manual) ...<Widget>[
                ...controller.readOnlyRowsDrafts.map(
                  (EditReadOnlyRowDraft row) => _readOnlyRowCard(theme, row),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: controller.addReadOnlyDraftRow,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Row'),
                  ),
                ),
              ] else ...<Widget>[
                SearchableDropdownField<TableSchemaEntity>(
                  options: sourceTables,
                  value: selectedKeySchema,
                  label: 'Source table for unique key',
                  optionLabel:
                      (TableSchemaEntity s) => controller.tableDisplayLabel(s),
                  onChanged: (TableSchemaEntity selected) {
                    controller.readOnlyPopulateMapping.uniqueKeyTableId.value =
                        selected.id;
                    controller.readOnlyPopulateMapping.uniqueKeyColumnId.value =
                        null;
                  },
                ),
                const SizedBox(height: 8),
                SearchableDropdownField<TableColumnEntity>(
                  options: keyColumns,
                  value: selectedKeyColumn,
                  label: 'Unique key column',
                  optionLabel: (TableColumnEntity c) => c.name,
                  onChanged: (TableColumnEntity selected) {
                    controller.readOnlyPopulateMapping.uniqueKeyColumnId.value =
                        selected.id;
                  },
                ),
                const SizedBox(height: 10),
                ...controller.columns.map(
                  (EditColumnDraft column) => _mappingColumnCard(theme, column),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: controller.regenerateReadOnlyPreview,
                    icon: const Icon(Icons.preview_outlined),
                    label: const Text('Preview Generated Rows'),
                  ),
                ),
                if (controller.readOnlyGeneratedPreview.isNotEmpty)
                  _previewGeneratedRows(theme),
              ],
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: controller.applyReadOnlyRowsData,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Apply Rows Data'),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _readOnlyRowCard(ThemeData theme, EditReadOnlyRowDraft row) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: Text('Row', style: theme.textTheme.titleSmall)),
                IconButton(
                  onPressed: () => controller.removeReadOnlyDraftRow(row.id),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            ...controller.columns.map((EditColumnDraft column) {
              final EditReadOnlyCellDraft? cell = row.cells[column.id];
              if (cell == null) return const SizedBox.shrink();
              return _cellEditor(
                theme,
                cell,
                column,
                'readonly:${row.id}:${column.id}',
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _mappingColumnCard(ThemeData theme, EditColumnDraft column) {
    final EditReadOnlyCellDraft cell =
        controller.readOnlyPopulateMapping.cells[column.id] ??
        EditReadOnlyCellDraft();
    controller.readOnlyPopulateMapping.cells[column.id] = cell;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: _cellEditor(theme, cell, column, 'map:${column.id}'),
      ),
    );
  }

  Widget _cellEditor(
    ThemeData theme,
    EditReadOnlyCellDraft cell,
    EditColumnDraft column,
    String formulaKey,
  ) {
    return Obx(() {
      final List<TableSchemaEntity> sourceTables = controller
          .existingTableSchemas
          .where((TableSchemaEntity s) => s.tableKind != TableKind.summary)
          .toList(growable: false);
      TableSchemaEntity? selectedSchema;
      if (cell.sourceTableId.value != null) {
        for (final TableSchemaEntity s in sourceTables) {
          if (s.id == cell.sourceTableId.value) {
            selectedSchema = s;
            break;
          }
        }
      }
      final List<TableColumnEntity> sourceColumns =
          selectedSchema?.columns ?? const <TableColumnEntity>[];
      TableColumnEntity? selectedColumn;
      if (cell.sourceColumnId.value != null) {
        for (final TableColumnEntity c in sourceColumns) {
          if (c.id == cell.sourceColumnId.value) {
            selectedColumn = c;
            break;
          }
        }
      }
      final String label =
          column.nameController.text.trim().isEmpty
              ? 'Column'
              : column.nameController.text.trim();
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Column: $label', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            SegmentedButton<EditReadOnlyValueSource>(
              segments: const <ButtonSegment<EditReadOnlyValueSource>>[
                ButtonSegment(
                  value: EditReadOnlyValueSource.manual,
                  label: Text('Manual'),
                ),
                ButtonSegment(
                  value: EditReadOnlyValueSource.formula,
                  label: Text('Formula'),
                ),
                ButtonSegment(
                  value: EditReadOnlyValueSource.auto,
                  label: Text('Auto Generated'),
                ),
              ],
              selected: <EditReadOnlyValueSource>{cell.source.value},
              onSelectionChanged: (Set<EditReadOnlyValueSource> selection) {
                if (selection.isEmpty) return;
                cell.source.value = selection.first;
                if (selection.first != EditReadOnlyValueSource.formula) {
                  controller.clearFormulaErrorsForKey(formulaKey);
                } else {
                  controller.onFormulaInputModeChanged(formulaKey);
                }
              },
            ),
            const SizedBox(height: 8),
            if (cell.source.value == EditReadOnlyValueSource.manual)
              TextField(
                controller: cell.manualController,
                decoration: const InputDecoration(labelText: 'Value'),
              ),
            if (cell.source.value == EditReadOnlyValueSource.formula)
              _readOnlyCellFormulaConfig(theme, cell, formulaKey),
            if (cell.source.value == EditReadOnlyValueSource.auto) ...<Widget>[
              SearchableDropdownField<TableSchemaEntity>(
                options: sourceTables,
                value: selectedSchema,
                label: 'Source Table',
                optionLabel:
                    (TableSchemaEntity s) => controller.tableDisplayLabel(s),
                onChanged: (TableSchemaEntity selected) {
                  cell.sourceTableId.value = selected.id;
                  cell.sourceColumnId.value = null;
                },
              ),
              const SizedBox(height: 8),
              SearchableDropdownField<TableColumnEntity>(
                options: sourceColumns,
                value: selectedColumn,
                label: 'Source Column',
                optionLabel: (TableColumnEntity c) => c.name,
                onChanged: (TableColumnEntity selected) {
                  cell.sourceColumnId.value = selected.id;
                },
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _readOnlyCellFormulaConfig(
    ThemeData theme,
    EditReadOnlyCellDraft cell,
    String formulaKey,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Formula input mode', style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        Obx(
          () => SegmentedButton<FormulaInputMode>(
            showSelectedIcon: false,
            segments: const <ButtonSegment<FormulaInputMode>>[
              ButtonSegment(
                value: FormulaInputMode.guided,
                label: Text('Guided'),
                icon: Icon(Icons.tune, size: 16),
              ),
              ButtonSegment(
                value: FormulaInputMode.textEditor,
                label: Text('Text'),
                icon: Icon(Icons.edit_note, size: 16),
              ),
            ],
            selected: <FormulaInputMode>{cell.formulaInputMode.value},
            onSelectionChanged: (Set<FormulaInputMode> next) {
              if (next.isEmpty) return;
              cell.formulaInputMode.value = next.first;
              controller.onFormulaInputModeChanged(formulaKey);
            },
            emptySelectionAllowed: false,
          ),
        ),
        const SizedBox(height: 8),
        Obx(() {
          controller.formulaErrorsVersion.value;
          if (cell.formulaInputMode.value == FormulaInputMode.textEditor) {
            return FormulaTextEditorField(
              controller: cell.formulaTextController,
              schemas: controller.existingTableSchemas.toList(growable: false),
              currentColumnNames: controller.columns
                  .map((EditColumnDraft c) => c.nameController.text)
                  .toList(growable: false),
              errorText: controller.formulaFieldErrors[formulaKey],
              onChanged: () {
                controller.onFormulaTextEditorInteraction(formulaKey);
              },
            );
          }
          return GuidedFormulaBuilder(
            key: ValueKey<String>(formulaKey),
            host: controller,
            guided: cell.guided,
            columnId: formulaKey,
            theme: theme,
          );
        }),
      ],
    );
  }

  Widget _previewGeneratedRows(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Preview', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            ...controller.readOnlyGeneratedPreview.map((
              Map<String, dynamic> row,
            ) {
              final String rowText = controller.columns
                  .map((EditColumnDraft c) => (row[c.id] ?? '').toString())
                  .join(' | ');
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(rowText, style: theme.textTheme.bodySmall),
              );
            }),
          ],
        ),
      ),
    );
  }
}
