/// How child pages are shown when a parent page is opened (siblings use the same value).
enum NestedPageDisplayType {
  tab,
  segmented;

  static NestedPageDisplayType? tryFromStorage(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return switch (value) {
      'tab' => NestedPageDisplayType.tab,
      'segmented' => NestedPageDisplayType.segmented,
      _ => null,
    };
  }

  String get storageValue => switch (this) {
    NestedPageDisplayType.tab => 'tab',
    NestedPageDisplayType.segmented => 'segmented',
  };
}

/// User-defined page metadata for the no-code builder.
class BuilderPageEntity {
  const BuilderPageEntity({
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

  /// Persisted Material icon key (snake_case), e.g. article_outlined.
  final String iconName;

  /// True when this node is a drawer grouping container (folder), not a
  /// navigable content page.
  final bool isDrawerParentContainer;

  /// Optional parent page id when this page is a drawer child item.
  final String? parentPageId;

  /// When [parentPageId] is set, how the parent should present sibling child pages
  /// (tab bar vs segmented control). Null for standalone or legacy pages.
  final NestedPageDisplayType? nestedDisplayType;

  /// When this page is a tab/segment host and still has its own builder content,
  /// label for the first tab (that content). Null = use [name].
  final String? nestedRootContentTabName;

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
    bool? isDrawerParentContainer,
    String? parentPageId,
    NestedPageDisplayType? nestedDisplayType,
    String? nestedRootContentTabName,
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
      isDrawerParentContainer:
          isDrawerParentContainer ?? this.isDrawerParentContainer,
      parentPageId: parentPageId ?? this.parentPageId,
      nestedDisplayType: nestedDisplayType ?? this.nestedDisplayType,
      nestedRootContentTabName:
          nestedRootContentTabName ?? this.nestedRootContentTabName,
      widgetGridCount: widgetGridCount ?? this.widgetGridCount,
      layoutOrder: layoutOrder ?? this.layoutOrder,
      widgetOrder: widgetOrder ?? this.widgetOrder,
    );
  }
}
