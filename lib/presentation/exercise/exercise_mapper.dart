import 'package:daily_sentences/application/speech/control_speech.dart';
import 'package:daily_sentences/presentation/exercise/exercise_state.dart';

class ExerciseMapper {
  const ExerciseMapper();

  ExerciseState discovering(ExerciseState state) {
    return state.copyWith(
      mode: ExerciseMode.dictation,
      speechStatus: ExerciseSpeechStatus.discovering,
      canPlay: false,
      feedback: null,
      message: null,
    );
  }

  ExerciseState available(
    ExerciseState state,
    SpeechAvailability availability,
  ) {
    if (!availability.isSupported) {
      return state.copyWith(
        mode: ExerciseMode.rewrite,
        speechStatus: ExerciseSpeechStatus.unavailable,
        canPlay: false,
        feedback: null,
        message: null,
      );
    }
    if (availability.voice == null) {
      return state.copyWith(
        speechStatus: ExerciseSpeechStatus.discovering,
        canPlay: false,
        message: null,
      );
    }
    return state.copyWith(
      mode: ExerciseMode.dictation,
      speechStatus: ExerciseSpeechStatus.ready,
      canPlay: true,
      message: null,
    );
  }

  ExerciseState rewrite(ExerciseState state) {
    return state.copyWith(
      mode: ExerciseMode.rewrite,
      speechStatus: ExerciseSpeechStatus.unavailable,
      canPlay: false,
      feedback: null,
      message: null,
    );
  }

  ExerciseState playing(ExerciseState state) {
    return state.copyWith(
      speechStatus: ExerciseSpeechStatus.playing,
      canPlay: true,
      message: 'Playing pronunciation…',
    );
  }

  ExerciseState failure(ExerciseState state) {
    return state.copyWith(
      speechStatus: ExerciseSpeechStatus.failure,
      canPlay: true,
      message: 'Pronunciation could not play. Rewrite is available below.',
    );
  }
}
