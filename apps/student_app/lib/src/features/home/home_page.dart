import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/student_providers.dart';
import '../common/page_parts.dart';
import '../readings/reading_artwork.dart';
import '../readings/reading_seed_data.dart';

class StudentHomePage extends ConsumerWidget {
  const StudentHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessContext = ref.watch(studentAccessProvider);
    final streakDays = ref.watch(studentStreakDaysProvider);
    final reviewCount = ref.watch(studentReviewWordCountProvider);
    final continueSummary = ref.watch(studentContinueReadingSummaryProvider);
    final weeklyWords = ref.watch(studentWeeklyWordCountProvider);
    final weeklySessions = ref.watch(studentWeeklySessionCountProvider);
    final weeklyTrend = ref.watch(studentWeeklyTrendProvider);
    final goalProgress = ref.watch(studentGoalProgressProvider);
    final completedGoalDays = ref.watch(studentCompletedGoalDaysProvider);
    final analyticsEstimated = ref.watch(studentAnalyticsEstimatedProvider);

    final wordOfTheDay = ref.watch(studentWordOfTheDayProvider);
    final recommendedReadings = ref.watch(studentRecommendedReadingsProvider);
    final wordSummary = ref.watch(studentWordSummaryProvider);
    final readingProgressMap =
        ref.watch(studentReadingProgressProvider).valueOrNull ?? const {};

    final displayName = _displayNameFor(accessContext);

    return StudentShellFrame(
      destination: StudentDestination.home,
      title: 'Hoş geldin, $displayName!',
      subtitle: 'Bugün yeni bir şeyler öğrenmeye hazır mısın?',
      accessContext: accessContext,
      browserTitle: 'Ana Sayfa',
      headerAction: _ProPill(
        isPremium: accessContext.canViewPremium,
        onPressed: () => context.go('/premium'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= AppBreakpoints.studentHomeWide;

          final statsBar = _QuickStatsBar(
            studiedWords: wordSummary.studiedCount,
            totalWords: wordSummary.totalCount,
            completedReadings:
                readingProgressMap.values.where((p) => p.completed).length,
          );

          final heroCard = _StreakHeroCard(
            days: streakDays,
            goalProgress: goalProgress,
          );
          final continueCard = _ContinueReadingCard(
            reading: continueSummary.reading,
            progressPercent: continueSummary.progressPercent,
            ctaLabel: continueSummary.ctaLabel,
            onPressed:
                continueSummary.hasReading
                    ? () =>
                        context.go('/readings/${continueSummary.reading.id}')
                    : null,
          );
          final wordOfTheDayCard = _WordOfTheDayCard(word: wordOfTheDay);
          final reviewCard = _ReviewCard(
            reviewCount: reviewCount,
            onPressed: () => context.go('/words/flashcards'),
          );
          final weeklyCard = _AnalyticsWeeklyProgressCard(
            trend: weeklyTrend,
            totalWords: weeklyWords,
            totalSentences: weeklySessions,
            completedGoalDays: completedGoalDays,
            goalProgress: goalProgress,
            isEstimated: analyticsEstimated,
          );

          final recommendedSection = _RecommendedReadingsSection(
            readings: recommendedReadings,
            progressMap: readingProgressMap,
            canViewPremium: accessContext.canViewPremium,
          );

          if (!isWide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                statsBar,
                const SizedBox(height: 18),
                heroCard,
                const SizedBox(height: 18),
                continueCard,
                const SizedBox(height: 18),
                wordOfTheDayCard,
                const SizedBox(height: 18),
                reviewCard,
                const SizedBox(height: 18),
                weeklyCard,
                const SizedBox(height: 24),
                recommendedSection,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              statsBar,
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: heroCard),
                  const SizedBox(width: 20),
                  Expanded(child: continueCard),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        wordOfTheDayCard,
                        const SizedBox(height: 20),
                        reviewCard,
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(child: weeklyCard),
                ],
              ),
              const SizedBox(height: 24),
              recommendedSection,
            ],
          );
        },
      ),
    );
  }

  static String _displayNameFor(AccessContext accessContext) {
    final rawDisplayName = accessContext.session.user?.displayName?.trim();
    if (rawDisplayName != null && rawDisplayName.isNotEmpty) {
      return rawDisplayName;
    }

    final email = accessContext.email?.trim();
    if (email != null && email.contains('@')) {
      final localPart = email.split('@').first.replaceAll('.', ' ');
      return localPart
          .split(' ')
          .where((part) => part.isNotEmpty)
          .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
          .join(' ');
    }

    return accessContext.isAnonymous ? 'Misafir' : 'Öğrenci';
  }
}

class _ProPill extends StatelessWidget {
  const _ProPill({required this.isPremium, required this.onPressed});

  final bool isPremium;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(tokens.pillRadius),
      onTap: onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(tokens.pillRadius),
          border: Border.all(color: tokens.hero.withValues(alpha: 0.45)),
          color: tokens.surface.withValues(alpha: 0.72),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_outlined, size: 18, color: tokens.hero),
              const SizedBox(width: 8),
              Text(
                isPremium ? 'PRO Aktif' : 'Pro\'ya Geç',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: tokens.hero),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakHeroCard extends StatelessWidget {
  const _StreakHeroCard({required this.days, required this.goalProgress});

  final int days;
  final double goalProgress;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return StudentSurfaceCard(
      padding: EdgeInsets.zero,
      child: Container(
        constraints: const BoxConstraints(minHeight: 154),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(tokens.cardRadius),
          gradient: LinearGradient(
            colors: [tokens.hero, const Color(0xFFFF720F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -16,
              bottom: -18,
              child: Icon(
                Icons.local_fire_department_rounded,
                size: 120,
                color: tokens.heroGlow.withValues(alpha: 0.46),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.local_fire_department_rounded,
                        size: 28,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$days Gün',
                        style: Theme.of(
                          context,
                        ).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Hedef ${(goalProgress * 100).round()}%',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Harika gidiyorsun! Seriyi bozma.',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                  ),
                  const SizedBox(height: 14),
                  StudentProgressBar(
                    value: goalProgress,
                    color: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.24),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContinueReadingCard extends StatelessWidget {
  const _ContinueReadingCard({
    required this.reading,
    required this.progressPercent,
    required this.ctaLabel,
    required this.onPressed,
  });

  final ReadingPassage reading;
  final int progressPercent;
  final String ctaLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final readingSeed = readingSeedForPassage(reading);

    return StudentSurfaceCard(
      minHeight: 154,
      onTap: onPressed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ctaLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.accent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      reading.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      readingSeed.summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: tokens.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: tokens.surfaceMuted,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: tokens.accent,
                  size: 30,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: StudentProgressBar(
                  value: progressPercent / 100,
                  color: tokens.accent,
                  backgroundColor: tokens.accentSoft.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                '%$progressPercent Tamamlandı',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: tokens.secondaryText),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.reviewCount, required this.onPressed});

  final int reviewCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return StudentSurfaceCard(
      minHeight: 390,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_outlined, color: tokens.hero),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Gözden Geçirilecekler',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(fontSize: 18),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: tokens.badgeOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$reviewCount Kelime',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.badgeOrange,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Center(
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: tokens.accentSoft, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.auto_awesome_outlined,
                size: 52,
                color: tokens.secondaryText.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(height: 26),
          Center(
            child: Text(
              'Tekrar vakti geldi!',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: tokens.accent),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Öğrendiklerini pekiştirmek için kelime kartlarına göz at.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: tokens.secondaryText),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: onPressed, child: const Text('Kartları Başlat')),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsWeeklyProgressCard extends StatelessWidget {
  const _AnalyticsWeeklyProgressCard({
    required this.trend,
    required this.totalWords,
    required this.totalSentences,
    required this.completedGoalDays,
    required this.goalProgress,
    required this.isEstimated,
  });

  final List<double> trend;
  final int totalWords;
  final int totalSentences;
  final int completedGoalDays;
  final double goalProgress;
  final bool isEstimated;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return StudentSurfaceCard(
      minHeight: 390,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Haftalık İlerleme',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isEstimated
                          ? 'Canlı veri yerine tahmini haftalık trend gösteriliyor.'
                          : 'Canlı haftalık aktivite özeti',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: tokens.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color:
                      isEstimated
                          ? tokens.warning.withValues(alpha: 0.12)
                          : tokens.surfaceMuted,
                  borderRadius: BorderRadius.circular(tokens.pillRadius),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Text(
                        isEstimated ? 'Tahmini Veri' : 'Bu Hafta',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isEstimated
                            ? Icons.info_outline_rounded
                            : Icons.bar_chart_rounded,
                        color: isEstimated ? tokens.warning : tokens.accent,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              _MetricPill(
                label: '${(goalProgress * 100).round()}%',
                caption: 'Bugünkü hedef',
              ),
              const SizedBox(width: 18),
              _MetricPill(
                label: '$completedGoalDays gün',
                caption: '$totalWords kelime | $totalSentences oturum',
              ),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 210,
            child: CustomPaint(
              painter: _WeeklyBarPainter(
                color: tokens.accent,
                fillColor: tokens.accentSoft.withValues(alpha: 0.85),
                values: trend,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              _WeekLabel('Pzt'),
              _WeekLabel('Sal'),
              _WeekLabel('Çar'),
              _WeekLabel('Per'),
              _WeekLabel('Cum'),
              _WeekLabel('Cmt'),
              _WeekLabel('Paz'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.caption});

  final String label;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(caption, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _WeekLabel extends StatelessWidget {
  const _WeekLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _WeeklyBarPainter extends CustomPainter {
  const _WeeklyBarPainter({
    required this.color,
    required this.fillColor,
    required this.values,
  });

  final Color color;
  final Color fillColor;
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) {
      return;
    }

    final baselinePaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..strokeWidth = 1.5;
    final barPaint = Paint()..color = fillColor;
    final capPaint = Paint()..color = color;
    final segmentWidth = size.width / values.length;
    final barWidth = segmentWidth * 0.58;
    final capHeight = 8.0;
    final radius = Radius.circular(barWidth / 2);

    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      baselinePaint,
    );

    for (var index = 0; index < values.length; index++) {
      final normalized = values[index].clamp(0, 1);
      final barHeight = (size.height * normalized).clamp(10.0, size.height);
      final left = (segmentWidth * index) + ((segmentWidth - barWidth) / 2);
      final top = size.height - barHeight;
      final bodyRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(left, top, barWidth, barHeight),
        topLeft: radius,
        topRight: radius,
        bottomLeft: radius,
        bottomRight: radius,
      );
      canvas.drawRRect(bodyRect, barPaint);

      final capRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(left, top, barWidth, capHeight.clamp(0, barHeight)),
        topLeft: radius,
        topRight: radius,
      );
      canvas.drawRRect(capRect, capPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyBarPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.color != color ||
        oldDelegate.fillColor != fillColor;
  }
}

class _QuickStatsBar extends StatelessWidget {
  const _QuickStatsBar({
    required this.studiedWords,
    required this.totalWords,
    required this.completedReadings,
  });

  final int studiedWords;
  final int totalWords;
  final int completedReadings;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _StatPill(
            icon: Icons.auto_awesome_rounded,
            label: '$studiedWords / $totalWords',
            caption: 'Kelime',
            color: tokens.accent,
          ),
          const SizedBox(width: 12),
          _StatPill(
            icon: Icons.menu_book_rounded,
            label: '$completedReadings',
            caption: 'Okuma',
            color: tokens.success,
          ),
          const SizedBox(width: 12),
          _StatPill(
            icon: Icons.emoji_events_rounded,
            label:
                '%${totalWords > 0 ? ((studiedWords / totalWords) * 100).round() : 0}',
            caption: 'Başarı',
            color: tokens.warning,
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.label,
    required this.caption,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String caption;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.surfaceBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                caption,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: tokens.secondaryText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WordOfTheDayCard extends StatelessWidget {
  const _WordOfTheDayCard({required this.word});

  final WordEntry? word;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    if (word == null) return const SizedBox.shrink();

    return StudentSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: tokens.warning),
              const SizedBox(width: 10),
              Text(
                'Günün Kelimesi',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: tokens.warning,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            word!.enWord,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: tokens.primaryText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            word!.trMeaning,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: tokens.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (word!.exampleEn.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              word!.exampleEn,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: tokens.secondaryText,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecommendedReadingsSection extends StatelessWidget {
  const _RecommendedReadingsSection({
    required this.readings,
    required this.progressMap,
    required this.canViewPremium,
  });

  final List<ReadingPassage> readings;
  final Map<String, ReadingProgress> progressMap;
  final bool canViewPremium;

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Senin İçin Önerilenler',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final reading in readings)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: SizedBox(
                    width: 300,
                    child: _RecommendedReadingItem(
                      reading: reading,
                      progress: progressMap[reading.id],
                      isLocked: reading.isPro && !canViewPremium,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecommendedReadingItem extends StatelessWidget {
  const _RecommendedReadingItem({
    required this.reading,
    this.progress,
    required this.isLocked,
  });

  final ReadingPassage reading;
  final ReadingProgress? progress;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final seed = readingSeedForPassage(reading);

    return StudentSurfaceCard(
      padding: EdgeInsets.zero,
      onTap:
          isLocked
              ? () => context.go('/premium')
              : () => context.go('/readings/${reading.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReadingArtwork(
            seed: seed,
            remoteUrl: reading.coverUrl,
            height: 120,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: seed.levelBadgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        reading.level ?? '-',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: seed.levelBadgeColor,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (isLocked) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 14,
                        color: tokens.warning,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  reading.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  seed.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
