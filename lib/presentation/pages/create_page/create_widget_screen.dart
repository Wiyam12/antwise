import 'package:antwise/domain/entities/card_widget_layout.dart';
import 'package:antwise/domain/entities/table_column_entity.dart';
import 'package:antwise/domain/entities/table_column_type.dart';
import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/presentation/controllers/create_widget_controller.dart';
import 'package:antwise/presentation/widgets/searchable_dropdown_field.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CreateWidgetScreen extends GetView<CreateWidgetController> {
  const CreateWidgetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Create Widget')),
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
              if (controller.currentStep.value == 2) {
                await controller.submit();
              } else {
                await controller.goNext();
              }
            },
            onStepCancel: controller.goBack,
            controlsBuilder: (BuildContext context, ControlsDetails details) {
              final int step = controller.currentStep.value;
              final bool isLast = step == 2;
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
                              : Text(isLast ? 'Create Widget' : 'Next'),
                    ),
                  ],
                ),
              );
            },
            steps: <Step>[
              Step(
                title: const Text('Widget type'),
                subtitle: Text(
                  controller.selectedWidgetType.value == BuilderWidgetType.chart
                      ? 'Chart widget'
                      : 'Card widget',
                ),
                isActive: controller.currentStep.value >= 0,
                state:
                    controller.currentStep.value > 0
                        ? StepState.complete
                        : StepState.indexed,
                content: _stepWidgetType(theme),
              ),
              Step(
                title: const Text('Design layout'),
                isActive: controller.currentStep.value >= 1,
                state:
                    controller.currentStep.value > 1
                        ? StepState.complete
                        : StepState.indexed,
                content: _stepLayout(theme),
              ),
              Step(
                title: const Text('Data source'),
                isActive: controller.currentStep.value >= 2,
                state: StepState.indexed,
                content: _stepDataSource(theme),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _stepWidgetType(ThemeData theme) {
    return Obx(() {
      final BuilderWidgetType? selected = controller.selectedWidgetType.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Select the widget type to create.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (controller.widgetTypeError.value.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              controller.widgetTypeError.value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _widgetTypeOption(
            theme: theme,
            selected: selected,
            type: BuilderWidgetType.card,
            title: 'Card Widget',
            subtitle: 'Single metric display with optional formula.',
            icon: Icons.dashboard_customize_outlined,
          ),
          const SizedBox(height: 10),
          _widgetTypeOption(
            theme: theme,
            selected: selected,
            type: BuilderWidgetType.chart,
            title: 'Chart Widget',
            subtitle: 'Bar, line, or pie chart from table data.',
            icon: Icons.insert_chart_outlined,
          ),
        ],
      );
    });
  }

  Widget _widgetTypeOption({
    required ThemeData theme,
    required BuilderWidgetType? selected,
    required BuilderWidgetType type,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final bool isSel = selected == type;
    final ColorScheme cs = theme.colorScheme;
    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => controller.pickWidgetType(type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSel ? cs.primary : cs.outlineVariant,
              width: isSel ? 2 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: cs.primary, size: 28),
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
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSel) Icon(Icons.check_circle, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepLayout(ThemeData theme) {
    return Obx(() {
      if (controller.selectedWidgetType.value == BuilderWidgetType.chart) {
        final ChartWidgetType? selectedChart =
            controller.selectedChartType.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Select chart type.', style: theme.textTheme.bodyMedium),
            if (controller.chartTypeError.value.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                controller.chartTypeError.value,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _chartTypeChip(
                  theme,
                  type: ChartWidgetType.bar,
                  label: 'Bar Chart',
                  selected: selectedChart == ChartWidgetType.bar,
                ),
                _chartTypeChip(
                  theme,
                  type: ChartWidgetType.line,
                  label: 'Line Chart',
                  selected: selectedChart == ChartWidgetType.line,
                ),
                _chartTypeChip(
                  theme,
                  type: ChartWidgetType.pie,
                  label: 'Pie Chart',
                  selected: selectedChart == ChartWidgetType.pie,
                ),
              ],
            ),
          ],
        );
      }
      final CardWidgetLayout? selected = controller.selectedLayout.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Choose how the card looks on the page.',
            style: theme.textTheme.bodyMedium,
          ),
          if (controller.layoutError.value.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              controller.layoutError.value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _layoutOption(
            theme: theme,
            layout: CardWidgetLayout.simple,
            selected: selected,
            title: 'Simple card',
            subtitle: 'Title and prominent value',
            icon: Icons.view_agenda_outlined,
          ),
          const SizedBox(height: 10),
          _layoutOption(
            theme: theme,
            layout: CardWidgetLayout.info,
            selected: selected,
            title: 'Info card',
            subtitle: 'Icon, label, and value in a compact row',
            icon: Icons.info_outline_rounded,
          ),
          const SizedBox(height: 10),
          _layoutOption(
            theme: theme,
            layout: CardWidgetLayout.kpi,
            selected: selected,
            title: 'KPI card',
            subtitle: 'Emphasis on the metric (dashboard style)',
            icon: Icons.trending_up_rounded,
          ),
        ],
      );
    });
  }

  Widget _chartTypeChip(
    ThemeData theme, {
    required ChartWidgetType type,
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
    final bool isSel = selected == layout;
    final ColorScheme cs = theme.colorScheme;
    return Material(
      color: cs.surfaceContainerLow,
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
              color: isSel ? cs.primary : cs.outlineVariant,
              width: isSel ? 2 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: cs.primary, size: 28),
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
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSel) Icon(Icons.check_circle, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepDataSource(ThemeData theme) {
    return Obx(() {
      final bool isChart =
          controller.selectedWidgetType.value == BuilderWidgetType.chart;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            isChart
                ? 'Bind the chart to live table data (X-axis and Y-axis).'
                : 'Bind the card to live table data. Values are computed when the page loads and after data changes.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: controller.selectedPageId.value,
            decoration: InputDecoration(
              labelText: 'Page',
              errorText:
                  controller.pageError.value.isEmpty
                      ? null
                      : controller.pageError.value,
            ),
            items: controller.pageOptions
                .map(
                  (WidgetPageOption p) => DropdownMenuItem<String>(
                    value: p.id,
                    child: Text(p.name),
                  ),
                )
                .toList(growable: false),
            onChanged: (String? id) {
              controller.selectedPageId.value = id;
              controller.pageError.value = '';
            },
          ),
          const SizedBox(height: 12),
          SearchableDropdownField<TableSchemaEntity>(
            options: controller.allTableSchemas.toList(growable: false),
            value: controller.schemaById(controller.selectedTableId.value),
            optionLabel: (TableSchemaEntity s) => s.name,
            label: 'Source table',
            hintText: 'Search tables',
            onChanged: (TableSchemaEntity selected) {
              controller.onTableSelected(selected.id);
            },
          ),
          if (controller.tableError.value.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              controller.tableError.value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Builder(
            builder: (BuildContext context) {
              final cols = _columnsForSelectedTable(controller);
              if (!isChart) {
                return DropdownButtonFormField<String>(
                  value: _safeColumnValue(controller, cols),
                  decoration: InputDecoration(
                    labelText: 'Column',
                    helperText:
                        'Used when no custom formula is set (see below)',
                    errorText:
                        controller.columnError.value.isEmpty
                            ? null
                            : controller.columnError.value,
                  ),
                  items: cols
                      .map(
                        (TableColumnEntity c) => DropdownMenuItem<String>(
                          value: c.id,
                          child: Text('${c.name} (${_colTypeLabel(c.type)})'),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: controller.onColumnSelected,
                );
              }
              return Column(
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    value: _safeXAxisColumnValue(controller, cols),
                    decoration: InputDecoration(
                      labelText: 'X-Axis Column',
                      errorText:
                          controller.xAxisError.value.isEmpty
                              ? null
                              : controller.xAxisError.value,
                    ),
                    items: cols
                        .map(
                          (TableColumnEntity c) => DropdownMenuItem<String>(
                            value: c.id,
                            child: Text('${c.name} (${_colTypeLabel(c.type)})'),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: controller.onXAxisColumnSelected,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _safeYAxisColumnValue(controller, cols),
                    decoration: InputDecoration(
                      labelText: 'Y-Axis Column',
                      helperText: 'Optional when using formula',
                      errorText:
                          controller.yAxisError.value.isEmpty
                              ? null
                              : controller.yAxisError.value,
                    ),
                    items: cols
                        .map(
                          (TableColumnEntity c) => DropdownMenuItem<String>(
                            value: c.id,
                            child: Text('${c.name} (${_colTypeLabel(c.type)})'),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: controller.onYAxisColumnSelected,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.titleController,
            decoration: InputDecoration(
              labelText:
                  isChart ? 'Chart title (optional)' : 'Card title (optional)',
              hintText: isChart ? 'e.g. Sales by Product' : 'e.g. Total Sales',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.formulaController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Formula (optional)',
              hintText:
                  isChart
                      ? 'Use to compute Y values (e.g. IF(amount > 0, amount, 0))'
                      : 'SUM(Sales.amount)  or  IF(Stock.qty < 10, "Low", "OK")',
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
              errorText:
                  controller.formulaError.value.isEmpty
                      ? null
                      : controller.formulaError.value,
            ),
            onChanged: (_) => controller.formulaError.value = '',
          ),
          const SizedBox(height: 8),
          Text(
            isChart
                ? 'Chart uses X-axis and Y-axis columns from the selected table. '
                    'If formula is provided, it computes Y per row.'
                : 'Leave formula empty to use the selected column: numbers default to SUM; text uses the first row. '
                    'Custom formulas use the same functions and Table.Column references as table formulas.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    });
  }

  static List<TableColumnEntity> _columnsForSelectedTable(
    CreateWidgetController c,
  ) {
    final TableSchemaEntity? t = c.schemaById(c.selectedTableId.value);
    return t?.columns ?? const <TableColumnEntity>[];
  }

  static String? _safeColumnValue(
    CreateWidgetController c,
    List<TableColumnEntity> cols,
  ) {
    final String? id = c.selectedColumnId.value;
    if (id == null) {
      return null;
    }
    for (final TableColumnEntity col in cols) {
      if (col.id == id) {
        return id;
      }
    }
    return null;
  }

  static String? _safeXAxisColumnValue(
    CreateWidgetController c,
    List<TableColumnEntity> cols,
  ) {
    final String? id = c.selectedXAxisColumnId.value;
    if (id == null) {
      return null;
    }
    for (final TableColumnEntity col in cols) {
      if (col.id == id) {
        return id;
      }
    }
    return null;
  }

  static String? _safeYAxisColumnValue(
    CreateWidgetController c,
    List<TableColumnEntity> cols,
  ) {
    final String? id = c.selectedYAxisColumnId.value;
    if (id == null) {
      return null;
    }
    for (final TableColumnEntity col in cols) {
      if (col.id == id) {
        return id;
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
    TableColumnType.formula => 'Formula',
    TableColumnType.autoGenerated => 'Auto',
    TableColumnType.image => 'Image',
    TableColumnType.file => 'File',
  };
}
