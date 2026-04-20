import 'package:antwise/domain/entities/product_display_mode.dart';
import 'package:antwise/domain/entities/table_column_type.dart';
import 'package:antwise/domain/entities/table_data_loading_mode.dart';
import 'package:antwise/domain/entities/table_kind.dart';
import 'package:antwise/domain/entities/table_list_design_layout.dart';
import 'package:antwise/domain/entities/table_mode.dart';
import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/presentation/controllers/create_table_controller.dart';
import 'package:antwise/presentation/models/column_draft.dart';
import 'package:antwise/presentation/widgets/dropdown_column_config_body.dart';
import 'package:antwise/presentation/widgets/guided_formula_builder.dart';
import 'package:antwise/presentation/widgets/searchable_column_type_field.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
          child: Stepper(
            physics: const NeverScrollableScrollPhysics(),
            type: StepperType.vertical,
            currentStep: controller.currentStep.value,
            onStepContinue: () async {
              if (controller.currentStep.value == 4) {
                await controller.submit();
              } else {
                await controller.goNext();
              }
            },
            onStepCancel: controller.goBack,
            controlsBuilder: (BuildContext context, ControlsDetails details) {
              final int step = controller.currentStep.value;
              final bool isLast = step == 4;
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
                state:
                    controller.currentStep.value > 0
                        ? StepState.complete
                        : StepState.indexed,
                content: _stepDesignLayout(theme),
              ),
              Step(
                title: const Text('Basic information'),
                isActive: controller.currentStep.value >= 1,
                state:
                    controller.currentStep.value > 1
                        ? StepState.complete
                        : StepState.indexed,
                content: _stepBasicInfo(theme),
              ),
              Step(
                title: Text(
                  controller.tableKind.value == TableKind.summary
                      ? 'Access mode'
                      : 'CRUD behavior',
                ),
                isActive: controller.currentStep.value >= 2,
                state:
                    controller.currentStep.value > 2
                        ? StepState.complete
                        : StepState.indexed,
                content: _stepCrud(theme),
              ),
              Step(
                title: Text(
                  controller.tableKind.value == TableKind.summary
                      ? 'Summary structure'
                      : 'Columns',
                ),
                isActive: controller.currentStep.value >= 3,
                state:
                    controller.currentStep.value > 3
                        ? StepState.complete
                        : StepState.indexed,
                content: _stepColumns(theme),
              ),
              Step(
                title: const Text('Review'),
                isActive: controller.currentStep.value >= 4,
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
              DropdownButtonFormField<String>(
                value: controller.summarySourceTableId.value,
                decoration: const InputDecoration(
                  labelText: 'Source table',
                  helperText:
                      'Data is grouped by one column and summed on another',
                ),
                items: controller.summarySourceTableOptions
                    .map(
                      (s) => DropdownMenuItem<String>(
                        value: s.id,
                        child: Text(s.name),
                      ),
                    )
                    .toList(growable: false),
                onChanged: controller.onSummarySourceTableChanged,
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (BuildContext context) {
                  final src = controller.summarySourceSchema(
                    controller.summarySourceTableId.value,
                  );
                  final groupItems = controller.summaryGroupByCandidates(src);
                  final aggregateItems = controller.summaryAggregateCandidates(
                    src,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      DropdownButtonFormField<String>(
                        value:
                            groupItems.any(
                                  (c) =>
                                      c.id ==
                                      controller.summaryGroupByColumnId.value,
                                )
                                ? controller.summaryGroupByColumnId.value
                                : null,
                        decoration: const InputDecoration(
                          labelText: 'Group by (row key)',
                        ),
                        items: groupItems
                            .map(
                              (c) => DropdownMenuItem<String>(
                                value: c.id,
                                child: Text(c.name),
                              ),
                            )
                            .toList(growable: false),
                        onChanged:
                            (String? id) =>
                                controller.summaryGroupByColumnId.value = id,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value:
                            aggregateItems.any(
                                  (c) =>
                                      c.id ==
                                      controller.summaryAggregateColumnId.value,
                                )
                                ? controller.summaryAggregateColumnId.value
                                : null,
                        decoration: const InputDecoration(
                          labelText: 'Value to sum',
                          helperText:
                              'Numeric or currency columns from the source',
                        ),
                        items: aggregateItems
                            .map(
                              (c) => DropdownMenuItem<String>(
                                value: c.id,
                                child: Text(c.name),
                              ),
                            )
                            .toList(growable: false),
                        onChanged:
                            (String? id) =>
                                controller.summaryAggregateColumnId.value = id,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              _summaryAggregationPreview(theme),
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
                      final String asset =
                          CreateTableController.visualLayoutAssetByKey[key]!;
                      final double aspectRatio =
                          CreateTableController
                              .visualLayoutCardAspectRatioByKey[key]!;
                      final bool isSelected =
                          controller.selectedVisualLayoutKey.value == key;
                      return SizedBox(
                        width: childWidth,
                        child: AspectRatio(
                          aspectRatio: aspectRatio,
                          child: _visualLayoutImageCard(
                            theme: theme,
                            assetPath: asset,
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
                    value: ProductDisplayMode.list,
                    label: Text('List'),
                  ),
                  ButtonSegment<ProductDisplayMode>(
                    value: ProductDisplayMode.grid,
                    label: Text('Grid'),
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

  Widget _summaryAggregationPreview(ThemeData theme) {
    final src = controller.summarySourceSchema(
      controller.summarySourceTableId.value,
    );
    String groupName = '—';
    String valueName = '—';
    if (src != null && controller.summaryGroupByColumnId.value != null) {
      for (final c in src.columns) {
        if (c.id == controller.summaryGroupByColumnId.value) {
          groupName = c.name;
        }
      }
    }
    if (src != null && controller.summaryAggregateColumnId.value != null) {
      for (final c in src.columns) {
        if (c.id == controller.summaryAggregateColumnId.value) {
          valueName = c.name;
        }
      }
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
              'Each distinct "$groupName" becomes one row. A "Total" column shows '
              'SUM($valueName) for that group (auto-calculated, formula-type column).',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Table(
              border: TableBorder.all(color: theme.colorScheme.outlineVariant),
              columnWidths: const <int, TableColumnWidth>{
                0: FlexColumnWidth(1.2),
                1: FlexColumnWidth(1),
              },
              children: <TableRow>[
                TableRow(
                  children: <Widget>[
                    _previewCell(theme, groupName, header: true),
                    _previewCell(theme, 'Total', header: true),
                  ],
                ),
                TableRow(
                  children: <Widget>[
                    _previewCell(theme, '…'),
                    _previewCell(theme, '…'),
                  ],
                ),
              ],
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

  Widget _visualLayoutImageCard({
    required ThemeData theme,
    required String assetPath,
    required String layoutKey,
    required int optionIndex,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final ColorScheme cs = theme.colorScheme;
    const double radius = 14;
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
                    child: SizedBox.expand(
                      child: Image.asset(
                        assetPath,
                        key: ValueKey<String>(layoutKey),
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (
                          BuildContext context,
                          Object error,
                          StackTrace? stackTrace,
                        ) {
                          return ColoredBox(
                            color: cs.surfaceContainerHighest,
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: cs.onSurfaceVariant,
                              size: 40,
                            ),
                          );
                        },
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
              'Columns are generated for you: the group-by field keeps its label from the source table, '
              'and a "Total" column is added as an auto-calculated formula field (values are computed at runtime).',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            _summaryAggregationPreview(theme),
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
          ...controller.columns.map(
            (ColumnDraft column) => _columnCard(theme, column),
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

  Widget _columnCard(ThemeData theme, ColumnDraft column) {
    return Obx(() {
      final bool lockType = !controller.canEditColumnType(column);
      final bool showRemove = controller.canRemoveColumn(column);
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
                    child: Text('Column', style: theme.textTheme.titleSmall),
                  ),
                  if (showRemove)
                    IconButton(
                      onPressed: () => controller.removeColumn(column.id),
                      icon: const Icon(Icons.delete_outline),
                    ),
                ],
              ),
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
                Obx(
                  () => SearchableColumnTypeField(
                    selectedType: column.type.value,
                    allowedTypes: TableColumnType.values,
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
                ),
              const SizedBox(height: 8),
              if (!lockType)
                Obx(() {
                  if (column.type.value == TableColumnType.autoGenerated) {
                    return TextField(
                      controller: column.patternController,
                      decoration: const InputDecoration(
                        labelText: 'Auto pattern',
                        hintText: 'INV-{YYYY}-{SEQ}',
                      ),
                    );
                  }
                  if (column.type.value == TableColumnType.formula) {
                    return GuidedFormulaBuilder(
                      key: ValueKey<String>('formula-${column.id}'),
                      host: controller,
                      guided: column.guided,
                      columnId: column.id,
                      theme: theme,
                    );
                  }
                  if (column.type.value == TableColumnType.dropdown) {
                    return Obx(() {
                      final String? err =
                          controller.dropdownFieldErrors[column.id];
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
              if (!lockType) const SizedBox(height: 8),
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
                  subtitle: const Text(
                    'Prevent duplicate values in this column',
                  ),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
            ],
          ),
        ),
      );
    });
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
          DropdownButtonFormField<String>(
            value: controller.selectedPageId.value,
            decoration: const InputDecoration(labelText: 'Assign page'),
            items: controller.pageOptions
                .map(
                  (PageOption p) => DropdownMenuItem<String>(
                    value: p.id,
                    child: Text(p.name),
                  ),
                )
                .toList(growable: false),
            onChanged: (String? id) => controller.selectedPageId.value = id,
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
            selected: <TableMode>{controller.mode.value},
            onSelectionChanged: (Set<TableMode> selection) {
              if (summary) {
                return;
              }
              if (selection.isEmpty) {
                return;
              }
              controller.setMode(selection.first);
            },
          ),
          if (!summary && controller.mode.value == TableMode.crud) ...<Widget>[
            const SizedBox(height: 16),
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
      final TableSchemaEntity? src =
          summary
              ? controller.summarySourceSchema(
                controller.summarySourceTableId.value,
              )
              : null;
      String groupLabel = '—';
      String sumLabel = '—';
      if (src != null) {
        for (final c in src.columns) {
          if (c.id == controller.summaryGroupByColumnId.value) {
            groupLabel = c.name;
          }
          if (c.id == controller.summaryAggregateColumnId.value) {
            sumLabel = c.name;
          }
        }
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _reviewRow(
            theme,
            'Kind',
            summary ? 'Summary (aggregated)' : 'Standard',
          ),
          if (summary) ...<Widget>[
            _reviewRow(theme, 'Source table', src?.name ?? '—'),
            _reviewRow(theme, 'Group by', groupLabel),
            _reviewRow(theme, 'Sum column', sumLabel),
            _reviewRow(theme, 'Aggregation', 'SUM'),
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
            _reviewRow(theme, 'Columns', '$groupLabel, Total (auto)'),
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
