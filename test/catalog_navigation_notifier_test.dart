import 'package:daily_sentences/application/catalog/catalog_repository.dart';
import 'package:daily_sentences/application/catalog/load_catalog.dart';
import 'package:daily_sentences/domain/catalog/catalog.dart';
import 'package:daily_sentences/presentation/catalog_navigation/catalog_navigation_mapper.dart';
import 'package:daily_sentences/presentation/catalog_navigation/catalog_navigation_notifier.dart';
import 'package:daily_sentences/presentation/catalog_navigation/catalog_navigation_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps an empty catalog to the empty state', () async {
    final notifier = _notifier([
      const Catalog(schemaVersion: 1, contentVersion: 'a', languages: []),
    ]);

    await notifier.load();

    expect(notifier.state, isA<CatalogEmpty>());
  });

  test('maps only catalog languages, categories, and counts', () async {
    final notifier = _notifier([
      Catalog(
        schemaVersion: 1,
        contentVersion: 'a',
        languages: [
          CatalogLanguage(
            code: 'French',
            sentenceCount: 3,
            categories: [
              const CatalogCategory(
                code: 'Greetings',
                sentenceCount: 2,
                packages: [],
              ),
              const CatalogCategory(
                code: 'Travel',
                sentenceCount: 1,
                packages: [
                  PackageReference(
                    path: 'sentences/value.json',
                    sentenceCount: 1,
                    checksum: 'value',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ]);

    await notifier.load();

    final state = notifier.state as CatalogReady;
    expect(state.languages.single.code, 'French');
    expect(state.languages.single.sentenceCount, 3);
    expect(state.languages.single.categories.map((item) => item.code), [
      'Greetings',
      'Travel',
    ]);
    expect(
      state.languages.single.categories.last.packages.single.path,
      'sentences/value.json',
    );
    notifier.selectLanguage('French');
    notifier.selectCategory('French', 'Travel');
    expect((notifier.state as CatalogReady).selectedCategory, 'Travel');
  });

  test('exposes failure and retries the same use case', () async {
    final notifier = _notifier([
      StateError('network unavailable'),
      const Catalog(schemaVersion: 1, contentVersion: 'a', languages: []),
    ]);

    await notifier.load();
    expect(notifier.state, isA<CatalogFailure>());
    await notifier.load();
    expect(notifier.state, isA<CatalogEmpty>());
  });
}

CatalogNavigationNotifier _notifier(List<Object> results) {
  return CatalogNavigationNotifier(
    loadCatalog: LoadCatalog(_FakeCatalogRepository(results)),
    mapper: const CatalogNavigationMapper(),
  );
}

class _FakeCatalogRepository implements CatalogRepository {
  _FakeCatalogRepository(this._results);

  final List<Object> _results;

  @override
  Future<Catalog> loadCatalog() async {
    final result = _results.removeAt(0);
    if (result is Catalog) {
      return result;
    }
    throw result;
  }
}
