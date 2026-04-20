import 'package:antwise/domain/entities/builder_page_entity.dart';
import 'package:antwise/domain/repositories/builder_pages_repository.dart';

class GetBuilderPagesUseCase {
  GetBuilderPagesUseCase(this._repository);

  final BuilderPagesRepository _repository;

  Future<List<BuilderPageEntity>> call() => _repository.getPages();
}
