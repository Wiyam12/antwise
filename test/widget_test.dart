import 'dart:io';

import 'package:antwise/core/storage/hive_boxes.dart';
import 'package:antwise/core/storage/hive_service.dart';
import 'package:antwise/data/models/hive/app_settings_hive_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('hive storage initializes required boxes', () async {
    final Directory tmp = await Directory.systemTemp.createTemp(
      'antwise_test_',
    );
    Hive.init(tmp.path);
    final HiveService hiveService = HiveService();
    await hiveService.init();

    expect(Hive.isBoxOpen(HiveBoxes.pagesBox), isTrue);
    expect(Hive.isBoxOpen(HiveBoxes.widgetsBox), isTrue);
    expect(Hive.isBoxOpen(HiveBoxes.tablesBox), isTrue);
    expect(Hive.isBoxOpen(HiveBoxes.rowsBox), isTrue);
    expect(Hive.isBoxOpen(HiveBoxes.navigationBox), isTrue);
    expect(Hive.isBoxOpen(HiveBoxes.settingsBox), isTrue);

    await hiveService
        .box<AppSettingsHiveModel>(HiveBoxes.settingsBox)
        .put(
          'app_settings',
          AppSettingsHiveModel(
            resourcesDownloaded: true,
            themeMode: 'system',
            firstInstallCompleted: false,
            themePresetName: 'Ocean Blue',
            accountNames: const <String>[],
            activeAccountName: '',
          ),
        );

    final AppSettingsHiveModel? stored = hiveService
        .box<AppSettingsHiveModel>(HiveBoxes.settingsBox)
        .get('app_settings');
    expect(stored?.resourcesDownloaded, isTrue);

    await Hive.close();
  });
}
