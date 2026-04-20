import 'package:antwise/domain/entities/counter_entity.dart';

/// DTO / serialization layer for [CounterEntity]. Extend when adding API or DB.
class CounterModel {
  const CounterModel({required this.value});

  final int value;

  CounterEntity toEntity() => CounterEntity(value: value);

  factory CounterModel.fromEntity(CounterEntity entity) =>
      CounterModel(value: entity.value);

  factory CounterModel.fromJson(Map<String, dynamic> json) =>
      CounterModel(value: json['value'] as int);

  Map<String, dynamic> toJson() => <String, dynamic>{'value': value};
}
