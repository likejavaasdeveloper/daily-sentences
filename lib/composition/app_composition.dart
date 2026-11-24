import 'package:daily_sentences/application/catalog/catalog_repository.dart';
import 'package:daily_sentences/application/catalog/load_catalog.dart';
import 'package:daily_sentences/application/exercise/navigate_sentences.dart';
import 'package:daily_sentences/application/exercise/manage_exercise.dart';
import 'package:daily_sentences/application/sentence/sentence_package_repository.dart';
import 'package:daily_sentences/application/speech/control_speech.dart';
import 'package:daily_sentences/infrastructure/catalog/http_catalog_repository.dart';
import 'package:daily_sentences/infrastructure/sentence/http_sentence_package_repository.dart';
import 'package:daily_sentences/infrastructure/speech/browser_speech_provider.dart';
import 'package:daily_sentences/presentation/catalog_navigation/catalog_navigation_mapper.dart';
import 'package:daily_sentences/presentation/catalog_navigation/catalog_navigation_notifier.dart';
import 'package:daily_sentences/presentation/sentence_navigation/sentence_navigation_mapper.dart';
import 'package:daily_sentences/presentation/sentence_navigation/sentence_navigation_notifier.dart';
import 'package:daily_sentences/presentation/speech/learn_speech_mapper.dart';
import 'package:daily_sentences/presentation/speech/learn_speech_notifier.dart';
import 'package:daily_sentences/presentation/exercise/exercise_mapper.dart';
import 'package:daily_sentences/presentation/exercise/exercise_notifier.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

class ApplicationConfiguration {
  const ApplicationConfiguration.dailySentences()
    : applicationName = 'Daily Sentences';

  final String applicationName;
}

class AppComposition extends StatelessWidget {
  const AppComposition({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApplicationConfiguration>.value(
          value: const ApplicationConfiguration.dailySentences(),
        ),
        Provider<http.Client>(
          create: (_) => http.Client(),
          dispose: (_, client) => client.close(),
        ),
        Provider<CatalogRepository>(
          create: (context) => HttpCatalogRepository(
            client: context.read<http.Client>(),
            catalogUri: catalogUriForBase(Uri.base),
          ),
        ),
        Provider(
          create: (context) => LoadCatalog(context.read<CatalogRepository>()),
        ),
        Provider<SentencePackageRepository>(
          create: (context) => HttpSentencePackageRepository(
            client: context.read<http.Client>(),
            generatedContentUri: generatedContentUriForBase(Uri.base),
          ),
        ),
        Provider(
          create: (context) =>
              NavigateSentences(context.read<SentencePackageRepository>()),
        ),
        Provider<ControlSpeech>(
          create: (_) => ControlSpeech(createBrowserSpeechProvider()),
          dispose: (_, controlSpeech) => controlSpeech.dispose(),
        ),
        Provider(
          create: (context) =>
              ManageExercise(controlSpeech: context.read<ControlSpeech>()),
        ),
        Provider(create: (_) => const CatalogNavigationMapper()),
        Provider(create: (_) => const SentenceNavigationMapper()),
        Provider(create: (_) => const LearnSpeechMapper()),
        Provider(create: (_) => const ExerciseMapper()),
        ChangeNotifierProvider(
          create: (context) => CatalogNavigationNotifier(
            loadCatalog: context.read<LoadCatalog>(),
            mapper: context.read<CatalogNavigationMapper>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => LearnSpeechNotifier(
            controlSpeech: context.read<ControlSpeech>(),
            mapper: context.read<LearnSpeechMapper>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => ExerciseNotifier(
            manageExercise: context.read<ManageExercise>(),
            mapper: context.read<ExerciseMapper>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => SentenceNavigationNotifier(
            navigateSentences: context.read<NavigateSentences>(),
            mapper: context.read<SentenceNavigationMapper>(),
          ),
        ),
      ],
      child: child,
    );
  }
}
