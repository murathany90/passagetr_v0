import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_surface_card.dart';
import '../../../state/tts_providers.dart';

class ReadingAudioSettingsSheet extends ConsumerWidget {
  const ReadingAudioSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ReadingAudioPreferences prefs = ref.watch(
      readingAudioPreferencesProvider,
    );
    final ReadingAudioPreferencesNotifier notifier = ref.read(
      readingAudioPreferencesProvider.notifier,
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Okuma Ses Ayarlari',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            AppSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Ses hizi',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <double>[0.5, 1.0, 1.25, 1.5]
                        .map(
                          (double speed) => ChoiceChip(
                            label: Text(
                                'x${speed.toStringAsFixed(speed == 1.0 ? 0 : 2).replaceAll('.00', '')}'),
                            selected: prefs.speechRate == speed,
                            onSelected: (_) => notifier.setSpeechRate(speed),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            AppSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Kelime bilgi kontrol sikligi',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: WordInfoFrequency.values
                        .map(
                          (WordInfoFrequency frequency) => ChoiceChip(
                            label: Text(frequency.label),
                            selected: prefs.wordInfoFrequency == frequency,
                            onSelected: (_) =>
                                notifier.setWordInfoFrequency(frequency),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            AppSurfaceCard(
              child: SwitchListTile.adaptive(
                value: prefs.stopOnInteraction,
                onChanged: notifier.setStopOnInteraction,
                title: const Text('Kelimeye dokununca sesi durdur'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
