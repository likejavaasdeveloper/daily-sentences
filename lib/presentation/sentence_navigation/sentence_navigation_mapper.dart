import 'package:daily_sentences/application/exercise/navigate_sentences.dart';
import 'package:daily_sentences/presentation/sentence_navigation/sentence_navigation_state.dart';

class SentenceNavigationMapper {
  const SentenceNavigationMapper();

  SentenceNavigationReady mapPosition(SentencePosition position) {
    return SentenceNavigationReady(
      position: position,
      enteredAnswer: '',
      isAnswerRevealed: false,
    );
  }

  SentenceNavigationFailure mapFailure(Object error) {
    return SentenceNavigationFailure(
      'Sentences could not be loaded. ${error.toString()}',
    );
  }
}
