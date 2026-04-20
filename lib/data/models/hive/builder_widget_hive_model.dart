import 'package:hive/hive.dart';

class BuilderWidgetHiveModel {
  BuilderWidgetHiveModel({
    required this.id,
    required this.pageId,
    required this.type,
    required this.config,
  });

  final String id;
  final String pageId;
  final String type;
  final Map<String, dynamic> config;
}

class BuilderWidgetHiveModelAdapter extends TypeAdapter<BuilderWidgetHiveModel> {
  @override
  final int typeId = 3;

  @override
  BuilderWidgetHiveModel read(BinaryReader reader) {
    final int fields = reader.readByte();
    final Map<int, dynamic> data = <int, dynamic>{};
    for (int i = 0; i < fields; i++) {
      data[reader.readByte()] = reader.read();
    }
    return BuilderWidgetHiveModel(
      id: data[0] as String,
      pageId: data[1] as String,
      type: data[2] as String,
      config: (data[3] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
    );
  }

  @override
  void write(BinaryWriter writer, BuilderWidgetHiveModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.pageId)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.config);
  }
}
