import 'package:daily_sentences/domain/catalog/catalog.dart';
import 'package:daily_sentences/domain/sentence/sentence.dart';

abstract interface class SentencePackageRepository {
  Future<SentencePackage> loadPackage({
    required String contentVersion,
    required String language,
    required String category,
    required PackageReference reference,
  });

  void clearCache();
}
