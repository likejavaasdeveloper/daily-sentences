import 'package:daily_sentences/domain/catalog/catalog.dart';
import 'package:daily_sentences/presentation/catalog_navigation/catalog_navigation_state.dart';

class CatalogNavigationMapper {
  const CatalogNavigationMapper();

  CatalogNavigationState mapCatalog(Catalog catalog) {
    if (catalog.languages.isEmpty) {
      return const CatalogEmpty();
    }
    return CatalogReady(
      contentVersion: catalog.contentVersion,
      languages: catalog.languages
          .map(
            (language) => CatalogLanguageItem(
              code: language.code,
              sentenceCount: language.sentenceCount,
              categories: language.categories
                  .map(
                    (category) => CatalogCategoryItem(
                      code: category.code,
                      sentenceCount: category.sentenceCount,
                      packages: category.packages,
                    ),
                  )
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
    );
  }

  CatalogFailure mapFailure(Object error) {
    return CatalogFailure('Content could not be loaded. ${error.toString()}');
  }
}
