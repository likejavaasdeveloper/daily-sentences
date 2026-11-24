import 'dart:collection';

class PackageCache<T> {
  PackageCache({this.capacity = 3}) {
    if (capacity < 1 || capacity > 3) {
      throw ArgumentError.value(capacity, 'capacity');
    }
  }
  final int capacity;
  final LinkedHashMap<String, T> _values = LinkedHashMap();
  final Map<String, Future<T>> _pending = {};
  String? _contentVersion;
  int _generation = 0;

  Future<T> obtain({
    required String contentVersion,
    required String key,
    required Future<T> Function() load,
  }) {
    if (_contentVersion != contentVersion) {
      clear();
      _contentVersion = contentVersion;
    }
    final cached = _values.remove(key);
    if (cached != null) {
      _values[key] = cached;
      return Future.value(cached);
    }
    final pending = _pending[key];
    if (pending != null) {
      return pending;
    }
    final generation = _generation;
    late final Future<T> request;
    request = () async {
      try {
        final value = await load();
        if (_generation == generation) {
          _values[key] = value;
          if (_values.length > capacity) {
            _values.remove(_values.keys.first);
          }
        }
        return value;
      } finally {
        if (identical(_pending[key], request)) {
          _pending.remove(key);
        }
      }
    }();
    _pending[key] = request;
    return request;
  }

  void clear() {
    _generation++;
    _values.clear();
    _pending.clear();
  }
}
