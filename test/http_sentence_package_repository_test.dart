import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:daily_sentences/domain/catalog/catalog.dart';
import 'package:daily_sentences/infrastructure/sentence/http_sentence_package_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('resolves package paths under a GitHub Pages repository base', () {
    expect(
      generatedContentUriForBase(
        Uri.parse('https://example.github.io/daily-sentences/'),
      ),
      Uri.parse('https://example.github.io/daily-sentences/generated/'),
    );
  });

  test(
    'loads only the requested package and reuses its cached result',
    () async {
      const body =
          '{"schemaVersion":1,"language":"French","category":"Travel",'
          '"sentences":[{"sentence":"Bonjour","translation":"Hello",'
          '"usages":[]}]}';
      final reference = _reference(body, 1);
      var requests = 0;
      final repository = _repository((request) async {
        requests++;
        expect(
          request.url.path,
          '/daily-sentences/generated/${reference.path}',
        );
        return http.Response(body, 200);
      });

      final first = await repository.loadPackage(
        contentVersion: 'version',
        language: 'French',
        category: 'Travel',
        reference: reference,
      );
      final second = await repository.loadPackage(
        contentVersion: 'version',
        language: 'French',
        category: 'Travel',
        reference: reference,
      );

      expect(first.sentences.single.text, 'Bonjour');
      expect(identical(first, second), isTrue);
      expect(requests, 1);
    },
  );

  test('deduplicates concurrent HTTP requests', () async {
    const body =
        '{"schemaVersion":1,"language":"French","category":"Travel",'
        '"sentences":[{"sentence":"Bonjour","translation":"Hello",'
        '"usages":[]}]}';
    final reference = _reference(body, 1);
    var requests = 0;
    final repository = _repository((_) async {
      requests++;
      await Future<void>.delayed(Duration.zero);
      return http.Response(body, 200);
    });

    await Future.wait([
      repository.loadPackage(
        contentVersion: 'version',
        language: 'French',
        category: 'Travel',
        reference: reference,
      ),
      repository.loadPackage(
        contentVersion: 'version',
        language: 'French',
        category: 'Travel',
        reference: reference,
      ),
    ]);

    expect(requests, 1);
  });

  test('rejects checksum mismatches before decoding content', () async {
    const body = '{}';
    final invalidChecksum = List.filled(64, '0').join();
    final reference = PackageReference(
      path: 'sentences/$invalidChecksum.json',
      sentenceCount: 1,
      checksum: invalidChecksum,
    );
    final repository = _repository((_) async => http.Response(body, 200));

    expect(
      repository.loadPackage(
        contentVersion: 'version',
        language: 'French',
        category: 'Travel',
        reference: reference,
      ),
      throwsA(
        isA<SentencePackageLoadException>().having(
          (error) => error.message,
          'message',
          contains('checksum'),
        ),
      ),
    );
  });

  test(
    'rejects schema, language, category, count, and field mismatches',
    () async {
      final invalidBodies = <String, String>{
        'schemaVersion':
            '{"schemaVersion":2,"language":"French","category":"Travel",'
            '"sentences":[{"sentence":"a","translation":"b","usages":[]}]}',
        'language':
            '{"schemaVersion":1,"language":"Spanish","category":"Travel",'
            '"sentences":[{"sentence":"a","translation":"b","usages":[]}]}',
        'category':
            '{"schemaVersion":1,"language":"French","category":"Food",'
            '"sentences":[{"sentence":"a","translation":"b","usages":[]}]}',
        'sentence count':
            '{"schemaVersion":1,"language":"French","category":"Travel",'
            '"sentences":[{"sentence":"a","translation":"b","usages":[]},'
            '{"sentence":"c","translation":"d","usages":[]}]}',
        'unknown':
            '{"schemaVersion":1,"language":"French","category":"Travel",'
            '"sentences":[{"sentence":"a","translation":"b","usages":[],"id":1}]}',
      };
      for (final entry in invalidBodies.entries) {
        final reference = _reference(entry.value, 1);
        final repository = _repository(
          (_) async => http.Response(entry.value, 200),
        );

        await expectLater(
          repository.loadPackage(
            contentVersion: 'version',
            language: 'French',
            category: 'Travel',
            reference: reference,
          ),
          throwsA(
            isA<SentencePackageLoadException>().having(
              (error) => error.message,
              'message',
              contains(entry.key),
            ),
          ),
        );
      }
    },
  );

  test('rejects invalid content-addressed catalog references', () async {
    final repository = _repository((_) async => http.Response('', 200));
    const reference = PackageReference(
      path: 'sentences/not-the-checksum.json',
      sentenceCount: 1,
      checksum:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );

    expect(
      repository.loadPackage(
        contentVersion: 'version',
        language: 'French',
        category: 'Travel',
        reference: reference,
      ),
      throwsA(isA<SentencePackageLoadException>()),
    );
  });
}

HttpSentencePackageRepository _repository(
  Future<http.Response> Function(http.Request) handler,
) {
  return HttpSentencePackageRepository(
    client: MockClient(handler),
    generatedContentUri: Uri.parse(
      'https://example.github.io/daily-sentences/generated/',
    ),
  );
}

PackageReference _reference(String body, int sentenceCount) {
  final checksum = sha256.convert(utf8.encode(body)).toString();
  return PackageReference(
    path: 'sentences/$checksum.json',
    sentenceCount: sentenceCount,
    checksum: checksum,
  );
}
