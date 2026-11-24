import 'dart:async';

import 'package:daily_sentences/application/exercise/compare_answer.dart';
import 'package:daily_sentences/application/speech/control_speech.dart';

class ManageExercise {
  ManageExercise({
    required ControlSpeech controlSpeech,
    CompareAnswer comparator = const CompareAnswer(),
  }) : _controlSpeech = controlSpeech,
       _comparator = comparator;

  static const discoveryTimeout = Duration(seconds: 5);

  final ControlSpeech _controlSpeech;
  final CompareAnswer _comparator;

  Stream<SpeechAvailability> observeAvailability(String language) =>
      _controlSpeech.observeAvailability(language);

  Future<void> play({
    required String text,
    required String language,
    required double rate,
  }) => _controlSpeech.play(text: text, language: language, rate: rate);

  void stop() => _controlSpeech.stop();

  bool compare(String answer, String expected) => _comparator(answer, expected);
}
