import 'dart:async';

import 'package:daily_sentences/application/exercise/manage_exercise.dart';
import 'package:daily_sentences/application/speech/control_speech.dart';
import 'package:daily_sentences/application/speech/speech_provider.dart';
import 'package:daily_sentences/presentation/exercise/exercise_mapper.dart';
import 'package:daily_sentences/presentation/exercise/exercise_notifier.dart';
import 'package:daily_sentences/presentation/exercise/exercise_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unsupported speech immediately switches to Rewrite', () async {
    final provider = _FakeSpeechProvider(isSupported: false);
    final notifier = _notifier(provider);
    notifier.loadSentence(text: 'Bonjour', language: 'fr-FR');

    notifier.openExercise();
    await _eventsComplete();

    expect(notifier.state.mode, ExerciseMode.rewrite);
  });

  test('no compatible voice switches to Rewrite after five seconds', () async {
    final provider = _FakeSpeechProvider();
    final notifier = _notifier(provider);
    notifier.loadSentence(text: 'Bonjour', language: 'fr-FR');

    notifier.openExercise();
    await _eventsComplete();
    expect(notifier.state.mode, ExerciseMode.dictation);

    await Future<void>.delayed(const Duration(seconds: 5));
    expect(notifier.state.mode, ExerciseMode.rewrite);
  });

  test(
    'compatible voice enables Dictation and late changes stay in Rewrite',
    () async {
      final provider = _FakeSpeechProvider();
      final notifier = _notifier(provider);
      notifier.loadSentence(text: 'Bonjour', language: 'fr-FR');
      notifier.openExercise();
      await _eventsComplete();

      provider.emitVoices([_frenchVoice]);
      await _eventsComplete();
      expect(notifier.state.mode, ExerciseMode.dictation);
      expect(notifier.state.canPlay, isTrue);

      notifier.updateAnswer('preserved');
      notifier.openExercise();
      provider.emitVoices([]);
      await _eventsComplete();
      expect(notifier.state.mode, ExerciseMode.rewrite);
      expect(notifier.state.enteredAnswer, 'preserved');
    },
  );

  test('playback failure switches to Rewrite and preserves text', () async {
    final provider = _FakeSpeechProvider(
      voices: [_frenchVoice],
      playbackResults: [const SpeechPlaybackException('failed')],
    );
    final notifier = _notifier(provider);
    notifier.loadSentence(text: 'Bonjour', language: 'fr-FR');
    notifier.openExercise();
    await _eventsComplete();
    notifier.updateAnswer('my answer');

    await notifier.play();

    expect(notifier.state.mode, ExerciseMode.rewrite);
    expect(notifier.state.enteredAnswer, 'my answer');
  });

  test('intentional cancellation does not switch to Rewrite', () async {
    final playback = Completer<void>();
    final provider = _FakeSpeechProvider(
      voices: [_frenchVoice],
      playbackResults: [playback.future],
    );
    final notifier = _notifier(provider);
    notifier.loadSentence(text: 'Bonjour', language: 'fr-FR');
    notifier.openExercise();
    await _eventsComplete();
    final play = notifier.play();
    await _eventsComplete();

    notifier.selectLearn();
    playback.completeError(const SpeechPlaybackCancelled());
    await play;

    expect(notifier.state.mode, ExerciseMode.learn);
  });

  test('new sentence resets answer, reveal, and exercise mode', () async {
    final provider = _FakeSpeechProvider(isSupported: false);
    final notifier = _notifier(provider);
    notifier.loadSentence(text: 'Old', language: 'fr-FR');
    notifier.openExercise();
    await _eventsComplete();
    notifier.updateAnswer('old answer');
    notifier.revealAnswer();

    notifier.loadSentence(text: 'New', language: 'fr-FR');

    expect(notifier.state.mode, ExerciseMode.learn);
    expect(notifier.state.enteredAnswer, isEmpty);
    expect(notifier.state.isAnswerRevealed, isFalse);
  });

  test(
    'answer comparison is non-punitive and ignores ordinary punctuation',
    () {
      final provider = _FakeSpeechProvider();
      final notifier = _notifier(provider);
      notifier.loadSentence(text: 'Bonjour monde', language: 'fr-FR');
      notifier.updateAnswer('  BONJOUR, monde!  ');

      notifier.checkAnswer();

      expect(notifier.state.feedback, contains('matches'));
    },
  );

  test('reveal does not change the entered answer', () {
    final provider = _FakeSpeechProvider();
    final notifier = _notifier(provider);
    notifier.loadSentence(text: 'Bonjour', language: 'fr-FR');
    notifier.updateAnswer('Bounjour');

    notifier.revealAnswer();

    expect(notifier.state.isAnswerRevealed, isTrue);
    expect(notifier.state.enteredAnswer, 'Bounjour');
  });
}

const _frenchVoice = SpeechVoice(
  id: 'fr',
  name: 'French voice',
  language: 'fr-FR',
);

ExerciseNotifier _notifier(_FakeSpeechProvider provider) {
  return ExerciseNotifier(
    manageExercise: ManageExercise(controlSpeech: ControlSpeech(provider)),
    mapper: const ExerciseMapper(),
  );
}

Future<void> _eventsComplete() => Future<void>.delayed(Duration.zero);

class _FakeSpeechProvider implements SpeechProvider {
  _FakeSpeechProvider({
    List<SpeechVoice>? voices,
    this.isSupported = true,
    List<Object>? playbackResults,
  }) : _voices = voices ?? [],
       _playbackResults = playbackResults ?? [];

  final StreamController<List<SpeechVoice>> _voiceChanges =
      StreamController.broadcast(sync: true);
  final List<Object> _playbackResults;
  List<SpeechVoice> _voices;

  @override
  final bool isSupported;

  @override
  List<SpeechVoice> get voices => List.unmodifiable(_voices);

  @override
  Stream<List<SpeechVoice>> get voicesChanged => _voiceChanges.stream;

  void emitVoices(List<SpeechVoice> voices) {
    _voices = voices;
    _voiceChanges.add(List.unmodifiable(voices));
  }

  @override
  Future<void> speak(SpeechRequest request) {
    if (_playbackResults.isEmpty) {
      return Future<void>.value();
    }
    final result = _playbackResults.removeAt(0);
    if (result is Future<void>) {
      return result;
    }
    return Future<void>.error(result);
  }

  @override
  void stop() {}

  @override
  void dispose() {
    _voiceChanges.close();
  }
}
