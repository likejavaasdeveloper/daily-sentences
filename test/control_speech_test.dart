import 'dart:async';

import 'package:daily_sentences/application/speech/control_speech.dart';
import 'package:daily_sentences/application/speech/speech_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prefers an exact voice-language match', () {
    const exact = SpeechVoice(id: 'exact', name: 'Exact', language: 'fr-FR');
    const compatible = SpeechVoice(
      id: 'compatible',
      name: 'Compatible',
      language: 'fr-CA',
    );

    expect(selectSuitableVoice('fr-FR', [compatible, exact]), exact);
  });

  test('uses a compatible voice only within the same language', () {
    const compatible = SpeechVoice(
      id: 'compatible',
      name: 'Compatible',
      language: 'fr-CA',
    );
    const unrelated = SpeechVoice(
      id: 'unrelated',
      name: 'Unrelated',
      language: 'de-DE',
    );

    expect(selectSuitableVoice('fr-FR', [unrelated, compatible]), compatible);
    expect(selectSuitableVoice('fa-IR', [unrelated, compatible]), isNull);
    expect(selectSuitableVoice('x-private', [compatible]), isNull);
  });

  test('stops previous playback before starting another request', () async {
    final provider = FakeSpeechProvider(
      voices: [
        const SpeechVoice(id: 'voice', name: 'Voice', language: 'fr-FR'),
      ],
    );
    final useCase = ControlSpeech(provider);

    await useCase.play(text: 'Bonjour', language: 'fr-FR', rate: 1);

    expect(provider.stopCalls, 1);
    expect(provider.requests.single.text, 'Bonjour');
    expect(provider.requests.single.rate, 1);
  });

  test('does not ask an unrelated voice to speak', () {
    final provider = FakeSpeechProvider(
      voices: [
        const SpeechVoice(id: 'voice', name: 'Voice', language: 'de-DE'),
      ],
    );
    final useCase = ControlSpeech(provider);

    expect(
      useCase.play(text: 'Bonjour', language: 'fr-FR', rate: 1),
      throwsA(isA<SpeechPlaybackException>()),
    );
    expect(provider.requests, isEmpty);
  });
}

class FakeSpeechProvider implements SpeechProvider {
  FakeSpeechProvider({required this.voices, this.isSupported = true});

  @override
  final bool isSupported;

  @override
  final List<SpeechVoice> voices;

  final List<SpeechRequest> requests = [];
  int stopCalls = 0;

  @override
  Stream<List<SpeechVoice>> get voicesChanged => const Stream.empty();

  @override
  Future<void> speak(SpeechRequest request) async {
    requests.add(request);
  }

  @override
  void stop() => stopCalls++;

  @override
  void dispose() {}
}
