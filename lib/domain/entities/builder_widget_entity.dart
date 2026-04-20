class BuilderWidgetEntity {
  const BuilderWidgetEntity({
    required this.id,
    required this.pageId,
    required this.type,
    required this.config,
  });

  final String id;
  final String pageId;
  final String type;
  final Map<String, dynamic> config;
}
