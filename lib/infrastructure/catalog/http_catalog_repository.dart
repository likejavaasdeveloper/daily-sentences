import 'dart:convert';

import 'package:daily_sentences/application/catalog/catalog_repository.dart';
import 'package:daily_sentences/domain/catalog/catalog.dart';
import 'package:http/http.dart' as http;

class HttpCatalogRepository implements CatalogRepository {
  HttpCatalogRepository({required http.Client client, required Uri catalogUri})
    : _client = client,
      _catalogUri = catalogUri;

  final http.Client _client;
  final Uri _catalogUri;

  @override
  Future<Catalog> loadCatalog() async {
    final response = await _client.get(
      _catalogUri,
      headers: const {
        'Cache-Control': 'no-cache',
        'Accept': 'application/json',
      },
    );
    if (response.statusCode != 200) {
      throw CatalogLoadException(
        'Catalog request failed with status ${response.statusCode}.',
      );
    }
    return _decodeCatalog(response.body);
  }

  Catalog _decodeCatalog(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const CatalogLoadException('Catalog must be a JSON object.');
    }
    try {
      return Catalog(
        schemaVersion: _readInt(decoded, 'schemaVersion'),
        contentVersion: _readString(decoded, 'contentVersion'),
        languages: _readList(
          decoded,
          'languages',
        ).map(_decodeLanguage).toList(growable: false),
      );
    } on FormatException catch (error) {
      throw CatalogLoadException(error.message);
    }
  }

  CatalogLanguage _decodeLanguage(Object? value) {
    final decoded = _readObject(value, 'language');
    return CatalogLanguage(
      code: _readString(decoded, 'code'),
      sentenceCount: _readInt(decoded, 'sentenceCount'),
      categories: _readList(
        decoded,
        'categories',
      ).map(_decodeCategory).toList(growable: false),
    );
  }

  CatalogCategory _decodeCategory(Object? value) {
    final decoded = _readObject(value, 'category');
    return CatalogCategory(
      code: _readString(decoded, 'code'),
      sentenceCount: _readInt(decoded, 'sentenceCount'),
      packages: _readList(
        decoded,
        'packages',
      ).map(_decodePackage).toList(growable: false),
    );
  }

  PackageReference _decodePackage(Object? value) {
    final decoded = _readObject(value, 'package');
    return PackageReference(
      path: _readString(decoded, 'path'),
      sentenceCount: _readInt(decoded, 'sentenceCount'),
      checksum: _readString(decoded, 'checksum'),
    );
  }

  Map<String, dynamic> _readObject(Object? value, String name) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    throw FormatException('$name must be an object.');
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
    if (result is String && result.isNotEmpty) {
      return result;
    }
    throw FormatException('$name must be a nonempty string.');
  }

  int _readInt(Map<String, dynamic> value, String name) {
    final result = value[name];
    if (result is int && result >= 0) {
      return result;
    }
    throw FormatException('$name must be a nonnegative integer.');
  }
}

class CatalogLoadException implements Exception {
  const CatalogLoadException(this.message);

  final String message;
}

Uri catalogUriForBase(Uri baseUri) => baseUri.resolve('generated/catalog.json');
