import 'package:hive/hive.dart';

/// Single AI chat turn stored in Hive (scoped by account + workspace).
class AiChatMessageHiveModel {
  AiChatMessageHiveModel({
    required this.id,
    required this.role,
    required this.content,
    required this.timestampMillis,
    this.metadataJson = '',
  });

  final String id;
  final String role;
  final String content;
  final int timestampMillis;

  /// Optional JSON-encoded map for extras (tokens, sources, etc.).
  final String metadataJson;

  DateTime get timestamp =>
      DateTime.fromMillisecondsSinceEpoch(timestampMillis, isUtc: true);
}

class AiChatMessageHiveModelAdapter extends TypeAdapter<AiChatMessageHiveModel> {
  @override
  final int typeId = 7;

  @override
  AiChatMessageHiveModel read(BinaryReader reader) {
    final int fields = reader.readByte();
    final Map<int, dynamic> data = <int, dynamic>{};
    for (int i = 0; i < fields; i++) {
      data[reader.readByte()] = reader.read();
    }
    return AiChatMessageHiveModel(
      id: data[0] as String? ?? '',
      role: data[1] as String? ?? 'user',
      content: data[2] as String? ?? '',
      timestampMillis: data[3] as int? ?? DateTime.now().millisecondsSinceEpoch,
      metadataJson: data[4] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, AiChatMessageHiveModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.role)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.timestampMillis)
      ..writeByte(4)
      ..write(obj.metadataJson);
  }
}
