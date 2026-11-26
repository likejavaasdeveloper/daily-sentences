import 'dart:async';

import 'package:daily_sentences/application/exercise/manage_exercise.dart';
import 'package:daily_sentences/application/speech/control_speech.dart';
import 'package:daily_sentences/application/speech/speech_provider.dart';
import 'package:daily_sentences/presentation/exercise/exercise_mapper.dart';
import 'package:daily_sentences/presentation/exercise/exercise_state.dart';
import 'package:flutter/foundation.dart';

class ExerciseNotifier extends ChangeNotifier {
  ExerciseNotifier({
    required ManageExercise manageExercise,
    required ExerciseMapper mapper,
  }) : _manageExercise = manageExercise,
       _mapper = mapper;

  final ManageExercise _manageExercise;
  final ExerciseMapper _mapper;
  ExerciseState _state = const ExerciseState.learn();
  String? _text;
  String? _language;
  StreamSubscription<SpeechAvailability>? _availabilitySubscription;
  Timer? _discoveryTimer;
  int _playbackGeneration = 0;
  int _exerciseGeneration = 0;
  bool _fallbackLocked = false;
  bool _discoveredVoice = false;

  ExerciseState get state => _state;

  void loadSentence({required String text, required String language}) {
    ++_playbackGeneration;
    ++_exerciseGeneration;
    _cancelDiscovery();
    unawaited(_availabilitySubscription?.cancel());
    _availabilitySubscription = null;
    _manageExercise.stop();
    _text = text;
    _language = language;
    _fallbackLocked = false;
    _discoveredVoice = false;
    _state = const ExerciseState.learn();
    notifyListeners();
  }

  void selectLearn() {
    ++_playbackGeneration;
    _manageExercise.stop();
    _cancelDiscovery();
    unawaited(_availabilitySubscription?.cancel());
    _availabilitySubscription = null;
    _state = _state.copyWith(mode: ExerciseMode.learn);
    notifyListeners();
  }

  void openExercise() {
    if (_fallbackLocked) {
      _state = _mapper.rewrite(_state);
      notifyListeners();
      return;
    }
    final language = _language;
    if (language == null) {
      return;
    }
    final generation = ++_exerciseGeneration;
    _state = _mapper.discovering(_state);
    notifyListeners();
    unawaited(_availabilitySubscription?.cancel());
    _availabilitySubscription = _manageExercise
        .observeAvailability(language)
        .listen(
          (availability) {
            if (generation != _exerciseGeneration ||
                _fallbackLocked ||
                _state.mode == ExerciseMode.learn) {
              return;
            }
            if (!availability.isSupported || availability.voice == null) {
              if (availability.isSupported) {
                if (_discoveredVoice) {
                  _fallbackToRewrite();
                }
                return;
              }
              _fallbackToRewrite();
              return;
            }
            _cancelDiscovery();
            _discoveredVoice = true;
            _state = _mapper.available(_state, availability);
            notifyListeners();
          },
          onError: (_) {
            if (generation == _exerciseGeneration) {
              _fallbackToRewrite();
            }
          },
        );
    _discoveryTimer = Timer(ManageExercise.discoveryTimeout, () {
      if (generation == _exerciseGeneration &&
          !_fallbackLocked &&
          _state.mode == ExerciseMode.dictation &&
          !_state.canPlay) {
        _fallbackToRewrite();
      }
    });
  }

  void setRate(double rate) {
    _state = _state.copyWith(rate: rate);
    notifyListeners();
  }

  Future<void> play() async {
    final text = _text;
    final language = _language;
    if (text == null ||
        language == null ||
        !_state.canPlay ||
        _state.mode != ExerciseMode.dictation) {
      return;
    }
    final generation = ++_playbackGeneration;
    _state = _mapper.playing(_state);
    notifyListeners();
    try {
      await _manageExercise.play(
        text: text,
        language: language,
        rate: _state.rate,
      );
      if (generation != _playbackGeneration) {
        return;
      }
      _state = _state.copyWith(
        speechStatus: ExerciseSpeechStatus.ready,
        canPlay: true,
        message: null,
      );
      notifyListeners();
    } on SpeechPlaybackCancelled {
      if (generation != _playbackGeneration) {
        return;
      }
      _state = _state.copyWith(
        speechStatus: ExerciseSpeechStatus.ready,
        canPlay: true,
        message: null,
      );
      notifyListeners();
    } on Object {
      if (generation != _playbackGeneration) {
        return;
      }
      _fallbackToRewrite();
    }
  }

  void updateAnswer(String answer) {
    _state = _state.copyWith(enteredAnswer: answer, feedback: null);
    notifyListeners();
  }

  void revealAnswer() {
    _state = _state.copyWith(isAnswerRevealed: true);
    notifyListeners();
  }

  void checkAnswer() {
    final text = _text;
    if (text == null) {
      return;
    }
    final matches = _manageExercise.compare(_state.enteredAnswer, text);
    _state = _state.copyWith(
      feedback: matches
          ? 'That matches. Nicely done.'
          : 'Not quite yet—you can adjust your answer and try again.',
    );
    notifyListeners();
  }

  void clearSentence({bool notify = true}) {
    ++_playbackGeneration;
    ++_exerciseGeneration;
    _cancelDiscovery();
    unawaited(_availabilitySubscription?.cancel());
    _availabilitySubscription = null;
    _manageExercise.stop();
    _text = null;
    _language = null;
    _fallbackLocked = false;
    _discoveredVoice = false;
    _state = const ExerciseState.learn();
    if (notify) {
      notifyListeners();
    }
  }

  void _fallbackToRewrite() {
    ++_playbackGeneration;
    _manageExercise.stop();
    _cancelDiscovery();
    unawaited(_availabilitySubscription?.cancel());
    _fallbackLocked = true;
    _state = _mapper.rewrite(_state);
    notifyListeners();
  }

  void _cancelDiscovery() {
    _discoveryTimer?.cancel();
    _discoveryTimer = null;
  }

  @override
  void dispose() {
    ++_playbackGeneration;
    ++_exerciseGeneration;
    _cancelDiscovery();
    unawaited(_availabilitySubscription?.cancel());
    _manageExercise.stop();
    super.dispose();
  }
}
