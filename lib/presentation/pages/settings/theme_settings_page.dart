import 'package:antwise/core/app_snackbar.dart';
import 'package:antwise/core/theme/app_colors.dart';
import 'package:antwise/core/theme/app_theme.dart';
import 'package:antwise/core/theme/app_theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ThemeSettingsPage extends GetView<AppThemeController> {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Theme Settings')),
      body: Obx(() {
        final ThemePreset preset = controller.draftPreset;
        final ThemeMode mode = controller.draftThemeMode.value;
        final ThemeData previewTheme = _previewThemeForMode(
          context,
          mode,
          preset,
        );

        return Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  Text(
                    'Theme Presets',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _presetGrid(),
                  const SizedBox(height: 20),
                  Text(
                    'Theme Mode',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text('Light Mode'),
                    value: ThemeMode.light,
                    groupValue: mode,
                    onChanged: (ThemeMode? value) {
                      if (value != null) {
                        controller.setDraftThemeMode(value);
                      }
                    },
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text('Dark Mode'),
                    value: ThemeMode.dark,
                    groupValue: mode,
                    onChanged: (ThemeMode? value) {
                      if (value != null) {
                        controller.setDraftThemeMode(value);
                      }
                    },
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text('System Default'),
                    value: ThemeMode.system,
                    groupValue: mode,
                    onChanged: (ThemeMode? value) {
                      if (value != null) {
                        controller.setDraftThemeMode(value);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  _previewCard(previewTheme, preset),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    await controller.saveThemeChanges();
                    if (Get.isSnackbarOpen) {
                      Get.closeCurrentSnackbar();
                    }
                    showAppSnackbar('Theme', 'Theme settings saved');
                  },
                  style:
                      preset.name.toLowerCase() == 'ocean blue'
                          ? FilledButton.styleFrom(
                            foregroundColor: Colors.white,
                          )
                          : null,
                  child: const Text('Save Theme Changes'),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _presetGrid() {
    return Obx(() {
      final String selectedName = controller.draftPresetName.value;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: AppColors.presets.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.6,
        ),
        itemBuilder: (BuildContext context, int index) {
          final ThemePreset preset = AppColors.presets[index];
          final bool isSelected = preset.name == selectedName;
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => controller.setDraftPreset(preset.name),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade300,
                  width: isSelected ? 2.4 : 1.2,
                ),
                color: Theme.of(context).cardColor,
                boxShadow:
                    isSelected
                        ? <BoxShadow>[
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                        : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      _swatch(preset.primary),
                      const SizedBox(width: 6),
                      _swatch(preset.secondary),
                      if (preset.accent != null) ...<Widget>[
                        const SizedBox(width: 6),
                        _swatch(preset.accent!),
                      ],
                    ],
                  ),
                  const Spacer(),
                  Text(
                    preset.name,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  Widget _swatch(Color color) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  Widget _previewCard(ThemeData previewTheme, ThemePreset preset) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: previewTheme,
        child: Builder(
          builder: (BuildContext context) {
            final ThemeData t = Theme.of(context);
            // Scaffold cannot layout inside a scrollable (unbounded height). Use
            // Material + Column so the preview has the same surface/background
            // as a real screen without infinite height expansion.
            return Material(
              color: t.scaffoldBackgroundColor,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AppBar(
                    title: const Text('Preview AppBar'),
                    automaticallyImplyLeading: false,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        FilledButton(
                          onPressed: () {},
                          style:
                              preset.name.toLowerCase() == 'ocean blue'
                                  ? FilledButton.styleFrom(
                                    foregroundColor: Colors.white,
                                  )
                                  : null,
                          child: const Text('Preview Button'),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          child: ListTile(
                            title: const Text('Preview Card'),
                            subtitle: Text(preset.name),
                            trailing: Container(
                              width: 12,
                              height: 28,
                              decoration: BoxDecoration(
                                color: preset.accent ?? preset.secondary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Resolves which light/dark [ThemeData] to show in the preview, including
/// [ThemeMode.system] via platform brightness.
ThemeData _previewThemeForMode(
  BuildContext context,
  ThemeMode mode,
  ThemePreset preset,
) {
  final bool useDark = switch (mode) {
    ThemeMode.dark => true,
    ThemeMode.light => false,
    ThemeMode.system =>
      MediaQuery.platformBrightnessOf(context) == Brightness.dark,
  };
  return useDark
      ? AppTheme.dark(
        primary: preset.primary,
        secondary: preset.secondary,
        onPrimary: preset.onPrimary,
      )
      : AppTheme.light(
        primary: preset.primary,
        secondary: preset.secondary,
        onPrimary: preset.onPrimary,
      );
}
