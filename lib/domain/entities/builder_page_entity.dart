/// User-defined page metadata for the no-code builder.
class BuilderPageEntity {
  const BuilderPageEntity({
    required this.id,
    required this.name,
    required this.showInBottomNav,
    required this.showInDrawer,
    this.isDeleted = false,
    this.iconName = 'article_outlined',
    this.parentPageId,
    this.widgetGridCount = 1,
    this.layoutOrder = const <String>[],
    this.widgetOrder = const <String>[],
  });

  final String id;
  final String name;
  final bool showInBottomNav;
  final bool showInDrawer;
  final bool isDeleted;

  /// Persisted Material icon key (snake_case), e.g. article_outlined.
  final String iconName;

  /// Optional parent page id when this page is a drawer child item.
  final String? parentPageId;

  /// Number of cards per row for the grouped widgets block (1..3).
  final int widgetGridCount;

  /// Ordered layout component keys (e.g. `widgets`, `table:<id>`).
  final List<String> layoutOrder;

  /// Ordered card widget ids for the widgets block.
  final List<String> widgetOrder;

  bool get hasAnyPlacement => showInBottomNav || showInDrawer;

  BuilderPageEntity copyWith({
    String? id,
    String? name,
    bool? showInBottomNav,
    bool? showInDrawer,
    bool? isDeleted,
    String? iconName,
    String? parentPageId,
    int? widgetGridCount,
    List<String>? layoutOrder,
    List<String>? widgetOrder,
  }) {
    return BuilderPageEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      showInBottomNav: showInBottomNav ?? this.showInBottomNav,
      showInDrawer: showInDrawer ?? this.showInDrawer,
      isDeleted: isDeleted ?? this.isDeleted,
      iconName: iconName ?? this.iconName,
      parentPageId: parentPageId ?? this.parentPageId,
      widgetGridCount: widgetGridCount ?? this.widgetGridCount,
      layoutOrder: layoutOrder ?? this.layoutOrder,
      widgetOrder: widgetOrder ?? this.widgetOrder,
    );
  }
}
