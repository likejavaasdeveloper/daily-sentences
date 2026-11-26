class Catalog {
  const Catalog({
    required this.schemaVersion,
    required this.contentVersion,
    required this.languages,
  });

  final int schemaVersion;
  final String contentVersion;
  final List<CatalogLanguage> languages;
}

class CatalogLanguage {
  const CatalogLanguage({
    required this.code,
    required this.sentenceCount,
    required this.categories,
  });

  final String code;
  final int sentenceCount;
  final List<CatalogCategory> categories;
}

class CatalogCategory {
  const CatalogCategory({
    required this.code,
    required this.sentenceCount,
    required this.packages,
  });

  final String code;
  final int sentenceCount;
  final List<PackageReference> packages;
}

class PackageReference {
  const PackageReference({
    required this.path,
    required this.sentenceCount,
    required this.checksum,
  });
  final String path;
  final int sentenceCount;
  final String checksum;
}
