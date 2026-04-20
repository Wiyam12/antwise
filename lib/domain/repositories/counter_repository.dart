import 'package:antwise/domain/entities/counter_entity.dart';

/// Contract for counter persistence. Implementations live in [data/repositories].
abstract class CounterRepository {
  Future<CounterEntity> getCounter();

  Future<CounterEntity> increment();
}
