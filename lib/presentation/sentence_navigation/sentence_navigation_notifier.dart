import 'package:daily_sentences/application/exercise/navigate_sentences.dart';
import 'package:daily_sentences/presentation/sentence_navigation/sentence_navigation_mapper.dart';
import 'package:daily_sentences/presentation/sentence_navigation/sentence_navigation_state.dart';
import 'package:flutter/foundation.dart';

class SentenceNavigationNotifier extends ChangeNotifier {
  SentenceNavigationNotifier({
    required NavigateSentences navigateSentences,
    required SentenceNavigationMapper mapper,
  }) : _navigateSentences = navigateSentences,
       _mapper = mapper;

  final NavigateSentences _navigateSentences;
  final SentenceNavigationMapper _mapper;
  SentenceNavigationState _state = const SentenceNavigationIdle();
  SentenceSelection? _selection;
  SentencePosition? _position;
  bool _retryMoveNext = false;
  int _requestGeneration = 0;

  SentenceNavigationState get state => _state;

  Future<void> loadSelection(SentenceSelection selection) async {
    _selection = selection;
    _retryMoveNext = false;
    final generation = ++_requestGeneration;
    _state = const SentenceNavigationLoading();
    notifyListeners();
    try {
      final position = await _navigateSentences.start(selection);
      if (generation != _requestGeneration) {
        return;
      }
      _position = position;
      _state = _mapper.mapPosition(position);
    } on StaleSentenceLoadException {
      return;
    } on Object catch (error) {
      if (generation != _requestGeneration) {
        return;
      }
      _state = _mapper.mapFailure(error);
    }
    notifyListeners();
  }

  Future<void> moveNext() async {
    final current = _position;
    if (current == null || !current.hasNext) {
      return;
    }
    _retryMoveNext = true;
    final generation = ++_requestGeneration;
    _state = const SentenceNavigationLoading();
    notifyListeners();
    try {
      final position = await _navigateSentences.moveNext(current);
      if (generation != _requestGeneration) {
        return;
      }
      _position = position;
      _retryMoveNext = false;
      _state = _mapper.mapPosition(position);
    } on StaleSentenceLoadException {
      return;
    } on Object catch (error) {
      if (generation != _requestGeneration) {
        return;
      }
      _state = _mapper.mapFailure(error);
    }
    notifyListeners();
  }

  Future<void> retry() {
    if (_retryMoveNext) {
      return moveNext();
    }
    final selection = _selection;
    if (selection == null) {
      return Future.value();
    }
    return loadSelection(selection);
  }

  void updateAnswer(String answer) {
    final state = _state;
    if (state is SentenceNavigationReady) {
      _state = state.withAnswer(answer);
      notifyListeners();
    }
  }

  void revealAnswer() {
    final state = _state;
    if (state is SentenceNavigationReady) {
      _state = state.revealAnswer();
      notifyListeners();
    }
  }

  void clearSelection() {
    _requestGeneration++;
    _selection = null;
    _position = null;
    _retryMoveNext = false;
    _navigateSentences.clearSelection();
    _state = const SentenceNavigationIdle();
    notifyListeners();
  }
}
