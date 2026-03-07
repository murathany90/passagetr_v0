import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/layout/app_page_container.dart';
import '../../core/widgets/app_error_state.dart';
import '../../core/widgets/app_gradient_cta_button.dart';
import '../../core/widgets/app_section_header.dart';
import '../../core/widgets/app_shimmer_block.dart';
import '../../core/widgets/app_surface_card.dart';
import '../../domain/entities/home_dashboard_data.dart';
import '../../domain/entities/pack.dart';
import '../../domain/entities/reading_resume_item.dart';
import '../../state/providers.dart';
import '../flashcard/flashcard_session_page.dart';
import '../readings/reading_detail_page.dart';

const HomeMetricsData _defaultHomeMetricsData = HomeMetricsData(
  todayWordCount: 0,
  todayReadSentenceCount: 0,
  todaySolvedQuestionText: 'Yakinda',
);

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
      ref.invalidate(homeMetricsProvider);
      ref.invalidate(homeQuickStartProvider);
      ref.invalidate(homeDashboardProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<HomeMetricsData> metricsAsync = ref.watch(
      homeMetricsProvider,
    );
    final AsyncValue<QuickStartSuggestion> quickStartAsync = ref.watch(
      homeQuickStartProvider,
    );
    final HomeMetricsData metrics =
        metricsAsync.valueOrNull ?? _defaultHomeMetricsData;
    final QuickStartSuggestion quickStart =
        quickStartAsync.valueOrNull ??
            const QuickStartSuggestion(type: QuickStartType.unavailable);
    final HomeDashboardData data = HomeDashboardData(
      todayWordCount: metrics.todayWordCount,
      todayReadSentenceCount: metrics.todayReadSentenceCount,
      todaySolvedQuestionText: metrics.todaySolvedQuestionText,
      quickStart: quickStart,
    );
    final bool metricsLoading =
        metricsAsync.isLoading && metricsAsync.valueOrNull == null;
    final String quickStartTitle = _resolveQuickStartTitle(
      quickStartAsync,
      quickStart,
    );

    if (metricsAsync.hasError && metricsAsync.valueOrNull == null) {
      return AppPageContainer(
        padding: EdgeInsets.zero,
        child: AppErrorState(
          title: 'Ana sayfa verisi yuklenemedi.',
          detail: _friendlyHomeError(metricsAsync.error!),
          onRetry: () {
            ref.invalidate(homeMetricsProvider);
            ref.invalidate(homeQuickStartProvider);
            ref.invalidate(homeDashboardProvider);
          },
        ),
      );
    }

    return AppPageContainer(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool isDesktop = AppBreakpoints.isDesktopWidth(
            constraints.maxWidth,
          );

          return RefreshIndicator(
            onRefresh: () async {
              await ref
                  .read(offlineSyncControllerProvider.notifier)
                  .flushPending(silent: true);
              ref.invalidate(homeMetricsProvider);
              ref.invalidate(homeQuickStartProvider);
              ref.invalidate(homeDashboardProvider);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                if ((metricsAsync.isLoading && metricsAsync.valueOrNull != null) ||
                    (quickStartAsync.isLoading &&
                        quickStartAsync.valueOrNull != null))
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                ...(isDesktop
                    ? <Widget>[
                        Row(
                          key: const ValueKey<String>(
                            'home-dashboard-desktop-layout',
                          ),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              flex: 8,
                              child: _buildHeroCard(
                                context,
                                data: data,
                                quickStartTitle: quickStartTitle,
                                metricsLoading: metricsLoading,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 4,
                              child: Column(
                                children: <Widget>[
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: AppSectionHeader(
                                      title: 'Gunluk Metrikler',
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildMetricsCard(
                                    context,
                                    data,
                                    loading: metricsLoading,
                                  ),
                                  const SizedBox(height: 12),
                                  _WeeklyStreakCard(
                                    completion: _todayCompletionValue(data),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ]
                    : <Widget>[
                        _buildHeroCard(
                          context,
                          data: data,
                          quickStartTitle: quickStartTitle,
                          metricsLoading: metricsLoading,
                        ),
                        const SizedBox(height: 16),
                        const AppSectionHeader(title: 'Gunluk Metrikler'),
                        const SizedBox(height: 8),
                        _buildMetricsCard(
                          context,
                          data,
                          loading: metricsLoading,
                        ),
                        const SizedBox(height: 12),
                        _WeeklyStreakCard(
                          completion: _todayCompletionValue(data),
                        ),
                      ]),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroCard(
    BuildContext context, {
    required HomeDashboardData data,
    required String quickStartTitle,
    required bool metricsLoading,
  }) {
    final bool isDesktop = _isDesktopLayout(context);

    return AppSurfaceCard(
      variant: AppSurfaceVariant.feature,
      padding: const EdgeInsets.all(16),
      child: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: _HeroPrimaryContent(
                    data: data,
                    quickStartTitle: quickStartTitle,
                    isDesktop: true,
                    completionValue: _todayCompletionValue(data),
                    metricsLoading: metricsLoading,
                    onQuickStart: () => _onQuickStart(data),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 236,
                  child: _HeroDesktopAside(
                    completionValue: _todayCompletionValue(data),
                    quickStartTitle: quickStartTitle,
                    wordCount: data.todayWordCount,
                    readCount: data.todayReadSentenceCount,
                    metricsLoading: metricsLoading,
                  ),
                ),
              ],
            )
          : _HeroPrimaryContent(
              data: data,
              quickStartTitle: quickStartTitle,
              isDesktop: false,
              completionValue: _todayCompletionValue(data),
              metricsLoading: metricsLoading,
              onQuickStart: () => _onQuickStart(data),
            ),
    );
  }

  Widget _buildMetricsCard(
    BuildContext context,
    HomeDashboardData data, {
    required bool loading,
  }) {
    if (loading) {
      return const AppShimmerCard(lineCount: 3);
    }

    return AppSurfaceCard(
      variant: AppSurfaceVariant.grouped,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: <Widget>[
          _MetricRow(
            label: 'Bugun gorulen kelime',
            value: '${data.todayWordCount}',
            icon: Icons.school_outlined,
          ),
          const Divider(indent: 16, endIndent: 16),
          _MetricRow(
            label: 'Bugun okunan cumle',
            value: '${data.todayReadSentenceCount}',
            icon: Icons.menu_book_outlined,
          ),
          const Divider(indent: 16, endIndent: 16),
          _MetricRow(
            label: 'Bugun cozulen soru',
            value: data.todaySolvedQuestionText,
            icon: Icons.quiz_outlined,
          ),
        ],
      ),
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

String _resolveQuickStartTitle(
  AsyncValue<QuickStartSuggestion> quickStartAsync,
  QuickStartSuggestion quickStart,
) {
  if (quickStartAsync.isLoading && quickStartAsync.valueOrNull == null) {
    return 'Oneri hazirlaniyor';
  }
  return switch (quickStart.type) {
    QuickStartType.resumeReading => 'Okumaya devam et',
    QuickStartType.weakWords => 'Zorlandigin kelimeler',
    QuickStartType.randomWords => 'Rastgele flashcard',
    QuickStartType.unavailable => 'Su an oneri yok',
  };
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
    this.compact = false,
  });

  final double value;
  final int words;
  final int readCount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final int percent = (value * 100).round();
    return Row(
      children: <Widget>[
        SizedBox(
          width: compact ? 96 : 120,
          height: compact ? 96 : 120,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              CircularProgressIndicator(
                value: value,
                strokeWidth: compact ? 8 : 10,
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
                'Gunluk ilerleme',
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

class _HeroPrimaryContent extends StatelessWidget {
  const _HeroPrimaryContent({
    required this.data,
    required this.quickStartTitle,
    required this.isDesktop,
    required this.completionValue,
    required this.metricsLoading,
    required this.onQuickStart,
  });

  final HomeDashboardData data;
  final String quickStartTitle;
  final bool isDesktop;
  final double completionValue;
  final bool metricsLoading;
  final VoidCallback onQuickStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Bugunku Egitim',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Reading is Power. Gunluk hedefini odakli bir oturumla surdur.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        if (metricsLoading)
          const AppShimmerCard(lineCount: 2)
        else
          _CompletionRing(
            value: completionValue,
            words: data.todayWordCount,
            readCount: data.todayReadSentenceCount,
            compact: isDesktop,
          ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .secondaryContainer
                .withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'Siradaki adim: $quickStartTitle',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: isDesktop ? 240 : double.infinity,
            child: AppGradientCtaButton(
              label: 'Hizli Basla',
              icon: Icons.play_arrow_rounded,
              enabled: data.quickStart.isAvailable,
              onTap: onQuickStart,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroDesktopAside extends StatelessWidget {
  const _HeroDesktopAside({
    required this.completionValue,
    required this.quickStartTitle,
    required this.wordCount,
    required this.readCount,
    required this.metricsLoading,
  });

  final double completionValue;
  final String quickStartTitle;
  final int wordCount;
  final int readCount;
  final bool metricsLoading;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      variant: AppSurfaceVariant.grouped,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Bugun Plani',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          _HeroAsideRow(label: 'Odak', value: quickStartTitle),
          const SizedBox(height: 8),
          _HeroAsideRow(
            label: 'Kelime',
            value: metricsLoading ? '--' : '$wordCount',
          ),
          const SizedBox(height: 8),
          _HeroAsideRow(
            label: 'Cumle',
            value: metricsLoading ? '--' : '$readCount',
          ),
          const SizedBox(height: 8),
          _HeroAsideRow(
            label: 'Tamamlama',
            value: metricsLoading
                ? '--'
                : '%${(completionValue * 100).round()}',
          ),
        ],
      ),
    );
  }
}

class _HeroAsideRow extends StatelessWidget {
  const _HeroAsideRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

bool _isDesktopLayout(BuildContext context) {
  return AppBreakpoints.isDesktopWidth(MediaQuery.sizeOf(context).width);
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
          const AppSectionHeader(title: 'Gunluk Seri'),
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
                      'PZR',
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
