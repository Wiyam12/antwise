import 'package:hive/hive.dart';

class TableRowHiveModel {
  TableRowHiveModel({
    required this.id,
    required this.tableId,
    required this.values,
  });

  final String id;
  final String tableId;
  final Map<String, dynamic> values;
}

class TableRowHiveModelAdapter extends TypeAdapter<TableRowHiveModel> {
  @override
  final int typeId = 5;

  @override
  TableRowHiveModel read(BinaryReader reader) {
    final int fields = reader.readByte();
    final Map<int, dynamic> data = <int, dynamic>{};
    for (int i = 0; i < fields; i++) {
      data[reader.readByte()] = reader.read();
    }
    return TableRowHiveModel(
      id: data[0] as String,
      tableId: data[1] as String,
      values: (data[2] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
    );
  }

  @override
  void write(BinaryWriter writer, TableRowHiveModel obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.tableId)
      ..writeByte(2)
      ..write(obj.values);
  }
}
