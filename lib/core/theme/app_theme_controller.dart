import 'package:antwise/core/storage/hive_boxes.dart';
import 'package:antwise/core/storage/hive_service.dart';
import 'package:antwise/core/theme/app_colors.dart' show AppColors, ThemePreset;
import 'package:antwise/data/models/hive/app_settings_hive_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Global theme mode; extend later for custom themes or persistence.
class AppThemeController extends GetxController {
  AppThemeController(this._hiveService);

  final HiveService _hiveService;
  final Rx<ThemeMode> themeMode = ThemeMode.system.obs;
  final RxString selectedPresetName = AppColors.defaultPresetName.obs;

  final Rx<ThemeMode> draftThemeMode = ThemeMode.system.obs;
  final RxString draftPresetName = AppColors.defaultPresetName.obs;

  static const String _settingsKey = 'app_settings';

  @override
  void onInit() {
    super.onInit();
    loadFromStorage();
  }

  Future<void> loadFromStorage() async {
    final box = _hiveService.box<AppSettingsHiveModel>(HiveBoxes.settingsBox);
    final AppSettingsHiveModel? settings = box.get(_settingsKey);
    if (settings == null) {
      resetDraft();
      return;
    }
    final ThemeMode mode = switch (settings.themeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    themeMode.value = mode;
    selectedPresetName.value = settings.themePresetName;
    resetDraft();
  }

  void useSystem() => themeMode.value = ThemeMode.system;

  void useLight() => themeMode.value = ThemeMode.light;

  void useDark() => themeMode.value = ThemeMode.dark;

  void resetDraft() {
    draftThemeMode.value = themeMode.value;
    draftPresetName.value = selectedPresetName.value;
  }

  ThemePreset get selectedPreset => AppColors.presetByName(selectedPresetName.value);
  ThemePreset get draftPreset => AppColors.presetByName(draftPresetName.value);

  void setDraftPreset(String presetName) => draftPresetName.value = presetName;

  void setDraftThemeMode(ThemeMode mode) => draftThemeMode.value = mode;

  Future<void> saveThemeChanges() async {
    themeMode.value = draftThemeMode.value;
    selectedPresetName.value = draftPresetName.value;

    final box = _hiveService.box<AppSettingsHiveModel>(HiveBoxes.settingsBox);
    final AppSettingsHiveModel? old = box.get(_settingsKey);
    await box.put(
      _settingsKey,
      AppSettingsHiveModel(
        resourcesDownloaded: old?.resourcesDownloaded ?? false,
        themeMode: switch (themeMode.value) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          _ => 'system',
        },
        firstInstallCompleted: old?.firstInstallCompleted ?? false,
        themePresetName: selectedPresetName.value,
        accountNames: old?.accountNames ?? const <String>[],
        activeAccountName: old?.activeAccountName ?? '',
        accountWorkspaces: old?.accountWorkspaces ?? <String, dynamic>{},
      ),
    );
  }
}
