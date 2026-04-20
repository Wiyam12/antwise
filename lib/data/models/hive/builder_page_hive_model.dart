import 'package:antwise/domain/entities/builder_page_entity.dart';
import 'package:hive/hive.dart';

class BuilderPageHiveModel {
  BuilderPageHiveModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.navigationType,
    required this.isDeleted,
    this.parentPageId,
    this.widgetGridCount = 1,
    this.layoutOrder = const <String>[],
    this.widgetOrder = const <String>[],
  });

  final String id;

  final String name;

  final String icon;

  /// bottom | drawer | both
  final String navigationType;
  final bool isDeleted;
  final String? parentPageId;
  final int widgetGridCount;
  final List<String> layoutOrder;
  final List<String> widgetOrder;

  bool get showInBottomNav =>
      navigationType == 'bottom' || navigationType == 'both';
  bool get showInDrawer =>
      navigationType == 'drawer' || navigationType == 'both';

  BuilderPageEntity toEntity() => BuilderPageEntity(
    id: id,
    name: name,
    showInBottomNav: showInBottomNav,
    showInDrawer: showInDrawer,
    isDeleted: isDeleted,
    iconName: icon,
    parentPageId: parentPageId,
    widgetGridCount: widgetGridCount,
    layoutOrder: layoutOrder,
    widgetOrder: widgetOrder,
  );

  factory BuilderPageHiveModel.fromEntity(BuilderPageEntity entity) =>
      BuilderPageHiveModel(
        id: entity.id,
        name: entity.name,
        icon: entity.iconName,
        navigationType:
            entity.showInBottomNav && entity.showInDrawer
                ? 'both'
                : entity.showInBottomNav
                ? 'bottom'
                : 'drawer',
        isDeleted: entity.isDeleted,
        parentPageId: entity.parentPageId,
        widgetGridCount: entity.widgetGridCount,
        layoutOrder: entity.layoutOrder,
        widgetOrder: entity.widgetOrder,
      );
}

class BuilderPageHiveModelAdapter extends TypeAdapter<BuilderPageHiveModel> {
  @override
  final int typeId = 1;

  @override
  BuilderPageHiveModel read(BinaryReader reader) {
    final int fields = reader.readByte();
    final Map<int, dynamic> data = <int, dynamic>{};
    for (int i = 0; i < fields; i++) {
      data[reader.readByte()] = reader.read();
    }
    return BuilderPageHiveModel(
      id: data[0] as String,
      name: data[1] as String,
      icon: data[2] as String,
      navigationType: data[3] as String,
      isDeleted: data[4] as bool? ?? false,
      parentPageId: data[5] as String?,
      widgetGridCount: (data[6] as num?)?.toInt() ?? 1,
      layoutOrder:
          ((data[7] as List?) ?? const <dynamic>[])
              .map((dynamic e) => e.toString())
              .toList(growable: false),
      widgetOrder:
          ((data[8] as List?) ?? const <dynamic>[])
              .map((dynamic e) => e.toString())
              .toList(growable: false),
    );
  }

  @override
  void write(BinaryWriter writer, BuilderPageHiveModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.icon)
      ..writeByte(3)
      ..write(obj.navigationType)
      ..writeByte(4)
      ..write(obj.isDeleted)
      ..writeByte(5)
      ..write(obj.parentPageId)
      ..writeByte(6)
      ..write(obj.widgetGridCount)
      ..writeByte(7)
      ..write(obj.layoutOrder)
      ..writeByte(8)
      ..write(obj.widgetOrder);
  }
}
