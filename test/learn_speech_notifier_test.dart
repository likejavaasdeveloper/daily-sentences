import 'dart:async';

import 'package:daily_sentences/application/speech/control_speech.dart';
import 'package:daily_sentences/application/speech/speech_provider.dart';
import 'package:daily_sentences/presentation/speech/learn_speech_mapper.dart';
import 'package:daily_sentences/presentation/speech/learn_speech_notifier.dart';
import 'package:daily_sentences/presentation/speech/learn_speech_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'discovers voices without autoplay and accepts later availability',
    () async {
      final provider = _FakeSpeechProvider();
      final notifier = _notifier(provider);

      notifier.loadSentence(text: 'Bonjour', language: 'fr-FR');
      await _eventsComplete();

      expect(notifier.state.status, LearnSpeechStatus.unavailable);
      expect(provider.requests, isEmpty);
      provider.emitVoices([_frenchVoice]);
      await _eventsComplete();
      expect(notifier.state.status, LearnSpeechStatus.ready);
      expect(provider.requests, isEmpty);
    },
  );

  test('reports an unsupported browser without blocking text state', () async {
    final provider = _FakeSpeechProvider(isSupported: false);
    final notifier = _notifier(provider);

    notifier.loadSentence(text: 'Bonjour', language: 'fr-FR');
    await _eventsComplete();

    expect(notifier.state.status, LearnSpeechStatus.unavailable);
    expect(notifier.state.canPlay, isFalse);
    expect(notifier.state.message, contains('not supported'));
  });

  test('plays only on request using normal then adjusted speed', () async {
    final provider = _FakeSpeechProvider(voices: [_frenchVoice]);
    final notifier = _notifier(provider);
    notifier.loadSentence(text: 'Bonjour', language: 'fr-FR');
    await _eventsComplete();

    expect(notifier.state.rate, 1);
    expect(provider.requests, isEmpty);
    await notifier.play();
    notifier.setRate(0.8);
    await notifier.play();

    expect(provider.requests.map((request) => request.rate), [1, 0.8]);
    expect(
      provider.requests.every((request) => request.text == 'Bonjour'),
      isTrue,
    );
  });

  test('speech failure remains retryable and isolated', () async {
    final provider = _FakeSpeechProvider(
      voices: [_frenchVoice],
      playbackResults: [
        const SpeechPlaybackException('synthesis failed'),
        Future<void>.value(),
      ],
    );
    final notifier = _notifier(provider);
    notifier.loadSentence(text: 'Bonjour', language: 'fr-FR');
    await _eventsComplete();

    await notifier.play();
    expect(notifier.state.status, LearnSpeechStatus.failure);
    expect(notifier.state.canPlay, isTrue);
    await notifier.play();
    expect(notifier.state.status, LearnSpeechStatus.ready);
  });

  test(
    'sentence change cancels playback and ignores its stale completion',
    () async {
      final stalePlayback = Completer<void>();
      final provider = _FakeSpeechProvider(
        voices: [_frenchVoice],
        playbackResults: [stalePlayback.future],
      );
      final notifier = _notifier(provider);
      notifier.loadSentence(text: 'Old', language: 'fr-FR');
      await _eventsComplete();
      final oldPlay = notifier.play();
      await _eventsComplete();

      notifier.loadSentence(text: 'New', language: 'fr-FR');
      await _eventsComplete();
      stalePlayback.completeError(
        const SpeechPlaybackException('late failure'),
      );
      await oldPlay;

      expect(notifier.state.status, LearnSpeechStatus.ready);
      expect(provider.stopCalls, greaterThanOrEqualTo(2));
    },
  );

  test('repeated playback makes the newest callback authoritative', () async {
    final firstPlayback = Completer<void>();
    final secondPlayback = Completer<void>();
    final provider = _FakeSpeechProvider(
      voices: [_frenchVoice],
      playbackResults: [firstPlayback.future, secondPlayback.future],
    );
    final notifier = _notifier(provider);
    notifier.loadSentence(text: 'Bonjour', language: 'fr-FR');
    await _eventsComplete();
    final first = notifier.play();
    final second = notifier.play();

    secondPlayback.complete();
    await second;
    firstPlayback.completeError(const SpeechPlaybackException('stale failure'));
    await first;

    expect(notifier.state.status, LearnSpeechStatus.ready);
    expect(provider.requests.length, 2);
  });

  test(
    'clear and dispose stop playback and release voice observation',
    () async {
      final provider = _FakeSpeechProvider(voices: [_frenchVoice]);
      final notifier = _notifier(provider);
      notifier.loadSentence(text: 'Bonjour', language: 'fr-FR');
      await _eventsComplete();

      notifier.clearSentence();
      expect(notifier.state.status, LearnSpeechStatus.unavailable);
      final stopsBeforeDispose = provider.stopCalls;
      notifier.dispose();

      expect(provider.stopCalls, stopsBeforeDispose + 1);
    },
  );
}

const _frenchVoice = SpeechVoice(
  id: 'fr',
  name: 'French voice',
  language: 'fr-FR',
);

LearnSpeechNotifier _notifier(_FakeSpeechProvider provider) {
  return LearnSpeechNotifier(
    controlSpeech: ControlSpeech(provider),
    mapper: const LearnSpeechMapper(),
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

  final List<SpeechRequest> requests = [];
  int stopCalls = 0;

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
    requests.add(request);
    if (_playbackResults.isEmpty) {
      return Future.value();
    }
    final result = _playbackResults.removeAt(0);
    if (result is Future<void>) {
      return result;
    }
    return Future<void>.error(result);
  }

  @override
  void stop() => stopCalls++;

  @override
  void dispose() {
    _voiceChanges.close();
  }
}
