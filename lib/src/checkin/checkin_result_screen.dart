// checkin_result_screen.dart
import 'package:flutter/material.dart';

import '../suggestions/suggestions_screen.dart';
import '../utils/app_copy.dart';
import '../utils/state_tag_formatter.dart';
import '../utils/mood_emoji.dart';

import 'checkin_models.dart';

class CheckInResultScreen extends StatelessWidget {
  final String checkinId;
  final CheckInInput input;

  const CheckInResultScreen({
    super.key,
    required this.checkinId,
    required this.input,
  });

  /// 0..10 buckets used across the app
  String _levelLabel010(int v) {
    final x = v.clamp(0, 10);
    if (x <= 3) return 'low';
    if (x <= 6) return 'mid';
    return 'high';
  }

  String _driversLine() {
    final drivers = input.drivers;
    if (drivers.isEmpty) return 'Drivers: ${AppCopy.driversNone}';
    return 'Drivers: ${drivers.take(3).join(", ")}';
  }

  String _oneLineSummary() {
    final mood = input.primaryMood.label;
    final intensity = _levelLabel010(input.intensity);
    final energy = _levelLabel010(input.energy);
    final tension = _levelLabel010(input.tension);

    return 'You’re feeling $mood — with $intensity intensity, $energy energy, and $tension tension.';
  }

  @override
  Widget build(BuildContext context) {
    final moodLabel = input.primaryMood.label;
    final emoji = emojiForMood(input.primaryMood.name);
    final stateText = formatStateTag(input.computeStateTag());

    return Scaffold(
      appBar: AppBar(title: const Text(AppCopy.resultTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$emoji  $moodLabel',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      stateText,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _oneLineSummary(),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _driversLine(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Pill(
                          label:
                              '${AppCopy.intensityLabel}: ${input.intensity}/10 (${_levelLabel010(input.intensity)})',
                        ),
                        _Pill(
                          label:
                              '${AppCopy.energyLabel}: ${input.energy}/10 (${_levelLabel010(input.energy)})',
                        ),
                        _Pill(
                          label:
                              '${AppCopy.tensionLabel}: ${input.tension}/10 (${_levelLabel010(input.tension)})',
                        ),
                      ],
                    ),
                    if (input.selfHarmThoughts) ...[
                      const SizedBox(height: 12),
                      const Text(
                        AppCopy.safetyEnabled,
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.lightbulb),
              label: const Text(AppCopy.getSuggestions),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        SuggestionsScreen(input: input, checkinId: checkinId),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              child: const Text(AppCopy.backToHome),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  const _Pill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
