import 'package:daily_sentences/domain/catalog/catalog.dart';

abstract interface class CatalogRepository {
  Future<Catalog> loadCatalog();
}
