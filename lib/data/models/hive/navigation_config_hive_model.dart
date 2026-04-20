import 'package:hive/hive.dart';

class NavigationConfigHiveModel {
  NavigationConfigHiveModel({
    required this.bottomPageIds,
    required this.drawerPageIds,
    required this.activePageId,
    required this.mainPageId,
    this.bottomNavLayout = 'standard',
    this.bottomNavCenterPageId,
    this.bottomNavShowLabels = true,
    this.drawerNavLayout = 'softCard',
  });

  final List<String> bottomPageIds;
  final List<String> drawerPageIds;
  final String? activePageId;
  final String? mainPageId;

  /// [BottomNavLayoutType.storageValue]
  final String bottomNavLayout;
  final String? bottomNavCenterPageId;
  final bool bottomNavShowLabels;
  final String drawerNavLayout;
}

class NavigationConfigHiveModelAdapter
    extends TypeAdapter<NavigationConfigHiveModel> {
  @override
  final int typeId = 6;

  @override
  NavigationConfigHiveModel read(BinaryReader reader) {
    final int fields = reader.readByte();
    final Map<int, dynamic> data = <int, dynamic>{};
    for (int i = 0; i < fields; i++) {
      data[reader.readByte()] = reader.read();
    }
    return NavigationConfigHiveModel(
      bottomPageIds: ((data[0] as List?) ?? <dynamic>[]).cast<String>(),
      drawerPageIds: ((data[1] as List?) ?? <dynamic>[]).cast<String>(),
      activePageId: data[2] as String?,
      mainPageId: data[3] as String?,
      bottomNavLayout: data[4] as String? ?? 'standard',
      bottomNavCenterPageId: data[5] as String?,
      bottomNavShowLabels: data[6] as bool? ?? true,
      drawerNavLayout: data[7] as String? ?? 'softCard',
    );
  }

  @override
  void write(BinaryWriter writer, NavigationConfigHiveModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.bottomPageIds)
      ..writeByte(1)
      ..write(obj.drawerPageIds)
      ..writeByte(2)
      ..write(obj.activePageId)
      ..writeByte(3)
      ..write(obj.mainPageId)
      ..writeByte(4)
      ..write(obj.bottomNavLayout)
      ..writeByte(5)
      ..write(obj.bottomNavCenterPageId)
      ..writeByte(6)
      ..write(obj.bottomNavShowLabels)
      ..writeByte(7)
      ..write(obj.drawerNavLayout);
  }
}
