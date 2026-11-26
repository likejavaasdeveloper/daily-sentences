import 'dart:async';

import 'package:daily_sentences/application/exercise/navigate_sentences.dart';
import 'package:daily_sentences/application/sentence/sentence_package_repository.dart';
import 'package:daily_sentences/domain/catalog/catalog.dart';
import 'package:daily_sentences/domain/sentence/sentence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts by loading only the required first package', () async {
    final repository = _FakePackageRepository({
      'one': _package('French', 'Travel', 4),
      'two': _package('French', 'Travel', 1),
    });
    final useCase = NavigateSentences(repository);

    final position = await useCase.start(_selection(['one', 'two']));
    await Future<void>.delayed(Duration.zero);

    expect(position.sentence.text, 'sentence-0');
    expect(repository.loads, ['one']);
  });

  test('prefetches only the next package at two remaining sentences', () async {
    final repository = _FakePackageRepository({
      'one': _package('French', 'Travel', 4),
      'two': _package('French', 'Travel', 4),
      'three': _package('French', 'Travel', 1),
    });
    final useCase = NavigateSentences(repository);
    var position = await useCase.start(_selection(['one', 'two', 'three']));

    position = await useCase.moveNext(position);
    await Future<void>.delayed(Duration.zero);

    expect(NavigateSentences.prefetchThreshold, 2);
    expect(repository.loads, ['one', 'two']);
    expect(repository.loads, isNot(contains('three')));
  });

  test('navigates across a package boundary', () async {
    final repository = _FakePackageRepository({
      'one': _package('French', 'Travel', 1),
      'two': SentencePackage(
        language: 'French',
        category: 'Travel',
        sentences: const [
          Sentence(text: 'boundary', translation: 'b', usages: []),
        ],
      ),
    });
    final useCase = NavigateSentences(repository);
    final first = await useCase.start(_selection(['one', 'two']));

    final second = await useCase.moveNext(first);

    expect(second.packageIndex, 1);
    expect(second.sentenceIndex, 0);
    expect(second.sentence.text, 'boundary');
  });

  test(
    'clears cache only when the selected language or category changes',
    () async {
      final repository = _FakePackageRepository({
        'one': _package('French', 'Travel', 4),
      });
      final useCase = NavigateSentences(repository);
      final travel = _selection(['one']);

      await useCase.start(travel);
      await useCase.start(travel);
      await useCase.start(
        SentenceSelection(
          contentVersion: 'version',
          language: 'French',
          category: 'Food',
          packages: const [
            PackageReference(path: 'one', sentenceCount: 4, checksum: 'one'),
          ],
        ),
      );

      expect(repository.clearCount, 2);
    },
  );

  test('rejects an empty package list', () {
    final useCase = NavigateSentences(_FakePackageRepository({}));

    expect(
      useCase.start(
        const SentenceSelection(
          contentVersion: 'version',
          language: 'French',
          category: 'Travel',
          packages: [],
        ),
      ),
      throwsA(isA<SentenceNavigationException>()),
    );
  });

  test('an older selection completion is rejected as stale', () async {
    final pending = Completer<SentencePackage>();
    final repository = _DelayedPackageRepository(pending);
    final useCase = NavigateSentences(repository);
    final oldLoad = useCase.start(_selection(['old']));
    final currentLoad = useCase.start(_selection(['new'], category: 'Food'));

    pending.complete(_package('French', 'Travel', 1));

    await expectLater(oldLoad, throwsA(isA<StaleSentenceLoadException>()));
    expect((await currentLoad).selection.category, 'Food');
  });
}

SentenceSelection _selection(List<String> paths, {String category = 'Travel'}) {
  return SentenceSelection(
    contentVersion: 'version',
    language: 'French',
    category: category,
    packages: paths
        .map(
          (path) => PackageReference(
            path: path,
            sentenceCount: path == 'one' ? 4 : 1,
            checksum: path,
          ),
        )
        .toList(growable: false),
  );
}

SentencePackage _package(String language, String category, int count) {
  return SentencePackage(
    language: language,
    category: category,
    sentences: List.generate(
      count,
      (index) => Sentence(
        text: 'sentence-$index',
        translation: 'translation-$index',
        usages: const [],
      ),
      growable: false,
    ),
  );
}

class _FakePackageRepository implements SentencePackageRepository {
  _FakePackageRepository(this.packages);

  final Map<String, SentencePackage> packages;
  final List<String> loads = [];
  int clearCount = 0;

  @override
  void clearCache() => clearCount++;

  @override
  Future<SentencePackage> loadPackage({
    required String contentVersion,
    required String language,
    required String category,
    required PackageReference reference,
  }) async {
    loads.add(reference.path);
    final package = packages[reference.path];
    if (package == null) {
      throw StateError('missing ${reference.path}');
    }
    return package;
  }
}

class _DelayedPackageRepository implements SentencePackageRepository {
  _DelayedPackageRepository(this.pending);

  final Completer<SentencePackage> pending;

  @override
  void clearCache() {}

  @override
  Future<SentencePackage> loadPackage({
    required String contentVersion,
    required String language,
    required String category,
    required PackageReference reference,
  }) {
    if (reference.path == 'old') {
      return pending.future;
    }
    return Future.value(_package('French', 'Food', 1));
  }
}
