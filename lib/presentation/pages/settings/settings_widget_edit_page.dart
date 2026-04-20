import 'package:antwise/domain/entities/card_widget_layout.dart';
import 'package:antwise/domain/entities/table_column_entity.dart';
import 'package:antwise/domain/entities/table_column_type.dart';
import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/presentation/controllers/settings_widget_edit_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingsWidgetEditPage extends GetView<SettingsWidgetEditController> {
  const SettingsWidgetEditPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Widget')),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Obx(
        () => SizedBox(
          width: 220,
          child: FilledButton(
            onPressed: controller.isSaving.value ? null : controller.save,
            child: const Text('Save Changes'),
          ),
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        final widget = controller.widget.value;
        if (widget == null) {
          return const Center(child: Text('Widget not found'));
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: <Widget>[
            Text(
              'Page: ${controller.pageDisplayLabel(widget.pageId)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.titleController,
              decoration: InputDecoration(
                labelText:
                    controller.isChartWidget ? 'Chart Name' : 'Card Name',
                hintText:
                    controller.isChartWidget
                        ? 'e.g. Sales Trend'
                        : 'e.g. Total Sales',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (controller.isCardWidget) ...<Widget>[
              Text('Card Design Layout', style: theme.textTheme.titleSmall),
              if (controller.layoutError.value.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  controller.layoutError.value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              _layoutOption(
                theme: theme,
                layout: CardWidgetLayout.simple,
                selected: controller.selectedLayout.value,
                title: 'Simple Card',
                subtitle: 'Title and prominent value',
                icon: Icons.view_agenda_outlined,
              ),
              const SizedBox(height: 10),
              _layoutOption(
                theme: theme,
                layout: CardWidgetLayout.info,
                selected: controller.selectedLayout.value,
                title: 'Info Card',
                subtitle: 'Icon, label, and value row',
                icon: Icons.info_outline_rounded,
              ),
              const SizedBox(height: 10),
              _layoutOption(
                theme: theme,
                layout: CardWidgetLayout.kpi,
                selected: controller.selectedLayout.value,
                title: 'KPI Card',
                subtitle: 'Metric-forward dashboard style',
                icon: Icons.trending_up_rounded,
              ),
            ] else ...<Widget>[
              Text('Chart Type', style: theme.textTheme.titleSmall),
              if (controller.chartTypeError.value.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  controller.chartTypeError.value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  _chartTypeChip(
                    theme,
                    type: SettingsChartWidgetType.bar,
                    label: 'Bar Chart',
                    selected:
                        controller.selectedChartType.value ==
                        SettingsChartWidgetType.bar,
                  ),
                  _chartTypeChip(
                    theme,
                    type: SettingsChartWidgetType.line,
                    label: 'Line Chart',
                    selected:
                        controller.selectedChartType.value ==
                        SettingsChartWidgetType.line,
                  ),
                  _chartTypeChip(
                    theme,
                    type: SettingsChartWidgetType.pie,
                    label: 'Pie Chart',
                    selected:
                        controller.selectedChartType.value ==
                        SettingsChartWidgetType.pie,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Text('Data Source', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _safeTableValue(),
              decoration: InputDecoration(
                labelText: 'Source Table',
                border: const OutlineInputBorder(),
                errorText:
                    controller.tableError.value.isEmpty
                        ? null
                        : controller.tableError.value,
              ),
              items: controller.allSchemas
                  .map((TableSchemaEntity schema) {
                    return DropdownMenuItem<String>(
                      value: schema.id,
                      child: Text(controller.tableDisplayLabel(schema)),
                    );
                  })
                  .toList(growable: false),
              onChanged: controller.onTableChanged,
            ),
            const SizedBox(height: 12),
            if (controller.isCardWidget)
              DropdownButtonFormField<String>(
                value: _safeColumnValue(controller.selectedTableColumns),
                decoration: InputDecoration(
                  labelText: 'Source Column',
                  border: const OutlineInputBorder(),
                  errorText:
                      controller.columnError.value.isEmpty
                          ? null
                          : controller.columnError.value,
                ),
                items: controller.selectedTableColumns
                    .map(
                      (TableColumnEntity c) => DropdownMenuItem<String>(
                        value: c.id,
                        child: Text('${c.name} (${_colTypeLabel(c.type)})'),
                      ),
                    )
                    .toList(growable: false),
                onChanged: controller.onColumnChanged,
              )
            else
              Column(
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    value: _safeXAxisValue(controller.selectedTableColumns),
                    decoration: InputDecoration(
                      labelText: 'X-Axis Column',
                      border: const OutlineInputBorder(),
                      errorText:
                          controller.xAxisError.value.isEmpty
                              ? null
                              : controller.xAxisError.value,
                    ),
                    items: controller.selectedTableColumns
                        .map(
                          (TableColumnEntity c) => DropdownMenuItem<String>(
                            value: c.id,
                            child: Text('${c.name} (${_colTypeLabel(c.type)})'),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: controller.onXAxisColumnChanged,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _safeYAxisValue(controller.selectedTableColumns),
                    decoration: InputDecoration(
                      labelText: 'Y-Axis Column',
                      helperText: 'Optional when formula is provided',
                      border: const OutlineInputBorder(),
                      errorText:
                          controller.yAxisError.value.isEmpty
                              ? null
                              : controller.yAxisError.value,
                    ),
                    items: controller.selectedTableColumns
                        .map(
                          (TableColumnEntity c) => DropdownMenuItem<String>(
                            value: c.id,
                            child: Text('${c.name} (${_colTypeLabel(c.type)})'),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: controller.onYAxisColumnChanged,
                  ),
                ],
              ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.formulaController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText:
                    controller.isChartWidget
                        ? 'Optional Formula (Y value)'
                        : 'Optional Formula',
                hintText:
                    controller.isChartWidget
                        ? 'IF(amount > 0, amount, 0)'
                        : 'SUM(Sales.amount)',
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
                errorText:
                    controller.formulaError.value.isEmpty
                        ? null
                        : controller.formulaError.value,
              ),
              onChanged: (_) => controller.formulaError.value = '',
            ),
          ],
        );
      }),
    );
  }

  Widget _chartTypeChip(
    ThemeData theme, {
    required SettingsChartWidgetType type,
    required String label,
    required bool selected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => controller.pickChartType(type),
      selectedColor: theme.colorScheme.primaryContainer,
    );
  }

  Widget _layoutOption({
    required ThemeData theme,
    required CardWidgetLayout layout,
    required CardWidgetLayout? selected,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final bool isSelected = selected == layout;
    final ColorScheme colors = theme.colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => controller.pickLayout(layout),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? colors.primary : colors.outlineVariant,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: colors.primary, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: theme.textTheme.titleSmall),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected) Icon(Icons.check_circle, color: colors.primary),
            ],
          ),
        ),
      ),
    );
  }

  String? _safeTableValue() {
    final String? selected = controller.selectedTableId.value;
    if (selected == null) {
      return null;
    }
    for (final TableSchemaEntity schema in controller.allSchemas) {
      if (schema.id == selected) {
        return selected;
      }
    }
    return null;
  }

  String? _safeColumnValue(List<TableColumnEntity> columns) {
    final String? selected = controller.selectedColumnId.value;
    if (selected == null) {
      return null;
    }
    for (final TableColumnEntity column in columns) {
      if (column.id == selected) {
        return selected;
      }
    }
    return null;
  }

  String? _safeXAxisValue(List<TableColumnEntity> columns) {
    final String? selected = controller.selectedXAxisColumnId.value;
    if (selected == null) {
      return null;
    }
    for (final TableColumnEntity column in columns) {
      if (column.id == selected) {
        return selected;
      }
    }
    return null;
  }

  String? _safeYAxisValue(List<TableColumnEntity> columns) {
    final String? selected = controller.selectedYAxisColumnId.value;
    if (selected == null) {
      return null;
    }
    for (final TableColumnEntity column in columns) {
      if (column.id == selected) {
        return selected;
      }
    }
    return null;
  }

  static String _colTypeLabel(TableColumnType t) => switch (t) {
    TableColumnType.text => 'Text',
    TableColumnType.number => 'Number',
    TableColumnType.date => 'Date',
    TableColumnType.boolean => 'Bool',
    TableColumnType.dropdown => 'Dropdown',
    TableColumnType.currency => 'Currency',
    TableColumnType.formula => 'Formula',
    TableColumnType.autoGenerated => 'Auto',
    TableColumnType.image => 'Image',
    TableColumnType.file => 'File',
  };
}
