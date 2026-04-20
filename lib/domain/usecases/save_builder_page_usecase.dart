import 'package:antwise/domain/entities/builder_page_entity.dart';
import 'package:antwise/domain/repositories/builder_pages_repository.dart';

class SaveBuilderPageUseCase {
  SaveBuilderPageUseCase(this._repository);

  final BuilderPagesRepository _repository;

  Future<void> call(BuilderPageEntity page) => _repository.savePage(page);
}
