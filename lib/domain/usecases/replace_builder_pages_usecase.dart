import 'package:antwise/domain/entities/builder_page_entity.dart';
import 'package:antwise/domain/repositories/builder_pages_repository.dart';

class ReplaceBuilderPagesUseCase {
  ReplaceBuilderPagesUseCase(this._repository);

  final BuilderPagesRepository _repository;

  Future<void> call(List<BuilderPageEntity> pages) =>
      _repository.replacePages(pages);
}
