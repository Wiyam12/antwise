import 'package:antwise/domain/entities/navigation_config_entity.dart';
import 'package:antwise/domain/repositories/navigation_config_repository.dart';

class SaveNavigationConfigUseCase {
  SaveNavigationConfigUseCase(this._repository);

  final NavigationConfigRepository _repository;

  Future<void> call(NavigationConfigEntity config) =>
      _repository.saveConfig(config);
}
