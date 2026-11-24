import 'dart:convert';

import 'package:daily_sentences/application/sentence/sentence_package_repository.dart';
import 'package:daily_sentences/domain/catalog/catalog.dart';
import 'package:daily_sentences/domain/sentence/sentence.dart';
import 'package:daily_sentences/infrastructure/sentence/package_cache.dart';
import 'package:daily_sentences/infrastructure/sentence/package_integrity.dart';
import 'package:http/http.dart' as http;

class HttpSentencePackageRepository implements SentencePackageRepository {
  HttpSentencePackageRepository({
    required http.Client client,
    required Uri generatedContentUri,
    PackageCache<SentencePackage>? cache,
  }) : _client = client,
       _generatedContentUri = generatedContentUri,
       _cache = cache ?? PackageCache<SentencePackage>();

  final http.Client _client;
  final Uri _generatedContentUri;
  final PackageCache<SentencePackage> _cache;

  @override
  Future<SentencePackage> loadPackage({
    required String contentVersion,
    required String language,
    required String category,
    required PackageReference reference,
  }) async {
    _validateReference(reference);
    return _cache.obtain(
      contentVersion: contentVersion,
      key: reference.path,
      load: () => _fetchPackage(
        language: language,
        category: category,
        reference: reference,
      ),
    );
  }

  @override
  void clearCache() => _cache.clear();

  Future<SentencePackage> _fetchPackage({
    required String language,
    required String category,
    required PackageReference reference,
  }) async {
    final response = await _client.get(
      _generatedContentUri.resolve(reference.path),
      headers: const {
        'Cache-Control': 'no-cache',
        'Accept': 'application/json',
      },
    );
    if (response.statusCode != 200) {
      throw SentencePackageLoadException(
        '${reference.path}: request failed with status '
        '${response.statusCode}.',
      );
    }
    if (!hasValidPackageChecksum(response.bodyBytes, reference.checksum)) {
      throw SentencePackageLoadException(
        '${reference.path}: checksum does not match the catalog.',
      );
    }
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException catch (error) {
      throw SentencePackageLoadException(
        '${reference.path}: invalid UTF-8 JSON: ${error.message}',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw SentencePackageLoadException(
        '${reference.path}: package must be a JSON object.',
      );
    }
    try {
      _requireFields(decoded, const {
        'schemaVersion',
        'language',
        'category',
        'sentences',
      }, 'package');
      if (_readInt(decoded, 'schemaVersion') != 1) {
        throw const FormatException('schemaVersion must be 1.');
      }
      final packageLanguage = _readString(decoded, 'language');
      final packageCategory = _readString(decoded, 'category');
      if (packageLanguage != language) {
        throw FormatException(
          'language "$packageLanguage" does not match catalog language '
          '"$language".',
        );
      }
      if (packageCategory != category) {
        throw FormatException(
          'category "$packageCategory" does not match catalog category '
          '"$category".',
        );
      }
      final sentenceValues = _readList(decoded, 'sentences');
      if (sentenceValues.isEmpty || sentenceValues.length > 500) {
        throw const FormatException(
          'sentences must contain between 1 and 500 entries.',
        );
      }
      if (sentenceValues.length != reference.sentenceCount) {
        throw FormatException(
          'sentence count ${sentenceValues.length} does not match catalog '
          'count ${reference.sentenceCount}.',
        );
      }
      final sentences = <Sentence>[];
      for (var index = 0; index < sentenceValues.length; index++) {
        sentences.add(_decodeSentence(sentenceValues[index], index));
      }
      return SentencePackage(
        language: packageLanguage,
        category: packageCategory,
        sentences: List.unmodifiable(sentences),
      );
    } on FormatException catch (error) {
      throw SentencePackageLoadException('${reference.path}: ${error.message}');
    }
  }

  Sentence _decodeSentence(Object? value, int index) {
    if (value is! Map<String, dynamic>) {
      throw FormatException('sentences[$index] must be an object.');
    }
    _requireFields(value, const {
      'sentence',
      'translation',
      'usages',
    }, 'sentences[$index]');
    final usages = _readList(value, 'usages');
    final decodedUsages = <String>[];
    for (var usageIndex = 0; usageIndex < usages.length; usageIndex++) {
      final usage = usages[usageIndex];
      if (usage is! String || usage.trim().isEmpty) {
        throw FormatException(
          'sentences[$index].usages[$usageIndex] must be a nonempty string.',
        );
      }
      decodedUsages.add(usage);
    }
    return Sentence(
      text: _readString(value, 'sentence'),
      translation: _readString(value, 'translation'),
      usages: List.unmodifiable(decodedUsages),
    );
  }

  void _validateReference(PackageReference reference) {
    final checksumPattern = RegExp(r'^[0-9a-f]{64}$');
    if (!checksumPattern.hasMatch(reference.checksum)) {
      throw SentencePackageLoadException(
        '${reference.path}: checksum must be lowercase SHA-256 hexadecimal.',
      );
    }
    if (reference.path != 'sentences/${reference.checksum}.json') {
      throw SentencePackageLoadException(
        '${reference.path}: path must identify its catalog checksum.',
      );
    }
    if (reference.sentenceCount < 1 || reference.sentenceCount > 500) {
      throw SentencePackageLoadException(
        '${reference.path}: catalog sentence count must be between 1 and 500.',
      );
    }
  }

  void _requireFields(
    Map<String, dynamic> value,
    Set<String> expected,
    String location,
  ) {
    final actual = value.keys.toSet();
    final missing = expected.difference(actual);
    final unknown = actual.difference(expected);
    if (missing.isNotEmpty) {
      throw FormatException('$location is missing ${missing.join(', ')}.');
    }
    if (unknown.isNotEmpty) {
      throw FormatException(
        '$location contains unknown ${unknown.join(', ')}.',
      );
    }
  }

  List<Object?> _readList(Map<String, dynamic> value, String name) {
    final result = value[name];
    if (result is List<Object?>) {
      return result;
    }
    throw FormatException('$name must be an array.');
  }

  String _readString(Map<String, dynamic> value, String name) {
    final result = value[name];
    if (result is String && result.trim().isNotEmpty) {
      return result;
    }
    throw FormatException('$name must be a nonempty string.');
  }

  int _readInt(Map<String, dynamic> value, String name) {
    final result = value[name];
    if (result is int) {
      return result;
    }
    throw FormatException('$name must be an integer.');
  }
}

class SentencePackageLoadException implements Exception {
  const SentencePackageLoadException(this.message);

  final String message;

  @override
  String toString() => message;
}

Uri generatedContentUriForBase(Uri baseUri) => baseUri.resolve('generated/');
