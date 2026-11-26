import 'package:daily_sentences/application/speech/speech_provider.dart';

class SpeechAvailability {
  const SpeechAvailability({required this.isSupported, required this.voice});

  final bool isSupported;
  final SpeechVoice? voice;

  bool get isAvailable => isSupported && voice != null;
}

class ControlSpeech {
  ControlSpeech(this._provider);

  final SpeechProvider _provider;

  Stream<SpeechAvailability> observeAvailability(String language) async* {
    yield _availability(language, _provider.voices);
    await for (final voices in _provider.voicesChanged) {
      yield _availability(language, voices);
    }
  }

  Future<void> play({
    required String text,
    required String language,
    required double rate,
  }) async {
    final voice = selectSuitableVoice(language, _provider.voices);
    if (!_provider.isSupported || voice == null) {
      throw const SpeechPlaybackException(
        'No suitable voice is available for this language.',
      );
    }
    _provider.stop();
    await _provider.speak(
      SpeechRequest(text: text, language: language, voice: voice, rate: rate),
    );
  }

  void stop() => _provider.stop();

  void dispose() => _provider.dispose();

  SpeechAvailability _availability(String language, List<SpeechVoice> voices) {
    return SpeechAvailability(
      isSupported: _provider.isSupported,
      voice: selectSuitableVoice(language, voices),
    );
  }
}

SpeechVoice? selectSuitableVoice(
  String requestedLanguage,
  List<SpeechVoice> voices,
) {
  final normalizedRequested = requestedLanguage.toLowerCase();
  for (final voice in voices) {
    if (voice.language.toLowerCase() == normalizedRequested) {
      return voice;
    }
  }
  final requestedPrimary = _primaryLanguage(requestedLanguage);
  if (requestedPrimary == null) {
    return null;
  }
  for (final voice in voices) {
    if (_primaryLanguage(voice.language) == requestedPrimary) {
      return voice;
    }
  }
  return null;
}

String? _primaryLanguage(String language) {
  final parts = language.toLowerCase().split('-');
  if (parts.isEmpty ||
      parts.first == 'x' ||
      parts.first == 'i' ||
      parts.first.length < 2 ||
      parts.first.length > 3) {
    return null;
  }
  return parts.first;
}
