import 'package:antwise/data/datasources/counter_local_datasource.dart';
import 'package:antwise/data/models/counter_model.dart';
import 'package:antwise/domain/entities/counter_entity.dart';
import 'package:antwise/domain/repositories/counter_repository.dart';

class CounterRepositoryImpl implements CounterRepository {
  CounterRepositoryImpl(this._local);

  final CounterLocalDataSource _local;

  @override
  Future<CounterEntity> getCounter() async {
    final raw = await _local.read();
    return CounterModel(value: raw).toEntity();
  }

  @override
  Future<CounterEntity> increment() async {
    final raw = await _local.read();
    final next = raw + 1;
    await _local.write(next);
    return CounterModel(value: next).toEntity();
  }
}
