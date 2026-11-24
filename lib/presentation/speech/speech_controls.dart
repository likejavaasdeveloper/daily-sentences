import 'package:daily_sentences/presentation/exercise/exercise_notifier.dart';
import 'package:daily_sentences/presentation/exercise/exercise_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SpeechControls extends StatelessWidget {
  const SpeechControls({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ExerciseNotifier>().state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Pronunciation speed: ${state.rate.toStringAsFixed(1)}×'),
        Slider(
          value: state.rate,
          min: 0.5,
          max: 1.5,
          divisions: 10,
          onChanged: context.read<ExerciseNotifier>().setRate,
        ),
        FilledButton.icon(
          onPressed: state.canPlay
              ? context.read<ExerciseNotifier>().play
              : null,
          icon: const Icon(Icons.volume_up),
          label: Text(
            state.speechStatus == ExerciseSpeechStatus.playing
                ? 'Play again'
                : 'Play pronunciation',
          ),
        ),
        if (state.message != null) ...[
          const SizedBox(height: 8),
          Text(state.message!),
        ],
      ],
    );
  }
}
