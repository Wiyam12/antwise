import 'package:antwise/domain/entities/navigation_config_entity.dart';
import 'package:antwise/domain/repositories/navigation_config_repository.dart';

class GetNavigationConfigUseCase {
  GetNavigationConfigUseCase(this._repository);

  final NavigationConfigRepository _repository;

  Future<NavigationConfigEntity?> call() => _repository.getConfig();
}
