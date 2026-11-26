import 'dart:async';

import 'package:daily_sentences/application/exercise/compare_answer.dart';
import 'package:daily_sentences/infrastructure/sentence/package_cache.dart';
import 'package:daily_sentences/infrastructure/sentence/package_integrity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'compares incidental whitespace and punctuation without changing diacritics',
    () {
      const compare = CompareAnswer();
      expect(compare(' Bonjour,   monde! ', 'bonjour monde'), isTrue);
      expect(compare('cafe', 'café'), isFalse);
    },
  );

  test(
    'deduplicates concurrent requests and evicts least recently used package',
    () async {
      final cache = PackageCache<String>();
      var calls = 0;
      Future<String> load(String value) async {
        calls++;
        return value;
      }

      await Future.wait([
        cache.obtain(contentVersion: 'a', key: 'one', load: () => load('one')),
        cache.obtain(contentVersion: 'a', key: 'one', load: () => load('one')),
      ]);
      await cache.obtain(
        contentVersion: 'a',
        key: 'two',
        load: () => load('two'),
      );
      await cache.obtain(
        contentVersion: 'a',
        key: 'three',
        load: () => load('three'),
      );
      await cache.obtain(
        contentVersion: 'a',
        key: 'four',
        load: () => load('four'),
      );
      await cache.obtain(
        contentVersion: 'a',
        key: 'one',
        load: () => load('one'),
      );
      expect(calls, 5);
    },
  );

  test('promotes cache hits before LRU eviction', () async {
    final cache = PackageCache<String>();
    final calls = <String>[];

    Future<String> obtain(String key) {
      return cache.obtain(
        contentVersion: 'a',
        key: key,
        load: () async {
          calls.add(key);
          return key;
        },
      );
    }

    await obtain('one');
    await obtain('two');
    await obtain('three');
    await obtain('one');
    await obtain('four');
    await obtain('two');

    expect(calls, ['one', 'two', 'three', 'four', 'two']);
  });

  test('rejects cache capacities above the approved maximum', () {
    expect(() => PackageCache<String>(capacity: 4), throwsArgumentError);
  });

  test('validates package checksums', () {
    expect(
      hasValidPackageChecksum([
        1,
        2,
        3,
      ], '039058c6f2c0cb492c533b0a4d14ef77cc0f78abccced5287d84a1a2011cfb81'),
      isTrue,
    );
    expect(hasValidPackageChecksum([1, 2, 3], 'invalid'), isFalse);
  });

  test('invalidates cached packages when content version changes', () async {
    final cache = PackageCache<String>();
    var calls = 0;

    Future<String> load() async => 'value-${++calls}';

    expect(
      await cache.obtain(contentVersion: 'one', key: 'key', load: load),
      'value-1',
    );
    expect(
      await cache.obtain(contentVersion: 'two', key: 'key', load: load),
      'value-2',
    );
  });

  test('a cleared pending request cannot repopulate the cache', () async {
    final cache = PackageCache<String>();
    final stalePending = Completer<String>();
    final freshPending = Completer<String>();
    var calls = 0;
    final first = cache.obtain(
      contentVersion: 'one',
      key: 'key',
      load: () {
        calls++;
        return stalePending.future;
      },
    );

    cache.clear();
    final second = cache.obtain(
      contentVersion: 'one',
      key: 'key',
      load: () {
        calls++;
        return freshPending.future;
      },
    );
    stalePending.complete('stale');
    await first;
    final deduplicated = cache.obtain(
      contentVersion: 'one',
      key: 'key',
      load: () async {
        calls++;
        return 'unexpected';
      },
    );
    freshPending.complete('fresh');

    expect(await second, 'fresh');
    expect(await deduplicated, 'fresh');
    expect(
      await cache.obtain(
        contentVersion: 'one',
        key: 'key',
        load: () async {
          calls++;
          return 'unexpected';
        },
      ),
      'fresh',
    );
    expect(calls, 2);
  });
}
