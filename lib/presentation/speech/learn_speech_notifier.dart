import 'dart:async';

import 'package:daily_sentences/application/speech/control_speech.dart';
import 'package:daily_sentences/presentation/speech/learn_speech_mapper.dart';
import 'package:daily_sentences/presentation/speech/learn_speech_state.dart';
import 'package:flutter/foundation.dart';

class LearnSpeechNotifier extends ChangeNotifier {
  LearnSpeechNotifier({
    required ControlSpeech controlSpeech,
    required LearnSpeechMapper mapper,
  }) : _controlSpeech = controlSpeech,
       _mapper = mapper;

  final ControlSpeech _controlSpeech;
  final LearnSpeechMapper _mapper;
  LearnSpeechState _state = const LearnSpeechState.unavailable();
  StreamSubscription<SpeechAvailability>? _availabilitySubscription;
  String? _text;
  String? _language;
  int _sentenceGeneration = 0;
  int _playbackGeneration = 0;

  LearnSpeechState get state => _state;

  void loadSentence({required String text, required String language}) {
    final generation = ++_sentenceGeneration;
    _playbackGeneration++;
    _controlSpeech.stop();
    unawaited(_availabilitySubscription?.cancel());
    _text = text;
    _language = language;
    _state = _mapper.mapDiscovering(_state.rate);
    notifyListeners();
    _availabilitySubscription = _controlSpeech
        .observeAvailability(language)
        .listen(
          (availability) {
            if (generation != _sentenceGeneration) {
              return;
            }
            if (!availability.isAvailable &&
                _state.status == LearnSpeechStatus.playing) {
              _playbackGeneration++;
              _controlSpeech.stop();
            }
            if (_state.status != LearnSpeechStatus.playing ||
                !availability.isAvailable) {
              _state = _mapper.mapAvailability(availability, _state.rate);
              notifyListeners();
            }
          },
          onError: (Object error) {
            if (generation != _sentenceGeneration) {
              return;
            }
            _state = _mapper.mapFailure(_state.rate, error);
            notifyListeners();
          },
        );
  }

  void setRate(double rate) {
    _state = _state.withRate(rate);
    notifyListeners();
  }

  Future<void> play() async {
    final text = _text;
    final language = _language;
    if (text == null || language == null || !_state.canPlay) {
      return;
    }
    final generation = ++_playbackGeneration;
    final voiceName = _state.voiceName;
    _state = _mapper.mapPlaying(_state.rate, voiceName);
    notifyListeners();
    try {
      await _controlSpeech.play(
        text: text,
        language: language,
        rate: _state.rate,
      );
      if (generation != _playbackGeneration) {
        return;
      }
      await _refreshAvailability(language);
    } on Object catch (error) {
      if (generation != _playbackGeneration) {
        return;
      }
      _state = _mapper.mapFailure(_state.rate, error);
      notifyListeners();
    }
  }

  void clearSentence({bool notify = true}) {
    _sentenceGeneration++;
    _playbackGeneration++;
    _text = null;
    _language = null;
    _controlSpeech.stop();
    unawaited(_availabilitySubscription?.cancel());
    _availabilitySubscription = null;
    _state = const LearnSpeechState.unavailable();
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> _refreshAvailability(String language) async {
    await for (final availability in _controlSpeech.observeAvailability(
      language,
    )) {
      _state = _mapper.mapAvailability(availability, _state.rate);
      notifyListeners();
      return;
    }
  }

  @override
  void dispose() {
    _sentenceGeneration++;
    _playbackGeneration++;
    _controlSpeech.stop();
    unawaited(_availabilitySubscription?.cancel());
    super.dispose();
  }
}
