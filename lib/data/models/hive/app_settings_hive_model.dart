import 'package:hive/hive.dart';

class AppSettingsHiveModel {
  AppSettingsHiveModel({
    required this.resourcesDownloaded,
    required this.themeMode,
    required this.firstInstallCompleted,
    required this.themePresetName,
  });

  final bool resourcesDownloaded;
  final String themeMode;
  final bool firstInstallCompleted;
  final String themePresetName;
}

class AppSettingsHiveModelAdapter extends TypeAdapter<AppSettingsHiveModel> {
  @override
  final int typeId = 2;

  @override
  AppSettingsHiveModel read(BinaryReader reader) {
    final int fields = reader.readByte();
    final Map<int, dynamic> data = <int, dynamic>{};
    for (int i = 0; i < fields; i++) {
      data[reader.readByte()] = reader.read();
    }
    return AppSettingsHiveModel(
      resourcesDownloaded: data[0] as bool? ?? false,
      themeMode: data[1] as String? ?? 'system',
      firstInstallCompleted: data[2] as bool? ?? false,
      themePresetName: data[5] as String? ?? 'Ocean Blue',
    );
  }

  @override
  void write(BinaryWriter writer, AppSettingsHiveModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.resourcesDownloaded)
      ..writeByte(1)
      ..write(obj.themeMode)
      ..writeByte(2)
      ..write(obj.firstInstallCompleted)
      ..writeByte(5)
      ..write(obj.themePresetName);
  }
}
