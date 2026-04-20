import 'package:antwise/domain/entities/table_column_type.dart';
import 'package:antwise/domain/entities/table_data_loading_mode.dart';
import 'package:antwise/domain/entities/table_mode.dart';
import 'package:antwise/presentation/controllers/edit_table_controller.dart';
import 'package:antwise/presentation/widgets/dropdown_column_config_body.dart';
import 'package:antwise/presentation/widgets/guided_formula_builder.dart';
import 'package:antwise/presentation/widgets/searchable_column_type_field.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class EditTableScreen extends GetView<EditTableController> {
  const EditTableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Table')),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Obx(
        () => SizedBox(
          width: 220,
          child: FilledButton(
            onPressed:
                controller.isSaving.value ? null : controller.saveChanges,
            child: const Text('Save Changes'),
          ),
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: <Widget>[
            TextField(
              controller: controller.tableNameController,
              decoration: const InputDecoration(labelText: 'Table Name'),
            ),
            const SizedBox(height: 12),
            if (controller.isSummaryTable) ...<Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Summary table',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'This table is generated from a source table and stays read-only. '
                        'Column structure and CRUD behavior are locked for summary tables.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...<Widget>[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable swipe to delete'),
                subtitle: const Text(
                  'When on, swipe left on a row to delete. When off, use the delete icon.',
                ),
                value: controller.swipeToDelete.value,
                onChanged: controller.setSwipeToDelete,
              ),
              const SizedBox(height: 16),
              Text(
                'Table behavior',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Obx(
                () => SegmentedButton<TableMode>(
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
                    if (selection.isEmpty) {
                      return;
                    }
                    controller.setMode(selection.first);
                  },
                ),
              ),
              const SizedBox(height: 8),
              Obx(
                () => Text(
                  controller.mode.value == TableMode.crud
                      ? 'Allow creating, editing, and deleting rows from the builder.'
                      : 'Rows are shown for reference only; add, edit, and delete are hidden.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Table View Options',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Obx(
              () => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable Search Bar'),
                subtitle: const Text('Show search input above table rows'),
                value: controller.searchEnabled.value,
                onChanged: controller.setSearchEnabled,
              ),
            ),
            const SizedBox(height: 8),
            Obx(
              () => SegmentedButton<TableDataLoadingMode>(
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
            ),
            const SizedBox(height: 8),
            Obx(() {
              if (controller.dataLoadingMode.value ==
                  TableDataLoadingMode.lazy) {
                return DropdownButtonFormField<int>(
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
                );
              }
              return DropdownButtonFormField<int>(
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
              );
            }),
            if (!controller.isSummaryTable) ...<Widget>[
              const SizedBox(height: 16),
              Text('Columns', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: controller.columns.length,
                onReorder: controller.reorderColumns,
                itemBuilder: (BuildContext context, int index) {
                  final EditColumnDraft column = controller.columns[index];
                  return Card(
                    key: ValueKey<String>(column.id),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              const Icon(Icons.drag_indicator),
                              const SizedBox(width: 8),
                              Expanded(child: Text('Column ${index + 1}')),
                              IconButton(
                                onPressed: () => controller.removeColumn(index),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                          TextField(
                            controller: column.nameController,
                            decoration: const InputDecoration(
                              labelText: 'Column Name',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Obx(
                            () => SearchableColumnTypeField(
                              selectedType: column.type.value,
                              allowedTypes: TableColumnType.values,
                              label: 'Data type',
                              onChanged: (TableColumnType value) {
                                final TableColumnType previous =
                                    column.type.value;
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
                            if (column.type.value == TableColumnType.formula) {
                              return GuidedFormulaBuilder(
                                key: ValueKey<String>('formula-${column.id}'),
                                host: controller,
                                guided: column.guided,
                                columnId: column.id,
                                theme: Theme.of(context),
                              );
                            }
                            if (column.type.value ==
                                TableColumnType.autoGenerated) {
                              return TextField(
                                controller: column.patternController,
                                decoration: const InputDecoration(
                                  labelText: 'Auto pattern',
                                ),
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
                                  manualLinesController:
                                      column.dropdownOptionsController,
                                  allSchemas: controller.existingTableSchemas,
                                  errorText: err,
                                  excludeTableId: controller.editingTableId,
                                );
                              });
                            }
                            return const SizedBox.shrink();
                          }),
                          Obx(() {
                            if (controller.mode.value != TableMode.crud) {
                              return const SizedBox.shrink();
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                const SizedBox(height: 8),
                                Text(
                                  'Form fields',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                                CheckboxListTile(
                                  value: column.includeInCreate.value,
                                  onChanged:
                                      (bool? value) =>
                                          column.includeInCreate.value =
                                              value ?? false,
                                  title: const Text('Include in create form'),
                                  contentPadding: EdgeInsets.zero,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                ),
                                CheckboxListTile(
                                  value: column.includeInEdit.value,
                                  onChanged:
                                      (bool? value) =>
                                          column.includeInEdit.value =
                                              value ?? false,
                                  title: const Text('Include in edit form'),
                                  contentPadding: EdgeInsets.zero,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                ),
                              ],
                            );
                          }),
                          Obx(
                            () => CheckboxListTile(
                              value: column.isRequired.value,
                              onChanged:
                                  controller.mode.value == TableMode.crud
                                      ? (bool? value) =>
                                          column.isRequired.value =
                                              value ?? false
                                      : null,
                              title: const Text('Required in form'),
                              subtitle:
                                  controller.mode.value == TableMode.readOnly
                                      ? const Text(
                                        'Only applies when CRUD is enabled.',
                                      )
                                      : null,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                          ),
                          Obx(
                            () => CheckboxListTile(
                              value: column.isUnique.value,
                              onChanged:
                                  (bool? value) =>
                                      column.isUnique.value = value ?? false,
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
                },
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: controller.addColumn,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ),
              const SizedBox(height: 16),
              Obx(() {
                final ThemeData th = Theme.of(context);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          'Stock deduction (new rows only)',
                          style: th.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'When enabled, saving a **new** row in this table subtracts the line quantity from a numeric column on another table (first row where the match column equals the line product value). Edits and deletes do not adjust stock.',
                          style: th.textTheme.bodySmall?.copyWith(
                            color: th.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Enable stock deduction'),
                          value: controller.inventoryDeductionEnabled.value,
                          onChanged:
                              (bool v) =>
                                  controller.inventoryDeductionEnabled.value =
                                      v,
                        ),
                        if (controller
                            .inventoryDeductionEnabled
                            .value) ...<Widget>[
                          if (controller.inventoryStockTableOptions.isEmpty)
                            Text(
                              'Save another standard table first (e.g. Products with Stock).',
                              style: th.textTheme.bodySmall?.copyWith(
                                color: th.colorScheme.error,
                              ),
                            )
                          else ...<Widget>[
                            DropdownButtonFormField<String>(
                              value: controller.invStockTableFieldValue,
                              decoration: const InputDecoration(
                                labelText: 'Product / stock table',
                              ),
                              items: controller.inventoryStockTableOptions
                                  .map(
                                    (s) => DropdownMenuItem<String>(
                                      value: s.id,
                                      child: Text(s.name),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (String? id) {
                                if (id == null) {
                                  return;
                                }
                                controller.invStockTableId.value = id;
                                controller.invStockMatchColumnId.value = null;
                                controller.invStockQuantityColumnId.value =
                                    null;
                              },
                            ),
                            const SizedBox(height: 12),
                            if (controller.inventoryStockTableColumns.isEmpty)
                              Text(
                                'Pick a stock table with columns.',
                                style: th.textTheme.bodySmall?.copyWith(
                                  color: th.colorScheme.onSurfaceVariant,
                                ),
                              )
                            else ...<Widget>[
                              DropdownButtonFormField<String>(
                                value: controller.invStockMatchColumnFieldValue,
                                decoration: const InputDecoration(
                                  labelText: 'Match column on stock table',
                                  helperText:
                                      'Must match the line “product” value (e.g. product name)',
                                ),
                                items: controller.inventoryStockTableColumns
                                    .map(
                                      (c) => DropdownMenuItem<String>(
                                        value: c.id,
                                        child: Text(c.name),
                                      ),
                                    )
                                    .toList(growable: false),
                                onChanged:
                                    (String? id) =>
                                        controller.invStockMatchColumnId.value =
                                            id,
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value:
                                    controller.invStockQuantityColumnFieldValue,
                                decoration: const InputDecoration(
                                  labelText:
                                      'Stock quantity column (to subtract)',
                                ),
                                items: controller.inventoryStockNumericColumns
                                    .map(
                                      (c) => DropdownMenuItem<String>(
                                        value: c.id,
                                        child: Text(
                                          '${c.name} (${c.type.storageValue})',
                                        ),
                                      ),
                                    )
                                    .toList(growable: false),
                                onChanged:
                                    (String? id) =>
                                        controller
                                            .invStockQuantityColumnId
                                            .value = id,
                              ),
                            ],
                            const SizedBox(height: 12),
                            Text(
                              'This table (line row)',
                              style: th.textTheme.labelLarge,
                            ),
                            const SizedBox(height: 8),
                            if (controller
                                .inventoryLineProductCandidates
                                .isEmpty)
                              Text(
                                'Add a text or dropdown column for the product key.',
                                style: th.textTheme.bodySmall?.copyWith(
                                  color: th.colorScheme.error,
                                ),
                              )
                            else
                              DropdownButtonFormField<String>(
                                value: controller.invLineProductFieldValue,
                                decoration: const InputDecoration(
                                  labelText: 'Line product column',
                                ),
                                items: controller.inventoryLineProductCandidates
                                    .map(
                                      (c) => DropdownMenuItem<String>(
                                        value: c.id,
                                        child: Text(
                                          c.nameController.text.trim().isEmpty
                                              ? '(unnamed)'
                                              : c.nameController.text.trim(),
                                        ),
                                      ),
                                    )
                                    .toList(growable: false),
                                onChanged:
                                    (String? id) =>
                                        controller
                                            .invLineProductColumnId
                                            .value = id,
                              ),
                            const SizedBox(height: 12),
                            if (controller
                                .inventoryLineQuantityCandidates
                                .isEmpty)
                              Text(
                                'Add a number or currency column for quantity.',
                                style: th.textTheme.bodySmall?.copyWith(
                                  color: th.colorScheme.error,
                                ),
                              )
                            else
                              DropdownButtonFormField<String>(
                                value: controller.invLineQuantityFieldValue,
                                decoration: const InputDecoration(
                                  labelText: 'Line quantity column',
                                ),
                                items: controller
                                    .inventoryLineQuantityCandidates
                                    .map(
                                      (c) => DropdownMenuItem<String>(
                                        value: c.id,
                                        child: Text(
                                          c.nameController.text.trim().isEmpty
                                              ? '(unnamed)'
                                              : c.nameController.text.trim(),
                                        ),
                                      ),
                                    )
                                    .toList(growable: false),
                                onChanged:
                                    (String? id) =>
                                        controller
                                            .invLineQuantityColumnId
                                            .value = id,
                              ),
                          ],
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ] else ...<Widget>[
              const SizedBox(height: 16),
              Text(
                'Summary columns',
                style: Theme.of(context).textTheme.titleMedium,
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
          ],
        );
      }),
    );
  }
}
