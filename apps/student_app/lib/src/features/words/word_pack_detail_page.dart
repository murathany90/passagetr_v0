import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/student_providers.dart';
import '../common/page_parts.dart';
import 'flashcards_page.dart';

class StudentWordPackDetailPage extends ConsumerWidget {
  const StudentWordPackDetailPage({super.key, required this.packId});

  final String packId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessContext = ref.watch(studentAccessProvider);
    final packs = ref.watch(studentPacksProvider);
    final words = ref.watch(studentWordsProvider);
    final packProgress = ref.watch(studentPackProgressProvider);

    return StudentDetailFrame(
      destination: StudentDestination.words,
      accessContext: accessContext,
      header: WordsStudyHeader(
        title: 'Kelime Paketi',
        subtitle: 'Paketteki kelimeleri incele ve çalışmaya buradan başla.',
        onBack: () => context.go('/words'),
      ),
      body: packs.when(
        data: (packItems) => words.when(
          data: (wordItems) {
            final pack = _resolvePack(packItems);
            if (pack == null) {
              return const StudentSurfaceCard(
                child: Text('Kelime paketi bulunamadi.'),
              );
            }

            final scopedWords = wordItems
                .where((item) => item.packId == packId)
                .toList(growable: false);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StudentPackCard(
                  title: pack.name,
                  wordCount: pack.wordCount,
                  progressPercent: packProgress[packId] ?? 0,
                  accentColor: AppThemeTokens.of(context).accentBlue,
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide =
                        constraints.maxWidth >= AppBreakpoints.tablet;
                    final flashcardCard = _PackActionCard(
                      title: 'Flashcard ile Çalış',
                      subtitle:
                          'Seçili paketteki kelimeler için hızlı tekrar turu aç.',
                      icon: Icons.style_rounded,
                      color: AppThemeTokens.of(context).accentBlue,
                      onPressed: () =>
                          context.go('/words/flashcards?packId=$packId'),
                    );
                    final testCard = _PackActionCard(
                      title: 'Mini Test Başlat',
                      subtitle:
                          'Seçili paketteki kelimeler için kısa ölçme turu aç.',
                      icon: Icons.quiz_outlined,
                      color: AppThemeTokens.of(context).badgeOrange,
                      onPressed: () =>
                          context.go('/words/tests?packId=$packId'),
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
                        const SizedBox(width: 14),
                        Expanded(child: testCard),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                StudentSectionTitle(
                  title: 'Paket Kelimeleri',
                  trailing: Text(
                    '${scopedWords.length} kayıt',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 16),
                if (scopedWords.isEmpty)
                  const StudentSurfaceCard(
                    child: Text('Bu pakette görüntülenecek kelime yok.'),
                  )
                else
                  for (final word in scopedWords) ...[
                    StudentSurfaceCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  word.enWord,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  word.trMeaning,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppThemeTokens.of(
                                context,
                              ).surfaceMuted,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(word.pos),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Text(error.toString()),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Text(error.toString()),
      ),
    );
  }

  ContentPack? _resolvePack(List<ContentPack> items) {
    for (final item in items) {
      if (item.id == packId) {
        return item;
      }
    }

    return null;
  }
}

class _PackActionCard extends StatelessWidget {
  const _PackActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return StudentSurfaceCard(
      onTap: onPressed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
