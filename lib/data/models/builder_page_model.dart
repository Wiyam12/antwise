import 'package:antwise/domain/entities/builder_page_entity.dart';

class BuilderPageModel {
  const BuilderPageModel({
    required this.id,
    required this.name,
    required this.showInBottomNav,
    required this.showInDrawer,
    this.isDeleted = false,
    this.iconName = 'article_outlined',
    this.isDrawerParentContainer = false,
    this.parentPageId,
    this.nestedDisplayType,
    this.nestedRootContentTabName,
    this.widgetGridCount = 1,
    this.layoutOrder = const <String>[],
    this.widgetOrder = const <String>[],
  });

  final String id;
  final String name;
  final bool showInBottomNav;
  final bool showInDrawer;
  final bool isDeleted;
  final String iconName;
  final bool isDrawerParentContainer;
  final String? parentPageId;
  final String? nestedDisplayType;
  final String? nestedRootContentTabName;
  final int widgetGridCount;
  final List<String> layoutOrder;
  final List<String> widgetOrder;

  BuilderPageEntity toEntity() => BuilderPageEntity(
    id: id,
    name: name,
    showInBottomNav: showInBottomNav,
    showInDrawer: showInDrawer,
    isDeleted: isDeleted,
    iconName: iconName,
    isDrawerParentContainer: isDrawerParentContainer,
    parentPageId: parentPageId,
    nestedDisplayType: NestedPageDisplayType.tryFromStorage(nestedDisplayType),
    nestedRootContentTabName: nestedRootContentTabName,
    widgetGridCount: widgetGridCount,
    layoutOrder: layoutOrder,
    widgetOrder: widgetOrder,
  );

  factory BuilderPageModel.fromEntity(BuilderPageEntity entity) =>
      BuilderPageModel(
        id: entity.id,
        name: entity.name,
        showInBottomNav: entity.showInBottomNav,
        showInDrawer: entity.showInDrawer,
        isDeleted: entity.isDeleted,
        iconName: entity.iconName,
        isDrawerParentContainer: entity.isDrawerParentContainer,
        parentPageId: entity.parentPageId,
        nestedDisplayType: entity.nestedDisplayType?.storageValue,
        nestedRootContentTabName: entity.nestedRootContentTabName,
        widgetGridCount: entity.widgetGridCount,
        layoutOrder: entity.layoutOrder,
        widgetOrder: entity.widgetOrder,
      );

  factory BuilderPageModel.fromJson(Map<String, dynamic> json) =>
      BuilderPageModel(
        id: json['id'] as String,
        name: json['name'] as String,
        showInBottomNav: json['showInBottomNav'] as bool? ?? false,
        showInDrawer: json['showInDrawer'] as bool? ?? false,
        isDeleted: json['isDeleted'] as bool? ?? false,
        iconName: json['iconName'] as String? ?? 'article_outlined',
        isDrawerParentContainer:
            json['isDrawerParentContainer'] as bool? ?? false,
        parentPageId: json['parentPageId'] as String?,
        nestedDisplayType: json['nestedDisplayType'] as String?,
        nestedRootContentTabName: json['nestedRootContentTabName'] as String?,
        widgetGridCount: (json['widgetGridCount'] as num?)?.toInt() ?? 1,
        layoutOrder:
            ((json['layoutOrder'] as List?) ?? const <dynamic>[])
                .map((dynamic e) => e.toString())
                .toList(growable: false),
        widgetOrder:
            ((json['widgetOrder'] as List?) ?? const <dynamic>[])
                .map((dynamic e) => e.toString())
                .toList(growable: false),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'showInBottomNav': showInBottomNav,
    'showInDrawer': showInDrawer,
    'isDeleted': isDeleted,
    'iconName': iconName,
    'isDrawerParentContainer': isDrawerParentContainer,
    'parentPageId': parentPageId,
    'nestedDisplayType': nestedDisplayType,
    'nestedRootContentTabName': nestedRootContentTabName,
    'widgetGridCount': widgetGridCount,
    'layoutOrder': layoutOrder,
    'widgetOrder': widgetOrder,
  };
}
