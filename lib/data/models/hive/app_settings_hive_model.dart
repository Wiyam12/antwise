import 'package:hive/hive.dart';

class AppSettingsHiveModel {
  AppSettingsHiveModel({
    required this.resourcesDownloaded,
    required this.themeMode,
    required this.firstInstallCompleted,
    required this.themePresetName,
    required this.accountNames,
    required this.activeAccountName,
    required this.accountWorkspaces,
  });

  final bool resourcesDownloaded;
  final String themeMode;
  final bool firstInstallCompleted;
  final String themePresetName;
  final List<String> accountNames;
  final String activeAccountName;
  final Map<String, dynamic> accountWorkspaces;
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
      accountNames:
          (data[6] as List<dynamic>?)
              ?.map((dynamic item) => item.toString())
              .toList(growable: false) ??
          const <String>[],
      activeAccountName: data[7] as String? ?? '',
      accountWorkspaces:
          (data[8] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
    );
  }

  @override
  void write(BinaryWriter writer, AppSettingsHiveModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.resourcesDownloaded)
      ..writeByte(1)
      ..write(obj.themeMode)
      ..writeByte(2)
      ..write(obj.firstInstallCompleted)
      ..writeByte(5)
      ..write(obj.themePresetName)
      ..writeByte(6)
      ..write(obj.accountNames)
      ..writeByte(7)
      ..write(obj.activeAccountName)
      ..writeByte(8)
      ..write(obj.accountWorkspaces);
  }
}
