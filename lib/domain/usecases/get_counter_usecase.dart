import 'package:antwise/domain/entities/counter_entity.dart';
import 'package:antwise/domain/repositories/counter_repository.dart';

class GetCounterUseCase {
  GetCounterUseCase(this._repository);

  final CounterRepository _repository;

  Future<CounterEntity> call() => _repository.getCounter();
}
