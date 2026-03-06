import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passagetr/domain/entities/word_level_progress_summary.dart';
import 'package:passagetr/features/words/word_level_hub_page.dart';
import 'package:passagetr/state/word_providers.dart';

void main() {
  testWidgets('shows studied progress text and progress bar for each level',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          wordLevelProgressProvider.overrideWith(
            (Ref ref) async => const <WordLevelProgressSummary>[
              WordLevelProgressSummary(
                level: 'A2',
                wordCount: 20,
                studiedWordCount: 5,
              ),
            ],
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: WordLevelHubPage(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('A2'), findsOneWidget);
    expect(find.textContaining('5/20'), findsOneWidget);

    final LinearProgressIndicator progress = tester.widget(
      find.byType(LinearProgressIndicator),
    );
    expect(progress.value, 0.25);
  });
}
