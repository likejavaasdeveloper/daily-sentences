import 'package:daily_sentences/application/exercise/navigate_sentences.dart';
import 'package:daily_sentences/presentation/catalog_navigation/catalog_navigation_notifier.dart';
import 'package:daily_sentences/presentation/catalog_navigation/catalog_navigation_state.dart';
import 'package:daily_sentences/presentation/sentence_navigation/sentence_navigation_notifier.dart';
import 'package:daily_sentences/presentation/sentence_navigation/sentence_navigation_state.dart';
import 'package:daily_sentences/presentation/speech/learn_speech_notifier.dart';
import 'package:daily_sentences/presentation/speech/speech_controls.dart';
import 'package:daily_sentences/presentation/exercise/exercise_notifier.dart';
import 'package:daily_sentences/presentation/exercise/exercise_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final SentenceNavigationNotifier _sentenceNavigation;
  late final LearnSpeechNotifier _speech;
  late final ExerciseNotifier _exercise;
  String? _activeSentenceKey;

  @override
  void initState() {
    super.initState();
    _sentenceNavigation = context.read<SentenceNavigationNotifier>();
    _speech = context.read<LearnSpeechNotifier>();
    _exercise = context.read<ExerciseNotifier>();
    _sentenceNavigation.addListener(_onSentenceNavigationChanged);
    Future<void>.microtask(context.read<CatalogNavigationNotifier>().load);
  }

  void _onSentenceNavigationChanged() {
    final state = _sentenceNavigation.state;
    if (state is! SentenceNavigationReady) {
      if (_activeSentenceKey != null) {
        _activeSentenceKey = null;
        _speech.clearSentence();
        _exercise.clearSentence();
      }
      return;
    }
    final position = state.position;
    final key =
        '${position.selection.contentVersion}\u0000'
        '${position.selection.language}\u0000${position.selection.category}\u0000'
        '${position.packageIndex}\u0000${position.sentenceIndex}';
    if (key == _activeSentenceKey) {
      return;
    }
    _activeSentenceKey = key;
    _speech.loadSentence(
      text: position.sentence.text,
      language: position.selection.language,
    );
    _exercise.loadSentence(
      text: position.sentence.text,
      language: position.selection.language,
    );
  }

  @override
  void dispose() {
    _sentenceNavigation.removeListener(_onSentenceNavigationChanged);
    _speech.clearSentence(notify: false);
    _exercise.clearSentence(notify: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CatalogNavigationNotifier>().state;
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Sentences')),
      body: switch (state) {
        CatalogLoading() => const Center(child: CircularProgressIndicator()),
        CatalogEmpty() => const Center(
          child: Text('No sentences are available yet.'),
        ),
        CatalogFailure(:final message) => _FailureView(message: message),
        CatalogReady() => _CatalogView(state: state),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: context.read<CatalogNavigationNotifier>().load,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _CatalogView extends StatelessWidget {
  const _CatalogView({required this.state});

  final CatalogReady state;

  @override
  Widget build(BuildContext context) {
    final selected = state.languages.where(
      (item) => item.code == state.selectedLanguage,
    );
    final selectedLanguage = selected.isEmpty ? null : selected.first;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Languages'),
        ...state.languages.map(
          (language) => ListTile(
            title: Text(language.code),
            subtitle: Text('${language.sentenceCount} sentences'),
            selected: language.code == state.selectedLanguage,
            onTap: () {
              if (language.code != state.selectedLanguage) {
                context.read<SentenceNavigationNotifier>().clearSelection();
              }
              context.read<CatalogNavigationNotifier>().selectLanguage(
                language.code,
              );
            },
          ),
        ),
        if (selectedLanguage != null) ...[
          const SizedBox(height: 16),
          Text('${selectedLanguage.code} categories'),
          ...selectedLanguage.categories.map(
            (category) => ListTile(
              title: Text(category.code),
              subtitle: Text('${category.sentenceCount} sentences'),
              selected: category.code == state.selectedCategory,
              onTap: () {
                context.read<CatalogNavigationNotifier>().selectCategory(
                  selectedLanguage.code,
                  category.code,
                );
                context.read<SentenceNavigationNotifier>().loadSelection(
                  SentenceSelection(
                    contentVersion: state.contentVersion,
                    language: selectedLanguage.code,
                    category: category.code,
                    packages: category.packages,
                  ),
                );
              },
            ),
          ),
          if (state.selectedCategory != null) ...[
            const SizedBox(height: 16),
            const _SentenceStatus(),
          ],
        ],
      ],
    );
  }
}

class _SentenceStatus extends StatelessWidget {
  const _SentenceStatus();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SentenceNavigationNotifier>().state;
    return switch (state) {
      SentenceNavigationLoading() => const Center(
        child: CircularProgressIndicator(),
      ),
      SentenceNavigationFailure(:final message) => Column(
        children: [
          Text(message),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: context.read<SentenceNavigationNotifier>().retry,
            child: const Text('Retry sentences'),
          ),
        ],
      ),
      SentenceNavigationReady(:final position) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _ExerciseTabs(),
          const SizedBox(height: 12),
          _ExerciseContent(position: position),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: position.hasNext
                ? context.read<SentenceNavigationNotifier>().moveNext
                : null,
            child: const Text('Next sentence'),
          ),
        ],
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _ExerciseTabs extends StatelessWidget {
  const _ExerciseTabs();

  @override
  Widget build(BuildContext context) {
    final exercise = context.watch<ExerciseNotifier>();
    final mode = exercise.state.mode;
    return Row(
      children: [
        Expanded(
          child: ChoiceChip(
            label: const Text('Learn'),
            selected: mode == ExerciseMode.learn,
            onSelected: (_) => exercise.selectLearn(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ChoiceChip(
            label: Text(mode == ExerciseMode.rewrite ? 'Rewrite' : 'Dictation'),
            selected:
                mode == ExerciseMode.dictation || mode == ExerciseMode.rewrite,
            onSelected: (_) => exercise.openExercise(),
          ),
        ),
      ],
    );
  }
}

class _ExerciseContent extends StatelessWidget {
  const _ExerciseContent({required this.position});

  final SentencePosition position;

  @override
  Widget build(BuildContext context) {
    final exercise = context.watch<ExerciseNotifier>();
    final state = exercise.state;
    if (state.mode == ExerciseMode.learn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            position.sentence.text,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(position.sentence.translation),
          if (position.sentence.usages.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Usage'),
            ...position.sentence.usages.map(Text.new),
          ],
          const SizedBox(height: 16),
          const SpeechControls(),
        ],
      );
    }
    if (state.mode == ExerciseMode.dictation) {
      return _DictationContent(
        position: position,
        exercise: exercise,
        state: state,
      );
    }
    return _RewriteContent(
      position: position,
      exercise: exercise,
      state: state,
    );
  }
}

class _DictationContent extends StatelessWidget {
  const _DictationContent({
    required this.position,
    required this.exercise,
    required this.state,
  });

  final SentencePosition position;
  final ExerciseNotifier exercise;
  final ExerciseState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Listen and write the sentence.'),
        const SizedBox(height: 12),
        const SpeechControls(),
        const SizedBox(height: 12),
        if (state.isAnswerRevealed) ...[
          Text(
            position.sentence.text,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
        ],
        _AnswerField(
          key: const Key('exercise-answer'),
          initialValue: state.enteredAnswer,
          label: 'Your answer',
          onChanged: exercise.updateAnswer,
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: exercise.checkAnswer,
          child: const Text('Check answer'),
        ),
        TextButton(
          onPressed: exercise.revealAnswer,
          child: const Text('Reveal original'),
        ),
        if (state.feedback != null) Text(state.feedback!),
      ],
    );
  }
}

class _RewriteContent extends StatelessWidget {
  const _RewriteContent({
    required this.position,
    required this.exercise,
    required this.state,
  });

  final SentencePosition position;
  final ExerciseNotifier exercise;
  final ExerciseState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          position.sentence.text,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        _AnswerField(
          key: const Key('exercise-answer'),
          initialValue: state.enteredAnswer,
          label: 'Rewrite the sentence',
          onChanged: exercise.updateAnswer,
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: exercise.checkAnswer,
          child: const Text('Check answer'),
        ),
        if (state.feedback != null) Text(state.feedback!),
      ],
    );
  }
}

class _AnswerField extends StatefulWidget {
  const _AnswerField({
    super.key,
    required this.initialValue,
    required this.label,
    required this.onChanged,
  });

  final String initialValue;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  State<_AnswerField> createState() => _AnswerFieldState();
}

class _AnswerFieldState extends State<_AnswerField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant _AnswerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.initialValue,
        selection: TextSelection.collapsed(offset: widget.initialValue.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
      ),
      onChanged: widget.onChanged,
    );
  }
}
