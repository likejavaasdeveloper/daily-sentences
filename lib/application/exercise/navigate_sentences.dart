import 'dart:async';

import 'package:daily_sentences/application/sentence/sentence_package_repository.dart';
import 'package:daily_sentences/domain/catalog/catalog.dart';
import 'package:daily_sentences/domain/sentence/sentence.dart';

class SentenceSelection {
  const SentenceSelection({
    required this.contentVersion,
    required this.language,
    required this.category,
    required this.packages,
  });

  final String contentVersion;
  final String language;
  final String category;
  final List<PackageReference> packages;
}

class SentencePosition {
  const SentencePosition({
    required this.selection,
    required this.packageIndex,
    required this.sentenceIndex,
    required this.package,
  });

  final SentenceSelection selection;
  final int packageIndex;
  final int sentenceIndex;
  final SentencePackage package;

  Sentence get sentence => package.sentences[sentenceIndex];

  bool get hasNext =>
      sentenceIndex + 1 < package.sentences.length ||
      packageIndex + 1 < selection.packages.length;
}

class NavigateSentences {
  NavigateSentences(this._repository);

  static const int prefetchThreshold = 2;

  final SentencePackageRepository _repository;
  String? _selectionKey;
  int _selectionGeneration = 0;

  Future<SentencePosition> start(SentenceSelection selection) async {
    if (selection.packages.isEmpty) {
      throw const SentenceNavigationException(
        'The selected category has no sentence packages.',
      );
    }
    final selectionKey = '${selection.language}\u0000${selection.category}';
    if (_selectionKey != selectionKey) {
      _repository.clearCache();
      _selectionKey = selectionKey;
    }
    final generation = ++_selectionGeneration;
    final package = await _load(selection, 0);
    if (generation != _selectionGeneration) {
      throw const StaleSentenceLoadException();
    }
    final position = SentencePosition(
      selection: selection,
      packageIndex: 0,
      sentenceIndex: 0,
      package: package,
    );
    _schedulePrefetch(position, generation);
    return position;
  }

  Future<SentencePosition> moveNext(SentencePosition current) async {
    final nextSentenceIndex = current.sentenceIndex + 1;
    if (nextSentenceIndex < current.package.sentences.length) {
      final position = SentencePosition(
        selection: current.selection,
        packageIndex: current.packageIndex,
        sentenceIndex: nextSentenceIndex,
        package: current.package,
      );
      _schedulePrefetch(position, _selectionGeneration);
      return position;
    }
    final nextPackageIndex = current.packageIndex + 1;
    if (nextPackageIndex >= current.selection.packages.length) {
      return current;
    }
    final generation = _selectionGeneration;
    final package = await _load(current.selection, nextPackageIndex);
    if (generation != _selectionGeneration) {
      throw const StaleSentenceLoadException();
    }
    final position = SentencePosition(
      selection: current.selection,
      packageIndex: nextPackageIndex,
      sentenceIndex: 0,
      package: package,
    );
    _schedulePrefetch(position, generation);
    return position;
  }

  void clearSelection() {
    _selectionGeneration++;
    _selectionKey = null;
    _repository.clearCache();
  }

  Future<SentencePackage> _load(SentenceSelection selection, int packageIndex) {
    return _repository.loadPackage(
      contentVersion: selection.contentVersion,
      language: selection.language,
      category: selection.category,
      reference: selection.packages[packageIndex],
    );
  }

  void _schedulePrefetch(SentencePosition position, int generation) {
    final remaining =
        position.package.sentences.length - position.sentenceIndex - 1;
    final nextPackageIndex = position.packageIndex + 1;
    if (remaining > prefetchThreshold ||
        nextPackageIndex >= position.selection.packages.length) {
      return;
    }
    unawaited(_prefetch(position.selection, nextPackageIndex, generation));
  }

  Future<void> _prefetch(
    SentenceSelection selection,
    int packageIndex,
    int generation,
  ) async {
    if (generation != _selectionGeneration) {
      return;
    }
    try {
      await _load(selection, packageIndex);
    } on Object {
      return;
    }
  }
}

class SentenceNavigationException implements Exception {
  const SentenceNavigationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class StaleSentenceLoadException implements Exception {
  const StaleSentenceLoadException();
}
