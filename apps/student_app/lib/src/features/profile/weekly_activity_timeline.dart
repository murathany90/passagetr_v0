import 'package:flutter/material.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/student_analytics_models.dart';
import '../common/page_parts.dart';

/// C3: 7 günlük aktivite timeline widget'ı.
///
/// Her gün için bir sütun: gün adı, aktivite emojileri ve hedef badge'i.
/// [stats] boş veya tüm değerler 0 ise motivasyonel boş durum gösterilir.
class WeeklyActivityTimeline extends StatelessWidget {
  const WeeklyActivityTimeline({
    super.key,
    required this.stats,
    required this.isLoading,
  });

  final List<StudentDailyStat> stats;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _TimelineSkeleton();
    }

    final hasAnyActivity = stats.any(
      (s) =>
          s.wordsStudied > 0 ||
          s.readingsCompleted > 0 ||
          s.grammarCompleted > 0,
    );

    if (!hasAnyActivity) {
      return _TimelineEmptyState();
    }

    return StudentSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bu Haftaki Aktivite',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final stat in stats) ...[
                Expanded(child: _DayColumn(stat: stat)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({required this.stat});

  final StudentDailyStat stat;

  static const List<String> _dayNames = [
    'Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz',
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final isToday =
        stat.date.day == DateTime.now().day &&
        stat.date.month == DateTime.now().month;
    final dayName = _dayNames[stat.date.weekday - 1];
    final emojis = _emojisFor(stat);

    return Column(
      children: [
        // Hedef tamamlandı badge
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: stat.goalCompleted
                ? tokens.success.withValues(alpha: 0.15)
                : tokens.surfaceMuted,
            border: isToday
                ? Border.all(color: tokens.accent, width: 2)
                : null,
          ),
          child: Center(
            child: Text(
              stat.goalCompleted ? '🔥' : (emojis.isNotEmpty ? emojis[0] : '·'),
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          dayName,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w400,
            color: isToday ? tokens.accent : tokens.secondaryText,
          ),
          textAlign: TextAlign.center,
        ),
        if (emojis.length > 1) ...[
          const SizedBox(height: 4),
          Text(
            emojis.skip(1).join(' '),
            style: const TextStyle(fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  List<String> _emojisFor(StudentDailyStat stat) {
    final result = <String>[];
    if (stat.readingsCompleted > 0) result.add('📖');
    if (stat.grammarCompleted > 0) result.add('✏️');
    if (stat.wordsStudied > 0) result.add('🔤');
    return result;
  }
}

class _TimelineEmptyState extends StatelessWidget {
  const _TimelineEmptyState();

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return StudentSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🎯', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 12),
          Text(
            'Bu hafta henüz aktivite yok',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Bugün bir okuma veya kelime çalışması yaparak streak başlat!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: tokens.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineSkeleton extends StatelessWidget {
  const _TimelineSkeleton();

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final baseColor = tokens.secondaryText.withValues(alpha: 0.1);
    return StudentSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 18,
            width: 140,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(
              7,
              (_) => Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: baseColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 12,
                      width: 24,
                      decoration: BoxDecoration(
                        color: baseColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
