enum ExerciseMode { learn, dictation, rewrite }

enum ExerciseSpeechStatus { discovering, unavailable, ready, playing, failure }

class ExerciseState {
  const ExerciseState({
    required this.mode,
    required this.speechStatus,
    required this.enteredAnswer,
    required this.isAnswerRevealed,
    required this.rate,
    required this.canPlay,
    this.feedback,
    this.message,
  });

  const ExerciseState.learn()
    : mode = ExerciseMode.learn,
      speechStatus = ExerciseSpeechStatus.unavailable,
      enteredAnswer = '',
      isAnswerRevealed = false,
      rate = 1,
      canPlay = false,
      feedback = null,
      message = null;

  final ExerciseMode mode;
  final ExerciseSpeechStatus speechStatus;
  final String enteredAnswer;
  final bool isAnswerRevealed;
  final double rate;
  final bool canPlay;
  final String? feedback;
  final String? message;

  ExerciseState copyWith({
    ExerciseMode? mode,
    ExerciseSpeechStatus? speechStatus,
    String? enteredAnswer,
    bool? isAnswerRevealed,
    double? rate,
    bool? canPlay,
    String? feedback,
    String? message,
  }) {
    return ExerciseState(
      mode: mode ?? this.mode,
      speechStatus: speechStatus ?? this.speechStatus,
      enteredAnswer: enteredAnswer ?? this.enteredAnswer,
      isAnswerRevealed: isAnswerRevealed ?? this.isAnswerRevealed,
      rate: rate ?? this.rate,
      canPlay: canPlay ?? this.canPlay,
      feedback: feedback,
      message: message,
    );
  }
}
