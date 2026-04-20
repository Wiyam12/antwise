import 'package:antwise/data/datasources/navigation_config_local_datasource.dart';
import 'package:antwise/data/models/hive/navigation_config_hive_model.dart';
import 'package:antwise/domain/entities/bottom_nav_layout_type.dart';
import 'package:antwise/domain/entities/drawer_nav_layout_type.dart';
import 'package:antwise/domain/entities/navigation_config_entity.dart';
import 'package:antwise/domain/repositories/navigation_config_repository.dart';

class NavigationConfigRepositoryImpl implements NavigationConfigRepository {
  NavigationConfigRepositoryImpl(this._local);

  final NavigationConfigLocalDataSource _local;

  @override
  Future<NavigationConfigEntity?> getConfig() async {
    final NavigationConfigHiveModel? model = await _local.read();
    if (model == null) {
      return null;
    }
    return NavigationConfigEntity(
      bottomPageIds: model.bottomPageIds,
      drawerPageIds: model.drawerPageIds,
      activePageId: model.activePageId,
      mainPageId: model.mainPageId,
      bottomNavLayout: BottomNavLayoutType.fromStorage(model.bottomNavLayout),
      bottomNavCenterPageId: model.bottomNavCenterPageId,
      bottomNavShowLabels: model.bottomNavShowLabels,
      drawerNavLayout: DrawerNavLayoutType.fromStorage(model.drawerNavLayout),
    );
  }

  @override
  Future<void> saveConfig(NavigationConfigEntity config) async {
    await _local.write(
      NavigationConfigHiveModel(
        bottomPageIds: config.bottomPageIds,
        drawerPageIds: config.drawerPageIds,
        activePageId: config.activePageId,
        mainPageId: config.mainPageId,
        bottomNavLayout: config.bottomNavLayout.storageValue,
        bottomNavCenterPageId: config.bottomNavCenterPageId,
        bottomNavShowLabels: config.bottomNavShowLabels,
        drawerNavLayout: config.drawerNavLayout.storageValue,
      ),
    );
  }
}
