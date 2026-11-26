import 'package:daily_sentences/application/catalog/catalog_repository.dart';
import 'package:daily_sentences/domain/catalog/catalog.dart';

class LoadCatalog {
  const LoadCatalog(this._repository);

  final CatalogRepository _repository;

  Future<Catalog> call() => _repository.loadCatalog();
}
