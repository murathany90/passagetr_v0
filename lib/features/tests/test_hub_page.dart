import 'package:flutter/material.dart';

import '../../domain/entities/pack.dart';
import 'matching_session_page.dart';
import 'mcq_session_page.dart';
import 'typing_session_page.dart';

class TestHubPage extends StatelessWidget {
  const TestHubPage({required this.pack, super.key});

  final Pack pack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Hub')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => McqSessionPage(pack: pack),
                  ),
                );
              },
              child: const Text('MCQ (EN -> TR)'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MatchingSessionPage(pack: pack),
                  ),
                );
              },
              child: const Text('Matching'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TypingSessionPage(pack: pack),
                  ),
                );
              },
              child: const Text('Typing (TR -> EN)'),
            ),
          ],
        ),
      ),
    );
  }
}
