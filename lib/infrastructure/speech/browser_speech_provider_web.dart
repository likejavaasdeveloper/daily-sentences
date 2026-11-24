import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:daily_sentences/application/speech/speech_provider.dart';
import 'package:web/web.dart' as web;

SpeechProvider createSpeechProvider() => BrowserSpeechProvider();

class BrowserSpeechProvider implements SpeechProvider {
  BrowserSpeechProvider() {
    _supported =
        globalContext.has('speechSynthesis') &&
        globalContext.has('SpeechSynthesisUtterance');
    if (_supported) {
      _synthesis = web.window.speechSynthesis;
      _voicesChangedListener = ((web.Event event) {
        _voiceChanges.add(voices);
      }).toJS;
      _synthesis!.addEventListener('voiceschanged', _voicesChangedListener);
    }
  }

  final StreamController<List<SpeechVoice>> _voiceChanges =
      StreamController.broadcast(sync: true);
  final Map<String, web.SpeechSynthesisVoice> _nativeVoices = {};
  late final bool _supported;
  web.SpeechSynthesis? _synthesis;
  web.EventListener? _voicesChangedListener;
  Completer<void>? _activeCompletion;
  int _playbackGeneration = 0;
  bool _disposed = false;

  @override
  bool get isSupported => _supported && !_disposed;

  @override
  List<SpeechVoice> get voices {
    if (!isSupported) {
      return const [];
    }
    _nativeVoices.clear();
    return _synthesis!
        .getVoices()
        .toDart
        .map((voice) {
          final id = '${voice.voiceURI}\u0000${voice.name}\u0000${voice.lang}';
          _nativeVoices[id] = voice;
          return SpeechVoice(id: id, name: voice.name, language: voice.lang);
        })
        .toList(growable: false);
  }

  @override
  Stream<List<SpeechVoice>> get voicesChanged => _voiceChanges.stream;

  @override
  Future<void> speak(SpeechRequest request) {
    if (!isSupported) {
      throw const SpeechPlaybackException('Speech synthesis is unsupported.');
    }
    final availableVoices = voices;
    if (!availableVoices.any((voice) => voice.id == request.voice.id)) {
      throw const SpeechPlaybackException(
        'The selected browser voice is no longer available.',
      );
    }
    final nativeVoice = _nativeVoices[request.voice.id];
    if (nativeVoice == null) {
      throw const SpeechPlaybackException(
        'The selected browser voice is no longer available.',
      );
    }
    stop();
    final generation = _playbackGeneration;
    final completion = Completer<void>();
    _activeCompletion = completion;
    final utterance = web.SpeechSynthesisUtterance(request.text)
      ..lang = request.language
      ..voice = nativeVoice
      ..rate = request.rate;
    utterance.onend = ((web.Event event) {
      if (generation == _playbackGeneration && !completion.isCompleted) {
        _activeCompletion = null;
        completion.complete();
      }
    }).toJS;
    utterance.onerror = ((web.Event event) {
      if (generation == _playbackGeneration && !completion.isCompleted) {
        _activeCompletion = null;
        completion.completeError(
          const SpeechPlaybackException('Browser speech playback failed.'),
        );
      }
    }).toJS;
    try {
      _synthesis!.speak(utterance);
    } on Object catch (error) {
      _activeCompletion = null;
      if (!completion.isCompleted) {
        completion.completeError(
          SpeechPlaybackException('Browser speech playback failed: $error'),
        );
      }
    }
    return completion.future;
  }

  @override
  void stop() {
    _playbackGeneration++;
    if (_supported) {
      _synthesis?.cancel();
    }
    final completion = _activeCompletion;
    _activeCompletion = null;
    if (completion != null && !completion.isCompleted) {
      completion.completeError(const SpeechPlaybackCancelled());
    }
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    stop();
    final listener = _voicesChangedListener;
    if (_supported && listener != null) {
      _synthesis?.removeEventListener('voiceschanged', listener);
    }
    _disposed = true;
    _voiceChanges.close();
  }
}
