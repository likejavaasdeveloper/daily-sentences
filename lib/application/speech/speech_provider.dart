class SpeechVoice {
  const SpeechVoice({
    required this.id,
    required this.name,
    required this.language,
  });

  final String id;
  final String name;
  final String language;
}

class SpeechRequest {
  const SpeechRequest({
    required this.text,
    required this.language,
    required this.voice,
    required this.rate,
  });

  final String text;
  final String language;
  final SpeechVoice voice;
  final double rate;
}

abstract interface class SpeechProvider {
  bool get isSupported;

  List<SpeechVoice> get voices;

  Stream<List<SpeechVoice>> get voicesChanged;

  Future<void> speak(SpeechRequest request);

  void stop();

  void dispose();
}

class SpeechPlaybackException implements Exception {
  const SpeechPlaybackException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SpeechPlaybackCancelled implements Exception {
  const SpeechPlaybackCancelled();
}
