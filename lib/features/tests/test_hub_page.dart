import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/widgets/app_section_header.dart';
import '../../core/widgets/app_surface_card.dart';
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const AppSectionHeader(title: 'Test Modlari'),
          const SizedBox(height: 10),
          AppSurfaceCard(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => McqSessionPage(
                    pack: pack,
                    questionCount: AppConstants.testTargetQuestionCount,
                    sessionLabel: 'MCQ',
                  ),
                ),
              );
            },
            child: const _ModeTile(
              icon: Icons.radio_button_checked_rounded,
              title: 'MCQ',
              subtitle: 'EN -> TR 10 soru',
            ),
          ),
          const SizedBox(height: 8),
          AppSurfaceCard(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MatchingSessionPage(pack: pack),
                ),
              );
            },
            child: const _ModeTile(
              icon: Icons.link_rounded,
              title: 'Matching',
              subtitle: 'Tiklamali eslestirme',
            ),
          ),
          const SizedBox(height: 8),
          AppSurfaceCard(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TypingSessionPage(pack: pack),
                ),
              );
            },
            child: const _ModeTile(
              icon: Icons.keyboard_alt_outlined,
              title: 'Typing',
              subtitle: 'TR -> EN exact match',
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        CircleAvatar(
          radius: 20,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded),
      ],
    );
  }
}
