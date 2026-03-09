import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/student_providers.dart';
import '../common/page_parts.dart';
import '../readings/reading_seed_data.dart';

class StudentHomePage extends ConsumerWidget {
  const StudentHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessContext = ref.watch(studentAccessProvider);
    final streakDays = ref.watch(studentStreakDaysProvider);
    final reviewCount = ref.watch(studentReviewWordCountProvider);
    final continueProgress = ref.watch(studentContinueProgressProvider);
    final todayWords = ref.watch(studentTodayWordCountProvider);
    final todaySentences = ref.watch(studentTodaySentenceCountProvider);
    final weeklyTrend = ref.watch(studentWeeklyTrendProvider);
    final goalProgress = ref.watch(studentGoalProgressProvider);
    final completedGoalDays = ref.watch(studentCompletedGoalDaysProvider);
    final readings = ref.watch(studentReadingsProvider);

    final continueReading = readings.maybeWhen(
      data: _selectContinueReading,
      orElse: () => const ReadingPassage(
        id: 'reading-silent-ocean',
        title: 'The Silent Ocean',
        level: 'Zor',
        category: 'Bilim',
      ),
    );

    return StudentShellFrame(
      destination: StudentDestination.home,
      title: 'Hoş geldin, Ahmet!',
      subtitle: 'Bugün yeni bir şeyler öğrenmeye hazır mısın?',
      accessContext: accessContext,
      headerAction: _ProPill(
        isPremium: accessContext.canViewPremium,
        onPressed: () => context.go('/premium'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= AppBreakpoints.studentHomeWide;

          final heroCard = _StreakHeroCard(
            days: streakDays,
            goalProgress: goalProgress,
          );
          final continueCard = _ContinueReadingCard(
            reading: continueReading,
            progressPercent: continueProgress,
            onPressed: () => context.go('/readings/${continueReading.id}'),
          );
          final reviewCard = _ReviewCard(
            reviewCount: reviewCount,
            onPressed: () => context.go('/words/flashcards'),
          );
          final weeklyCard = _WeeklyProgressCard(
            trend: weeklyTrend,
            totalWords: todayWords,
            totalSentences: todaySentences,
            completedGoalDays: completedGoalDays,
            goalProgress: goalProgress,
          );

          if (!isWide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heroCard,
                const SizedBox(height: 18),
                continueCard,
                const SizedBox(height: 18),
                reviewCard,
                const SizedBox(height: 18),
                weeklyCard,
              ],
            );
          }

          return Column(
            children: [
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
                  SizedBox(width: 282, child: reviewCard),
                  const SizedBox(width: 20),
                  Expanded(child: weeklyCard),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  static ReadingPassage _selectContinueReading(List<ReadingPassage> items) {
    for (final item in items) {
      if (item.id == 'reading-silent-ocean') {
        return item;
      }
    }

    return items.first;
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
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(color: Colors.white),
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
    required this.onPressed,
  });

  final ReadingPassage reading;
  final int progressPercent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final readingSeed = readingSeedFor(reading.id);

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
                      'KALDI?IN YERDEN DEVAM ET',
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
          FilledButton(
            onPressed: onPressed,
            child: const Text('Kartları Başlat'),
          ),
        ],
      ),
    );
  }
}

class _WeeklyProgressCard extends StatelessWidget {
  const _WeeklyProgressCard({
    required this.trend,
    required this.totalWords,
    required this.totalSentences,
    required this.completedGoalDays,
    required this.goalProgress,
  });

  final List<double> trend;
  final int totalWords;
  final int totalSentences;
  final int completedGoalDays;
  final double goalProgress;

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
                      'Okuma ve kelime çalışma puanın',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: tokens.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.surfaceMuted,
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
                        'Bu Hafta',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: tokens.accent,
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
                caption: 'Günlük hedef',
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
              painter: _WeeklyTrendPainter(
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

class _WeeklyTrendPainter extends CustomPainter {
  const _WeeklyTrendPainter({
    required this.color,
    required this.fillColor,
    required this.values,
  });

  final Color color;
  final Color fillColor;
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) {
      return;
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    final fillPaint = Paint()..color = fillColor;

    final stepX = size.width / (values.length - 1);
    final points = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(
          i * stepX,
          size.height - (values[i].clamp(0.0, 1.0) * size.height),
        ),
    ];

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    final fillPath = Path()..moveTo(points.first.dx, size.height);

    for (var i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      final control = Offset((current.dx + next.dx) / 2, current.dy);
      final control2 = Offset((current.dx + next.dx) / 2, next.dy);
      linePath.cubicTo(
        control.dx,
        control.dy,
        control2.dx,
        control2.dy,
        next.dx,
        next.dy,
      );
      fillPath.cubicTo(
        control.dx,
        control.dy,
        control2.dx,
        control2.dy,
        next.dx,
        next.dy,
      );
    }

    fillPath
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(covariant _WeeklyTrendPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.color != color ||
        oldDelegate.fillColor != fillColor;
  }
}
