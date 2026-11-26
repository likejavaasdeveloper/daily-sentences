import 'package:daily_sentences/infrastructure/catalog/http_catalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('resolves catalog relative to a GitHub Pages repository base path', () {
    final uri = catalogUriForBase(
      Uri.parse('https://example.github.io/daily-sentences/'),
    );

    expect(
      uri,
      Uri.parse(
        'https://example.github.io/daily-sentences/generated/catalog.json',
      ),
    );
  });

  test('decodes catalog metadata without requesting packages', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/daily-sentences/generated/catalog.json');
      return http.Response(
        '{"schemaVersion":1,"contentVersion":"version","languages":[{"code":"French","sentenceCount":2,"categories":[{"code":"Greetings","sentenceCount":2,"packages":[{"path":"sentences/value.json","sentenceCount":2,"checksum":"value"}]}]}]}',
        200,
      );
    });
    final repository = HttpCatalogRepository(
      client: client,
      catalogUri: Uri.parse(
        'https://example.github.io/daily-sentences/generated/catalog.json',
      ),
    );

    final catalog = await repository.loadCatalog();

    expect(catalog.languages.single.code, 'French');
    expect(catalog.languages.single.categories.single.code, 'Greetings');
  });

  test('reports catalog request failures', () async {
    final repository = HttpCatalogRepository(
      client: MockClient((_) async => http.Response('', 503)),
      catalogUri: Uri.parse('https://example.github.io/generated/catalog.json'),
    );

    expect(repository.loadCatalog, throwsA(isA<CatalogLoadException>()));
  });
}
