import 'package:antwise/domain/entities/card_widget_layout.dart';
import 'package:antwise/presentation/controllers/settings_widget_edit_controller.dart';
import 'package:antwise/presentation/widgets/formula_text_editor_field.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingsWidgetEditPage extends GetView<SettingsWidgetEditController> {
  const SettingsWidgetEditPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Widget')),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        final widget = controller.widget.value;
        if (widget == null) {
          return const Center(child: Text('Widget not found'));
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
          child: Stepper(
            physics: const NeverScrollableScrollPhysics(),
            type: StepperType.vertical,
            currentStep: controller.currentStep.value,
            onStepContinue: () async {
              if (controller.currentStep.value == 2) {
                await controller.save();
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
                              ? controller.save
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
                              : Text(isLast ? 'Save Changes' : 'Next'),
                    ),
                  ],
                ),
              );
            },
            steps: <Step>[
              Step(
                title: const Text('Basic widget info'),
                isActive: controller.currentStep.value >= 0,
                state:
                    controller.currentStep.value > 0
                        ? StepState.complete
                        : StepState.indexed,
                content: _stepBasicInfo(theme),
              ),
              Step(
                title: const Text('Configuration'),
                isActive: controller.currentStep.value >= 1,
                state:
                    controller.currentStep.value > 1
                        ? StepState.complete
                        : StepState.indexed,
                content: _stepConfiguration(theme),
              ),
              Step(
                title: const Text('Data source / logic'),
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

  Widget _stepBasicInfo(ThemeData theme) {
    final bool isChart = controller.isChartWidget;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Widget type is locked in edit mode.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Widget type',
            border: OutlineInputBorder(),
          ),
          child: Text(
            isChart ? 'Chart widget (locked)' : 'Card widget (locked)',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller.titleController,
          decoration: InputDecoration(
            labelText:
                isChart ? 'Chart title (optional)' : 'Card title (optional)',
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _stepConfiguration(ThemeData theme) {
    if (controller.isCardWidget) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Layout is locked to preserve existing widget structure.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          _layoutOption(
            theme: theme,
            layout: CardWidgetLayout.hero,
            selected: controller.selectedLayout.value,
            title: 'Hero balance card',
            subtitle: 'Gradient card style',
            icon: Icons.style_outlined,
            enabled: false,
          ),
          const SizedBox(height: 10),
          _layoutOption(
            theme: theme,
            layout: CardWidgetLayout.percent,
            selected: controller.selectedLayout.value,
            title: 'Percent progress card',
            subtitle: 'Upload/progress style card',
            icon: Icons.percent_rounded,
            enabled: false,
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Chart type is locked to preserve existing widget structure.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
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
              enabled: false,
            ),
            _chartTypeChip(
              theme,
              type: SettingsChartWidgetType.line,
              label: 'Line Chart',
              selected:
                  controller.selectedChartType.value ==
                  SettingsChartWidgetType.line,
              enabled: false,
            ),
            _chartTypeChip(
              theme,
              type: SettingsChartWidgetType.pie,
              label: 'Pie Chart',
              selected:
                  controller.selectedChartType.value ==
                  SettingsChartWidgetType.pie,
              enabled: false,
            ),
          ],
        ),
      ],
    );
  }

  Widget _stepDataSource(ThemeData theme) {
    final bool isChart = controller.isChartWidget;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DropdownButtonFormField<String>(
          value: controller.selectedPageId.value,
          decoration: InputDecoration(
            labelText: 'Page',
            errorText:
                controller.pageError.value.isEmpty
                    ? null
                    : controller.pageError.value,
          ),
          items: controller.pages
              .map(
                (page) => DropdownMenuItem<String>(
                  value: page.id,
                  child: Text(page.name),
                ),
              )
              .toList(growable: false),
          onChanged: controller.onPageChanged,
        ),
        const SizedBox(height: 12),
        const SizedBox(height: 12),
        FormulaTextEditorField(
          controller: controller.formulaController,
          schemas: controller.allSchemas.toList(growable: false),
          currentColumnNames: const <String>[],
          onChanged: () => controller.formulaError.value = '',
          errorText:
              controller.formulaError.value.isEmpty
                  ? null
                  : controller.formulaError.value,
        ),
        const SizedBox(height: 8),
        Text(
          isChart
              ? 'Formula is optional and can compute Y values.'
              : 'Formula is optional and can override default card value computation.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _chartTypeChip(
    ThemeData theme, {
    required SettingsChartWidgetType type,
    required String label,
    required bool selected,
    bool enabled = true,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: enabled ? (_) => controller.pickChartType(type) : null,
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
    bool enabled = true,
  }) {
    final bool isSelected = selected == layout;
    final ColorScheme colors = theme.colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? () => controller.pickLayout(layout) : null,
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
}
