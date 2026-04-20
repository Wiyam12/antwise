import 'package:antwise/domain/entities/builder_page_entity.dart';

abstract class BuilderPagesRepository {
  Future<List<BuilderPageEntity>> getPages();

  Future<void> savePage(BuilderPageEntity page);

  Future<void> replacePages(List<BuilderPageEntity> pages);
}
