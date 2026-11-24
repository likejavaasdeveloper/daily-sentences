import 'package:daily_sentences/domain/catalog/catalog.dart';

class CatalogNavigationState {
  const CatalogNavigationState();
}

class CatalogLoading extends CatalogNavigationState {
  const CatalogLoading();
}

class CatalogEmpty extends CatalogNavigationState {
  const CatalogEmpty();
}

class CatalogReady extends CatalogNavigationState {
  const CatalogReady({
    required this.contentVersion,
    required this.languages,
    this.selectedLanguage,
    this.selectedCategory,
  });

  final String contentVersion;
  final List<CatalogLanguageItem> languages;
  final String? selectedLanguage;
  final String? selectedCategory;

  CatalogReady selectLanguage(String language) {
    return CatalogReady(
      contentVersion: contentVersion,
      languages: languages,
      selectedLanguage: language,
    );
  }

  CatalogReady selectCategory(String language, String category) {
    return CatalogReady(
      contentVersion: contentVersion,
      languages: languages,
      selectedLanguage: language,
      selectedCategory: category,
    );
  }
}

class CatalogFailure extends CatalogNavigationState {
  const CatalogFailure(this.message);

  final String message;
}

class CatalogLanguageItem {
  const CatalogLanguageItem({
    required this.code,
    required this.sentenceCount,
    required this.categories,
  });

  final String code;
  final int sentenceCount;
  final List<CatalogCategoryItem> categories;
}

class CatalogCategoryItem {
  const CatalogCategoryItem({
    required this.code,
    required this.sentenceCount,
    required this.packages,
  });

  final String code;
  final int sentenceCount;
  final List<PackageReference> packages;
}
