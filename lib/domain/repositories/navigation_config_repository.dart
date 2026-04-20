import 'package:antwise/domain/entities/navigation_config_entity.dart';

abstract class NavigationConfigRepository {
  Future<NavigationConfigEntity?> getConfig();

  Future<void> saveConfig(NavigationConfigEntity config);
}
