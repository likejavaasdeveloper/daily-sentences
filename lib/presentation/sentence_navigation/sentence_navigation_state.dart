import 'package:daily_sentences/application/exercise/navigate_sentences.dart';

class SentenceNavigationState {
  const SentenceNavigationState();
}

class SentenceNavigationIdle extends SentenceNavigationState {
  const SentenceNavigationIdle();
}

class SentenceNavigationLoading extends SentenceNavigationState {
  const SentenceNavigationLoading();
}

class SentenceNavigationReady extends SentenceNavigationState {
  const SentenceNavigationReady({
    required this.position,
    required this.enteredAnswer,
    required this.isAnswerRevealed,
  });

  final SentencePosition position;
  final String enteredAnswer;
  final bool isAnswerRevealed;

  SentenceNavigationReady withAnswer(String answer) {
    return SentenceNavigationReady(
      position: position,
      enteredAnswer: answer,
      isAnswerRevealed: isAnswerRevealed,
    );
  }

  SentenceNavigationReady revealAnswer() {
    return SentenceNavigationReady(
      position: position,
      enteredAnswer: enteredAnswer,
      isAnswerRevealed: true,
    );
  }
}

class SentenceNavigationFailure extends SentenceNavigationState {
  const SentenceNavigationFailure(this.message);

  final String message;
}
