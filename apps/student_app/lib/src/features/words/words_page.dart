import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/student_providers.dart';
import '../common/page_parts.dart';

class StudentWordsPage extends ConsumerStatefulWidget {
  const StudentWordsPage({super.key});

  @override
  ConsumerState<StudentWordsPage> createState() => _StudentWordsPageState();
}

class _StudentWordsPageState extends ConsumerState<StudentWordsPage> {
  late final TextEditingController _searchController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accessContext = ref.watch(studentAccessProvider);
    final packProgress = ref.watch(studentPackProgressProvider);
    final packs = ref.watch(studentPacksProvider);
    final words = ref.watch(studentWordsProvider);
    final wordProgress = ref.watch(studentWordProgressProvider).valueOrNull;

    final studiedWordCount =
        wordProgress?.values.where((item) => item.seenCount > 0).length ?? 0;
    final totalWords = words.valueOrNull?.length ?? 0;

    return StudentShellFrame(
      destination: StudentDestination.words,
      title: 'Kelimeler',
      subtitle:
          'Kelime hazineni büyüt, ardından flashcard ve mini test ile pekiştir.',
      accessContext: accessContext,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StudentSearchField(
            controller: _searchController,
            hintText: 'Kelime havuzunda veya sözlükte ara...',
            onChanged: (value) {
              setState(() {
                _query = value.trim().toLowerCase();
              });
            },
          ),
          const SizedBox(height: 24),
          _StudySummaryRow(
            studiedWordCount: studiedWordCount,
            totalWords: totalWords,
            reviewCount: ref.watch(studentReviewWordCountProvider),
          ),
          const SizedBox(height: 24),
          const StudentSectionTitle(title: 'Çalışma Merkezi'),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= AppBreakpoints.tablet;
              final flashcardCard = _StudyActionCard(
                title: 'Flashcard Çalışması',
                subtitle: 'Zayıf kelimelerden başlayarak hızlı tekrar yap.',
                buttonLabel: 'Flashcard Aç',
                icon: Icons.style_rounded,
                accentColor: AppThemeTokens.of(context).accentBlue,
                onPressed: () => context.go('/words/flashcards'),
              );
              final testCard = _StudyActionCard(
                title: 'Mini Test',
                subtitle: 'Kısa çoktan seçmeli tur ile ilerlemeyi ölç.',
                buttonLabel: 'Mini Test Başlat',
                icon: Icons.quiz_outlined,
                accentColor: AppThemeTokens.of(context).badgeOrange,
                onPressed: () => context.go('/words/tests'),
              );

              if (!isWide) {
                return Column(
                  children: [
                    flashcardCard,
                    const SizedBox(height: 14),
                    testCard,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: flashcardCard),
                  const SizedBox(width: 16),
                  Expanded(child: testCard),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          const StudentSectionTitle(title: 'Kelime Paketleri'),
          const SizedBox(height: 18),
          packs.when(
            data: (items) {
              final filtered = items
                  .where((item) => item.name.toLowerCase().contains(_query))
                  .toList(growable: false);

              if (filtered.isEmpty) {
                return StudentSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Eşleşen paket bulunamadı',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Arama filtresini temizleyip tekrar dene.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final columns =
                      constraints.maxWidth >= AppBreakpoints.gridWide
                      ? 3
                      : constraints.maxWidth >= AppBreakpoints.small
                      ? 2
                      : 1;
                  final spacing = 18.0;
                  final itemWidth =
                      (constraints.maxWidth - ((columns - 1) * spacing)) /
                      columns;

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      for (var index = 0; index < filtered.length; index++)
                        SizedBox(
                          width: itemWidth,
                          child: StudentPackCard(
                            title: filtered[index].name,
                            wordCount: filtered[index].wordCount,
                            progressPercent:
                                packProgress[filtered[index].id] ?? 0,
                            accentColor: _packAccentColor(context, index),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Text(error.toString()),
          ),
        ],
      ),
    );
  }

  Color _packAccentColor(BuildContext context, int index) {
    final tokens = AppThemeTokens.of(context);
    final palette = <Color>[
      tokens.accentBlue,
      tokens.purple,
      tokens.green,
      tokens.warning,
      tokens.pink,
      const Color(0xFFA855F7),
    ];

    return palette[index % palette.length];
  }
}

class _StudySummaryRow extends StatelessWidget {
  const _StudySummaryRow({
    required this.studiedWordCount,
    required this.totalWords,
    required this.reviewCount,
  });

  final int studiedWordCount;
  final int totalWords;
  final int reviewCount;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final items = <({String label, String value, Color color})>[
      (
        label: 'Çalışılan',
        value: '$studiedWordCount',
        color: tokens.accentBlue,
      ),
      (label: 'Toplam', value: '$totalWords', color: tokens.accent),
      (label: 'Tekrar', value: '$reviewCount', color: tokens.badgeOrange),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyLarge,
                children: [
                  TextSpan(
                    text: '${item.value} ',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: item.color),
                  ),
                  TextSpan(
                    text: item.label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: tokens.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _StudyActionCard extends StatelessWidget {
  const _StudyActionCard({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.icon,
    required this.accentColor,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final String buttonLabel;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return StudentSurfaceCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 18),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 20),
          FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
        ],
      ),
    );
  }
}
