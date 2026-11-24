import 'package:daily_sentences/application/speech/speech_provider.dart';

SpeechProvider createSpeechProvider() => _UnsupportedSpeechProvider();

class _UnsupportedSpeechProvider implements SpeechProvider {
  @override
  bool get isSupported => false;

  @override
  List<SpeechVoice> get voices => const [];

  @override
  Stream<List<SpeechVoice>> get voicesChanged => const Stream.empty();

  @override
  Future<void> speak(SpeechRequest request) {
    throw const SpeechPlaybackException('Speech synthesis is unsupported.');
  }

  @override
  void stop() {}

  @override
  void dispose() {}
}
