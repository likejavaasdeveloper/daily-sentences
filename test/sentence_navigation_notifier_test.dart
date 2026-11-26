import 'dart:async';

import 'package:daily_sentences/application/exercise/navigate_sentences.dart';
import 'package:daily_sentences/application/sentence/sentence_package_repository.dart';
import 'package:daily_sentences/domain/catalog/catalog.dart';
import 'package:daily_sentences/domain/sentence/sentence.dart';
import 'package:daily_sentences/presentation/sentence_navigation/sentence_navigation_mapper.dart';
import 'package:daily_sentences/presentation/sentence_navigation/sentence_navigation_notifier.dart';
import 'package:daily_sentences/presentation/sentence_navigation/sentence_navigation_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exposes loading, failure, and successful retry states', () async {
    final repository = _ResultRepository([
      StateError('offline'),
      _package('French', 'Travel', ['one']),
    ]);
    final notifier = _notifier(repository);
    final states = <Type>[];
    notifier.addListener(() => states.add(notifier.state.runtimeType));

    await notifier.loadSelection(_selection('Travel', 'travel'));
    expect(notifier.state, isA<SentenceNavigationFailure>());
    await notifier.retry();

    expect(notifier.state, isA<SentenceNavigationReady>());
    expect(
      states,
      containsAllInOrder([
        SentenceNavigationLoading,
        SentenceNavigationFailure,
        SentenceNavigationLoading,
        SentenceNavigationReady,
      ]),
    );
  });

  test('a new sentence receives fresh temporary exercise state', () async {
    final notifier = _notifier(
      _ResultRepository([
        _package('French', 'Travel', ['one', 'two']),
      ]),
    );
    await notifier.loadSelection(_selection('Travel', 'travel'));
    notifier.updateAnswer('temporary answer');
    notifier.revealAnswer();
    final edited = notifier.state as SentenceNavigationReady;
    expect(edited.enteredAnswer, 'temporary answer');
    expect(edited.isAnswerRevealed, isTrue);

    await notifier.moveNext();

    final next = notifier.state as SentenceNavigationReady;
    expect(next.position.sentence.text, 'two');
    expect(next.enteredAnswer, isEmpty);
    expect(next.isAnswerRevealed, isFalse);
  });

  test('a stale response cannot replace the current selection state', () async {
    final pending = Completer<SentencePackage>();
    final repository = _SelectionRepository(pending);
    final notifier = _notifier(repository);
    final oldLoad = notifier.loadSelection(_selection('Travel', 'old'));
    final currentLoad = notifier.loadSelection(_selection('Food', 'new'));
    await currentLoad;

    pending.complete(_package('French', 'Travel', ['old']));
    await oldLoad;

    final state = notifier.state as SentenceNavigationReady;
    expect(state.position.selection.category, 'Food');
    expect(state.position.sentence.text, 'new');
  });

  test('clear selection ignores an in-flight completion', () async {
    final pending = Completer<SentencePackage>();
    final notifier = _notifier(_PendingRepository(pending));
    final load = notifier.loadSelection(_selection('Travel', 'old'));

    notifier.clearSelection();
    pending.complete(_package('French', 'Travel', ['old']));
    await load;

    expect(notifier.state, isA<SentenceNavigationIdle>());
  });
}

SentenceNavigationNotifier _notifier(SentencePackageRepository repository) {
  return SentenceNavigationNotifier(
    navigateSentences: NavigateSentences(repository),
    mapper: const SentenceNavigationMapper(),
  );
}

SentenceSelection _selection(String category, String path) {
  return SentenceSelection(
    contentVersion: 'version',
    language: 'French',
    category: category,
    packages: [PackageReference(path: path, sentenceCount: 2, checksum: path)],
  );
}

SentencePackage _package(
  String language,
  String category,
  List<String> sentences,
) {
  return SentencePackage(
    language: language,
    category: category,
    sentences: sentences
        .map(
          (text) => Sentence(
            text: text,
            translation: '$text translation',
            usages: const [],
          ),
        )
        .toList(growable: false),
  );
}

class _ResultRepository implements SentencePackageRepository {
  _ResultRepository(this.results);

  final List<Object> results;

  @override
  void clearCache() {}

  @override
  Future<SentencePackage> loadPackage({
    required String contentVersion,
    required String language,
    required String category,
    required PackageReference reference,
  }) async {
    final result = results.removeAt(0);
    if (result is SentencePackage) {
      return result;
    }
    throw result;
  }
}

class _SelectionRepository implements SentencePackageRepository {
  _SelectionRepository(this.pending);

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
    return Future.value(_package('French', 'Food', ['new']));
  }
}

class _PendingRepository implements SentencePackageRepository {
  _PendingRepository(this.pending);

  final Completer<SentencePackage> pending;

  @override
  void clearCache() {}

  @override
  Future<SentencePackage> loadPackage({
    required String contentVersion,
    required String language,
    required String category,
    required PackageReference reference,
  }) => pending.future;
}
