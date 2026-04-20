import 'package:antwise/core/constants/storage_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class AppResourcesLocalDataSource {
  Future<bool> readResourcesDownloaded();

  Future<void> writeResourcesDownloaded(bool value);
}

class AppResourcesLocalDataSourceImpl implements AppResourcesLocalDataSource {
  AppResourcesLocalDataSourceImpl(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<bool> readResourcesDownloaded() async =>
      _prefs.getBool(StorageKeys.resourcesDownloaded) ?? false;

  @override
  Future<void> writeResourcesDownloaded(bool value) async {
    await _prefs.setBool(StorageKeys.resourcesDownloaded, value);
  }
}
