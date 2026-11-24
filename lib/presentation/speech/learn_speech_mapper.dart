import 'package:daily_sentences/application/speech/control_speech.dart';
import 'package:daily_sentences/presentation/speech/learn_speech_state.dart';

class LearnSpeechMapper {
  const LearnSpeechMapper();

  LearnSpeechState mapDiscovering(double rate) {
    return LearnSpeechState(
      status: LearnSpeechStatus.discovering,
      rate: rate,
      canPlay: false,
      message: 'Discovering browser voices…',
    );
  }

  LearnSpeechState mapAvailability(
    SpeechAvailability availability,
    double rate,
  ) {
    if (!availability.isSupported) {
      return LearnSpeechState(
        status: LearnSpeechStatus.unavailable,
        rate: rate,
        canPlay: false,
        message: 'Speech synthesis is not supported by this browser.',
      );
    }
    final voice = availability.voice;
    if (voice == null) {
      return LearnSpeechState(
        status: LearnSpeechStatus.unavailable,
        rate: rate,
        canPlay: false,
        message: 'No suitable voice is available for this language.',
      );
    }
    return LearnSpeechState(
      status: LearnSpeechStatus.ready,
      rate: rate,
      canPlay: true,
      voiceName: voice.name,
    );
  }

  LearnSpeechState mapPlaying(double rate, String? voiceName) {
    return LearnSpeechState(
      status: LearnSpeechStatus.playing,
      rate: rate,
      canPlay: true,
      message: 'Playing pronunciation…',
      voiceName: voiceName,
    );
  }

  LearnSpeechState mapFailure(double rate, Object error) {
    return LearnSpeechState(
      status: LearnSpeechStatus.failure,
      rate: rate,
      canPlay: true,
      message: 'Pronunciation failed. You can retry or continue learning.',
    );
  }
}
