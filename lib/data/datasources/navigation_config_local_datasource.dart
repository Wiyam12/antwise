import 'package:antwise/core/storage/hive_boxes.dart';
import 'package:antwise/core/storage/hive_service.dart';
import 'package:antwise/data/models/hive/navigation_config_hive_model.dart';

abstract class NavigationConfigLocalDataSource {
  Future<NavigationConfigHiveModel?> read();

  Future<void> write(NavigationConfigHiveModel config);
}

class NavigationConfigLocalDataSourceImpl
    implements NavigationConfigLocalDataSource {
  NavigationConfigLocalDataSourceImpl(this._hiveService);

  final HiveService _hiveService;
  static const String _key = 'navigation_config';

  @override
  Future<NavigationConfigHiveModel?> read() async {
    return _hiveService
        .box<NavigationConfigHiveModel>(HiveBoxes.navigationBox)
        .get(_key);
  }

  @override
  Future<void> write(NavigationConfigHiveModel config) async {
    await _hiveService
        .box<NavigationConfigHiveModel>(HiveBoxes.navigationBox)
        .put(_key, config);
  }
}
