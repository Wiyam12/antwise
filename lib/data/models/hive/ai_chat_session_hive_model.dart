import 'package:antwise/data/models/hive/ai_chat_message_hive_model.dart';
import 'package:hive/hive.dart';

/// Persisted conversation for one (account_id, workspace_id) pair.
class AiChatSessionHiveModel {
  AiChatSessionHiveModel({required this.messages});

  final List<AiChatMessageHiveModel> messages;
}

class AiChatSessionHiveModelAdapter extends TypeAdapter<AiChatSessionHiveModel> {
  @override
  final int typeId = 8;

  static final AiChatMessageHiveModelAdapter _messageAdapter =
      AiChatMessageHiveModelAdapter();

  @override
  AiChatSessionHiveModel read(BinaryReader reader) {
    final int length = reader.readInt();
    final List<AiChatMessageHiveModel> messages =
        <AiChatMessageHiveModel>[];
    for (int i = 0; i < length; i++) {
      messages.add(_messageAdapter.read(reader));
    }
    return AiChatSessionHiveModel(messages: messages);
  }

  @override
  void write(BinaryWriter writer, AiChatSessionHiveModel obj) {
    writer.writeInt(obj.messages.length);
    for (final AiChatMessageHiveModel message in obj.messages) {
      _messageAdapter.write(writer, message);
    }
  }
}
