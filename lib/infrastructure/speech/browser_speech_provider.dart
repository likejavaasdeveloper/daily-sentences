import 'package:daily_sentences/application/speech/speech_provider.dart';
import 'package:daily_sentences/infrastructure/speech/browser_speech_provider_stub.dart'
    if (dart.library.js_interop) 'package:daily_sentences/infrastructure/speech/browser_speech_provider_web.dart';

SpeechProvider createBrowserSpeechProvider() => createSpeechProvider();
