enum LearnSpeechStatus { discovering, unavailable, ready, playing, failure }

class LearnSpeechState {
  const LearnSpeechState({
    required this.status,
    required this.rate,
    required this.canPlay,
    this.message,
    this.voiceName,
  });

  const LearnSpeechState.unavailable()
    : status = LearnSpeechStatus.unavailable,
      rate = 1,
      canPlay = false,
      message = null,
      voiceName = null;

  final LearnSpeechStatus status;
  final double rate;
  final bool canPlay;
  final String? message;
  final String? voiceName;

  LearnSpeechState withRate(double value) {
    return LearnSpeechState(
      status: status,
      rate: value,
      canPlay: canPlay,
      message: message,
      voiceName: voiceName,
    );
  }
}
