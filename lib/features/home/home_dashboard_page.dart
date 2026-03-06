import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_error_state.dart';
import '../../core/widgets/app_gradient_cta_button.dart';
import '../../core/widgets/app_shimmer_block.dart';
import '../../core/widgets/app_section_header.dart';
import '../../core/widgets/app_surface_card.dart';
import '../../domain/entities/home_dashboard_data.dart';
import '../../domain/entities/pack.dart';
import '../../domain/entities/reading_resume_item.dart';
import '../../state/providers.dart';
import '../flashcard/flashcard_session_page.dart';
import '../readings/reading_detail_page.dart';

class HomeDashboardPage extends ConsumerStatefulWidget {
  const HomeDashboardPage({super.key});

  @override
  ConsumerState<HomeDashboardPage> createState() => _HomeDashboardPageState();
}

class _HomeDashboardPageState extends ConsumerState<HomeDashboardPage> {
  Future<void> _onQuickStart(HomeDashboardData data) async {
    final QuickStartSuggestion quickStart = data.quickStart;
    if (!quickStart.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hizli basla icin uygun icerik bulunamadi.'),
        ),
      );
      return;
    }

    bool shouldRefresh = false;

    switch (quickStart.type) {
      case QuickStartType.resumeReading:
        final ReadingResumeItem? resumeItem = quickStart.resumeItem;
        final Pack? pack = quickStart.pack;
        if (resumeItem == null || pack == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Yarim kalan okuma acilamadi.')),
          );
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ReadingDetailPage(
              passage: resumeItem.passage,
              pack: pack,
              initialLastIdx: resumeItem.progress.lastIdx,
            ),
          ),
        );
        shouldRefresh = true;
        break;
      case QuickStartType.weakWords:
      case QuickStartType.randomWords:
        final Pack? pack = quickStart.pack;
        final List<String> ids = quickStart.wordIds;
        if (pack == null || ids.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Hizli basla icin kelime bulunamadi.'),
            ),
          );
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => FlashcardSessionPage(
              pack: pack,
              customWordIds: ids,
              sessionLabel: 'Hizli Basla',
            ),
          ),
        );
        shouldRefresh = true;
        break;
      case QuickStartType.unavailable:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hizli basla hazir degil.')),
        );
        break;
    }

    if (mounted && shouldRefresh) {
      ref.invalidate(homeDashboardProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<HomeDashboardData> dashboard = ref.watch(
      homeDashboardProvider,
    );

    return dashboard.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            AppShimmerCard(lineCount: 4),
            SizedBox(height: 12),
            AppShimmerCard(),
            SizedBox(height: 8),
            AppShimmerCard(),
          ],
        ),
      ),
      error: (Object error, StackTrace stack) {
        return AppErrorState(
          title: 'Ana sayfa verisi yuklenemedi.',
          detail: _friendlyHomeError(error),
          onRetry: () => ref.invalidate(homeDashboardProvider),
        );
      },
      data: (HomeDashboardData data) {
        final String quickStartTitle = switch (data.quickStart.type) {
          QuickStartType.resumeReading => 'Okumaya devam et',
          QuickStartType.weakWords => 'Zorlandığın kelimeler',
          QuickStartType.randomWords => 'Rastgele flashcard',
          QuickStartType.unavailable => 'Şu an öneri yok',
        };

        return RefreshIndicator(
          onRefresh: () async {
            await ref
                .read(offlineSyncControllerProvider.notifier)
                .flushPending(silent: true);
            ref.invalidate(homeDashboardProvider);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              AppSurfaceCard(
                variant: AppSurfaceVariant.feature,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Bugünkü Eğitim',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Reading is Power. Günlük hedefini odaklı bir oturumla sürdür.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 14),
                    _CompletionRing(
                      value: _todayCompletionValue(data),
                      words: data.todayWordCount,
                      readCount: data.todayReadSentenceCount,
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .secondaryContainer
                            .withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Sıradaki adım: $quickStartTitle',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer,
                            ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppGradientCtaButton(
                      label: 'Hızlı Başla',
                      icon: Icons.play_arrow_rounded,
                      enabled: data.quickStart.isAvailable,
                      onTap: () => _onQuickStart(data),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const AppSectionHeader(title: 'Günlük Metrikler'),
              const SizedBox(height: 8),
              AppSurfaceCard(
                variant: AppSurfaceVariant.grouped,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: <Widget>[
                    _MetricRow(
                      label: 'Bugün görülen kelime',
                      value: '${data.todayWordCount}',
                      icon: Icons.school_outlined,
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    _MetricRow(
                      label: 'Bugün okunan cümle',
                      value: '${data.todayReadSentenceCount}',
                      icon: Icons.menu_book_outlined,
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    _MetricRow(
                      label: 'Bugün çözülen soru',
                      value: data.todaySolvedQuestionText,
                      icon: Icons.quiz_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _WeeklyStreakCard(
                completion: _todayCompletionValue(data),
              ),
            ],
          ),
        );
      },
    );
  }

  double _todayCompletionValue(HomeDashboardData data) {
    final int points = (data.todayWordCount * 2) + data.todayReadSentenceCount;
    const int target = 40;
    final double raw = points / target;
    if (raw < 0) {
      return 0;
    }
    if (raw > 1) {
      return 1;
    }
    return raw;
  }
}

String _friendlyHomeError(Object error) {
  final String text = error.toString().toLowerCase();
  if (text.contains('auth session yok') || text.contains('anonymous')) {
    return 'Anonim oturum gecici olarak olusmadi. Ag baglantisini kontrol edip yeniden deneyin.';
  }
  return error.toString();
}

class _CompletionRing extends StatelessWidget {
  const _CompletionRing({
    required this.value,
    required this.words,
    required this.readCount,
  });

  final double value;
  final int words;
  final int readCount;

  @override
  Widget build(BuildContext context) {
    final int percent = (value * 100).round();
    return Row(
      children: <Widget>[
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              CircularProgressIndicator(
                value: value,
                strokeWidth: 10,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              Text(
                '%$percent',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Günlük ilerleme',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                '$words kelime',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text('$readCount cumle okundu'),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeeklyStreakCard extends StatelessWidget {
  const _WeeklyStreakCard({
    required this.completion,
  });

  final double completion;

  @override
  Widget build(BuildContext context) {
    final int activeIndex = DateTime.now().weekday - 1;
    return AppSurfaceCard(
      variant: AppSurfaceVariant.grouped,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const AppSectionHeader(title: 'Günlük Seri'),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List<Widget>.generate(7, (int index) {
              final bool active = index == activeIndex;
              final bool done = active && completion >= 0.5;
              return Column(
                children: <Widget>[
                  Text(
                    <String>[
                      'PZT',
                      'SAL',
                      'CAR',
                      'PER',
                      'CUM',
                      'CTS',
                      'PZR'
                    ][index],
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 6),
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: done
                        ? Theme.of(context).colorScheme.primary
                        : (active
                            ? Theme.of(context).colorScheme.secondaryContainer
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest),
                    child: done
                        ? Icon(
                            Icons.bolt_rounded,
                            size: 14,
                            color: Theme.of(context).colorScheme.onPrimary,
                          )
                        : null,
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: <Widget>[
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}
