import 'dart:io';

import 'package:antwise/core/icons/app_icon_registry.dart';
import 'package:antwise/domain/entities/card_widget_layout.dart';
import 'package:antwise/domain/entities/table_column_entity.dart';
import 'package:antwise/domain/entities/table_column_type.dart';
import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/presentation/controllers/create_widget_controller.dart';
import 'package:antwise/presentation/widgets/column_field_icon_picker.dart';
import 'package:antwise/presentation/widgets/formula_text_editor_field.dart';
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
                content: _stepLayout(context, theme),
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

  Widget _stepLayout(BuildContext context, ThemeData theme) {
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
            layout: CardWidgetLayout.hero,
            selected: selected,
            title: 'Hero balance card',
            subtitle: 'Gradient card like the attached design',
            icon: Icons.style_outlined,
          ),
          const SizedBox(height: 10),
          _layoutOption(
            theme: theme,
            layout: CardWidgetLayout.percent,
            selected: selected,
            title: 'Percent progress card',
            subtitle: 'Upload/progress style card layout',
            icon: Icons.percent_rounded,
          ),
          if (selected == CardWidgetLayout.hero) ...<Widget>[
            const SizedBox(height: 12),
            _heroCardCustomization(context, theme),
          ],
          if (selected == CardWidgetLayout.percent) ...<Widget>[
            const SizedBox(height: 12),
            _percentCardCustomization(context, theme),
          ],
        ],
      );
    });
  }

  Widget _percentCardCustomization(BuildContext context, ThemeData theme) {
    return Obx(() {
      final String imagePath =
          controller.percentBackgroundImagePath.value ?? '';
      final bool hasImage = imagePath.isNotEmpty;
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Percent card setup', style: theme.textTheme.titleSmall),
            const SizedBox(height: 10),
            TextField(
              controller: controller.percentCardNameController,
              decoration: const InputDecoration(
                labelText: 'Card name',
                hintText: 'e.g. Uploading',
                border: OutlineInputBorder(),
              ),
              onChanged: (String value) {
                controller.percentLayoutError.value = '';
                controller.setPercentCardName(value);
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller.percentLabelController,
              decoration: const InputDecoration(
                labelText: 'Label',
                hintText: 'e.g. invoice.docx',
                border: OutlineInputBorder(),
              ),
              onChanged: (String value) {
                controller.percentLayoutError.value = '';
                controller.setPercentLabel(value);
              },
            ),
            const SizedBox(height: 10),
            Text('Background color', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _percentColorOptions
                  .map((_PercentColorOption option) {
                    final bool selected =
                        controller.percentBackgroundHex.value == option.hex;
                    return ChoiceChip(
                      label: Text(option.label),
                      avatar: CircleAvatar(
                        backgroundColor: _hexToColor(option.hex),
                      ),
                      selected: selected,
                      onSelected:
                          (_) => controller.setPercentBackgroundHex(option.hex),
                    );
                  })
                  .toList(growable: false),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final String? picked = await showColumnFieldIconPicker(
                        context,
                        currentKey: controller.percentIconKey.value,
                      );
                      controller.setPercentIconKey(picked);
                    },
                    icon: Icon(
                      controller.percentIconKey.value == null
                          ? Icons.add_photo_alternate_outlined
                          : AppIconRegistry.iconOf(
                            controller.percentIconKey.value,
                          ),
                    ),
                    label: Text(
                      controller.percentIconKey.value == null
                          ? 'Choose icon'
                          : controller.percentIconKey.value!,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (controller.percentIconKey.value != null) ...<Widget>[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => controller.setPercentIconKey(null),
                    child: const Text('Clear'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: controller.pickPercentBackgroundImage,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(hasImage ? 'Replace image' : 'Pick image'),
                ),
                const SizedBox(width: 8),
                if (hasImage)
                  TextButton(
                    onPressed: controller.clearPercentBackgroundImage,
                    child: const Text('Remove'),
                  ),
              ],
            ),
            if (hasImage) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                imagePath,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            _percentCardPreview(theme),
            if (controller.percentLayoutError.value.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                controller.percentLayoutError.value,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _percentCardPreview(ThemeData theme) {
    final String hex = controller.percentBackgroundHex.value.trim();
    final Color background = _hexToColor(hex) ?? const Color(0xFF2F80ED);
    final String title = controller.percentCardNameValue.value.trim();
    final String label = controller.percentLabelValue.value.trim();
    final String formula =
        controller.percentCombinedFormulaPreview.value.trim();
    final String? iconKey = controller.percentIconKey.value;
    final double percent = controller.previewPercentFromFormula(formula);
    final String? imagePath = controller.percentBackgroundImagePath.value;
    final File? backgroundFile =
        imagePath != null &&
                imagePath.isNotEmpty &&
                File(imagePath).existsSync()
            ? File(imagePath)
            : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              background,
              Color.lerp(background, Colors.black, 0.18) ?? background,
            ],
          ),
          image:
              backgroundFile != null
                  ? DecorationImage(
                    image: FileImage(backgroundFile),
                    fit: BoxFit.cover,
                    opacity: 0.3,
                  )
                  : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _fileTilePill(iconKey: iconKey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title.isEmpty ? 'Uploading' : title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              LinearProgressIndicator(
                minHeight: 5,
                value: percent / 100,
                backgroundColor: Colors.white.withValues(alpha: 0.22),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Text(
                    '${percent.toStringAsFixed(0)}%',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    label.isEmpty ? 'invoice.docx' : label,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fileTilePill({String? iconKey}) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Stack(
        children: <Widget>[
          Center(
            child: Icon(
              iconKey == null
                  ? Icons.description_outlined
                  : AppIconRegistry.iconOf(iconKey),
              color: Colors.white,
              size: 18,
            ),
          ),
          Positioned(
            right: 5,
            bottom: 4,
            child: Text(
              '2',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroCardCustomization(BuildContext context, ThemeData theme) {
    return Obx(() {
      final String imagePath = controller.heroBackgroundImagePath.value ?? '';
      final bool hasImage = imagePath.isNotEmpty;
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Hero card setup', style: theme.textTheme.titleSmall),
            const SizedBox(height: 10),
            TextField(
              controller: controller.heroCardNameController,
              decoration: const InputDecoration(
                labelText: 'Card name',
                hintText: 'e.g. Hey, Sandro',
                border: OutlineInputBorder(),
              ),
              onChanged: (String value) {
                controller.heroLayoutError.value = '';
                controller.setHeroCardName(value);
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller.heroLabelController,
              decoration: const InputDecoration(
                labelText: 'Label',
                hintText: 'e.g. Balance',
                border: OutlineInputBorder(),
              ),
              onChanged: (String value) {
                controller.heroLayoutError.value = '';
                controller.setHeroLabel(value);
              },
            ),
            const SizedBox(height: 10),
            Text('Background color', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _heroColorOptions
                  .map((_HeroColorOption option) {
                    final bool selected =
                        controller.heroBackgroundHex.value == option.hex;
                    return ChoiceChip(
                      label: Text(option.label),
                      avatar: CircleAvatar(
                        backgroundColor: _hexToColor(option.hex),
                      ),
                      selected: selected,
                      onSelected:
                          (_) => controller.setHeroBackgroundHex(option.hex),
                    );
                  })
                  .toList(growable: false),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: controller.heroPrefixType.value,
              decoration: const InputDecoration(
                labelText: 'Value prefix',
                border: OutlineInputBorder(),
              ),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(value: 'none', child: Text('None')),
                DropdownMenuItem<String>(value: 'text', child: Text('Text')),
                DropdownMenuItem<String>(value: 'icon', child: Text('Icon')),
              ],
              onChanged: (String? value) {
                controller.setHeroPrefixType(value ?? 'none');
              },
            ),
            if (controller.heroPrefixType.value == 'text') ...<Widget>[
              const SizedBox(height: 10),
              TextField(
                controller: controller.heroPrefixTextController,
                decoration: const InputDecoration(
                  labelText: 'Prefix text',
                  hintText: '\$',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            if (controller.heroPrefixType.value == 'icon') ...<Widget>[
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final String? picked = await showColumnFieldIconPicker(
                          context,
                          currentKey: controller.heroPrefixIconKey.value,
                        );
                        controller.setHeroPrefixIconKey(picked);
                      },
                      icon: Icon(
                        controller.heroPrefixIconKey.value == null
                            ? Icons.add_reaction_outlined
                            : AppIconRegistry.iconOf(
                              controller.heroPrefixIconKey.value,
                            ),
                      ),
                      label: Text(
                        controller.heroPrefixIconKey.value == null
                            ? 'Choose prefix icon'
                            : controller.heroPrefixIconKey.value!,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (controller.heroPrefixIconKey.value != null) ...<Widget>[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => controller.setHeroPrefixIconKey(null),
                      child: const Text('Clear'),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: controller.pickHeroBackgroundImage,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(hasImage ? 'Replace image' : 'Pick image'),
                ),
                const SizedBox(width: 8),
                if (hasImage)
                  TextButton(
                    onPressed: controller.clearHeroBackgroundImage,
                    child: const Text('Remove'),
                  ),
              ],
            ),
            if (hasImage) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                imagePath,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            _heroCardPreview(theme),
            if (controller.heroLayoutError.value.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                controller.heroLayoutError.value,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _heroCardPreview(ThemeData theme) {
    final String hex = controller.heroBackgroundHex.value.trim();
    final Color background = _hexToColor(hex) ?? theme.colorScheme.primary;
    final String cardName = controller.heroCardNameValue.value.trim();
    final String label = controller.heroLabelValue.value.trim();
    final String? imagePath = controller.heroBackgroundImagePath.value;
    final String prefixType = controller.heroPrefixType.value;
    final String prefixText = controller.heroPrefixTextController.text.trim();
    final String? prefixIconKey = controller.heroPrefixIconKey.value;
    final File? backgroundFile =
        imagePath != null &&
                imagePath.isNotEmpty &&
                File(imagePath).existsSync()
            ? File(imagePath)
            : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              background,
              Color.lerp(background, Colors.black, 0.28) ?? background,
            ],
          ),
          image:
              backgroundFile != null
                  ? DecorationImage(
                    image: FileImage(backgroundFile),
                    fit: BoxFit.cover,
                    opacity: 0.42,
                  )
                  : null,
        ),
        child: Stack(
          children: <Widget>[
            ..._heroBubbles(),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    cardName.isEmpty ? 'Hey, Sandro' : cardName,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    label.isEmpty ? 'Balance' : label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  Row(
                    children: <Widget>[
                      if (prefixType == 'text' && prefixText.isNotEmpty)
                        Text(
                          prefixText,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (prefixType == 'icon' &&
                          prefixIconKey != null) ...<Widget>[
                        Icon(
                          AppIconRegistry.iconOf(prefixIconKey),
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          '23,540.00',
                          style: theme.textTheme.displaySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _heroBubbles() {
    return <Widget>[
      Positioned(
        right: -20,
        top: 30,
        child: _bubble(90, Colors.pinkAccent.withValues(alpha: 0.9)),
      ),
      Positioned(
        left: 140,
        top: 8,
        child: _bubble(110, Colors.white.withValues(alpha: 0.16)),
      ),
      Positioned(
        left: 65,
        top: 28,
        child: _bubble(140, Colors.black.withValues(alpha: 0.12)),
      ),
      Positioned(
        left: 24,
        bottom: -50,
        child: _bubble(180, Colors.white.withValues(alpha: 0.1)),
      ),
    ];
  }

  Widget _bubble(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Color? _hexToColor(String raw) {
    var value = raw.trim().replaceAll('#', '');
    if (value.length == 6) {
      value = 'FF$value';
    }
    if (value.length != 8) {
      return null;
    }
    final int? parsed = int.tryParse(value, radix: 16);
    if (parsed == null) {
      return null;
    }
    return Color(parsed);
  }

  static const List<_HeroColorOption> _heroColorOptions = <_HeroColorOption>[
    _HeroColorOption(label: 'Indigo', hex: '#4F46E5'),
    _HeroColorOption(label: 'Sky', hex: '#0EA5E9'),
    _HeroColorOption(label: 'Violet', hex: '#7C3AED'),
    _HeroColorOption(label: 'Pink', hex: '#EC4899'),
    _HeroColorOption(label: 'Slate', hex: '#1F2937'),
  ];

  static const List<_PercentColorOption> _percentColorOptions =
      <_PercentColorOption>[
        _PercentColorOption(label: 'Blue', hex: '#2F80ED'),
        _PercentColorOption(label: 'Indigo', hex: '#4F46E5'),
        _PercentColorOption(label: 'Teal', hex: '#14B8A6'),
        _PercentColorOption(label: 'Violet', hex: '#7C3AED'),
        _PercentColorOption(label: 'Slate', hex: '#334155'),
      ];

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
      final bool isPercentCard =
          !isChart &&
          controller.selectedLayout.value == CardWidgetLayout.percent;
      final bool isHeroCard =
          !isChart && controller.selectedLayout.value == CardWidgetLayout.hero;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            isChart
                ? 'Bind the chart to live table data (X-axis and Y-axis).'
                : 'Bind the card to live table data. Values are computed when the page loads and after data changes.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.titleController,
            decoration: InputDecoration(
              labelText: isChart ? 'Chart name' : 'Card title (optional)',
              hintText: isChart ? 'e.g. Sales by Product' : 'e.g. Total Sales',
              errorText:
                  isChart && controller.chartNameError.value.isNotEmpty
                      ? controller.chartNameError.value
                      : null,
              border: OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (isChart) {
                controller.chartNameError.value = '';
              }
            },
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
          if (!isPercentCard && !isHeroCard) ...<Widget>[
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
                              child: Text(
                                '${c.name} (${_colTypeLabel(c.type)})',
                              ),
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
                              child: Text(
                                '${c.name} (${_colTypeLabel(c.type)})',
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: controller.onYAxisColumnSelected,
                    ),
                    if (controller.selectedChartType.value ==
                            ChartWidgetType.line &&
                        controller.isDateXAxisSelectedForChart) ...<Widget>[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Date Filter Options',
                          style: theme.textTheme.labelLarge,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...ChartDateGroupingFilter.values.map((
                        ChartDateGroupingFilter filter,
                      ) {
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: controller.selectedDateGroupingFilters
                              .contains(filter),
                          title: Text(_dateFilterLabel(filter.name)),
                          onChanged: (bool? checked) {
                            controller.toggleDateGroupingFilter(
                              filter,
                              checked ?? false,
                            );
                            controller.xAxisError.value = '';
                          },
                        );
                      }),
                      if (controller.xAxisError.value.isNotEmpty &&
                          controller.selectedDateGroupingFilters.isEmpty)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            controller.xAxisError.value,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ],
                );
              },
            ),
          ],
          if (isPercentCard) ...<Widget>[
            const SizedBox(height: 12),
            FormulaTextEditorField(
              controller: controller.percentNumeratorFormulaController,
              schemas: controller.allTableSchemas.toList(growable: false),
              currentColumnNames: const <String>[],
              onChanged: () {
                controller.percentLayoutError.value = '';
                controller.setPercentNumeratorFormula(
                  controller.percentNumeratorFormulaController.text,
                );
              },
              errorText: null,
            ),
            const SizedBox(height: 8),
            Text(
              'Combined formula preview: '
              '${controller.percentCombinedFormulaPreview.value.isEmpty ? '(set numerator and denominator)' : controller.percentCombinedFormulaPreview.value}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Percentage preview: ${controller.previewPercentFromFormula(controller.percentCombinedFormulaPreview.value).toStringAsFixed(0)}%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _percentCardPreview(theme),
          ] else ...<Widget>[
            const SizedBox(height: 12),
            FormulaTextEditorField(
              controller: controller.formulaController,
              schemas: controller.allTableSchemas.toList(growable: false),
              currentColumnNames: const <String>[],
              onChanged: () => controller.formulaError.value = '',
              errorText:
                  controller.formulaError.value.isEmpty
                      ? null
                      : controller.formulaError.value,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            isChart
                ? 'Chart uses X-axis and Y-axis columns from the selected table. '
                    'If formula is provided, it computes Y per row.'
                : isPercentCard
                ? 'Set one percent formula here. '
                    'Example: SUM(Completed) / SUM(Total) * 100.'
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

  static String _dateFilterLabel(String token) {
    return switch (token) {
      'daily' => 'Daily',
      'weekly' => 'Weekly',
      'monthly' => 'Monthly',
      'yearly' => 'Yearly',
      _ => token,
    };
  }
}

class _HeroColorOption {
  const _HeroColorOption({required this.label, required this.hex});

  final String label;
  final String hex;
}

class _PercentColorOption {
  const _PercentColorOption({required this.label, required this.hex});

  final String label;
  final String hex;
}
