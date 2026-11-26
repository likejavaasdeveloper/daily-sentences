import 'package:daily_sentences/application/catalog/load_catalog.dart';
import 'package:daily_sentences/presentation/catalog_navigation/catalog_navigation_mapper.dart';
import 'package:daily_sentences/presentation/catalog_navigation/catalog_navigation_state.dart';
import 'package:flutter/foundation.dart';

class CatalogNavigationNotifier extends ChangeNotifier {
  CatalogNavigationNotifier({
    required LoadCatalog loadCatalog,
    required CatalogNavigationMapper mapper,
  }) : _loadCatalog = loadCatalog,
       _mapper = mapper;

  final LoadCatalog _loadCatalog;
  final CatalogNavigationMapper _mapper;
  CatalogNavigationState _state = const CatalogLoading();

  CatalogNavigationState get state => _state;

  Future<void> load() async {
    _state = const CatalogLoading();
    notifyListeners();
    try {
      _state = _mapper.mapCatalog(await _loadCatalog());
    } catch (error) {
      _state = _mapper.mapFailure(error);
    }
    notifyListeners();
  }

  void selectLanguage(String language) {
    final state = _state;
    if (state is CatalogReady) {
      _state = state.selectLanguage(language);
      notifyListeners();
    }
  }

  void selectCategory(String language, String category) {
    final state = _state;
    if (state is CatalogReady) {
      _state = state.selectCategory(language, category);
      notifyListeners();
    }
  }
}
