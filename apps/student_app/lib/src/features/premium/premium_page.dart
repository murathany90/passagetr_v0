import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/student_analytics_models.dart';
import '../../core/student_providers.dart';
import '../common/page_parts.dart';

class StudentPremiumPage extends ConsumerWidget {
  const StudentPremiumPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessContext = ref.watch(studentAccessProvider);
    final analytics = ref.watch(studentAnalyticsSnapshotProvider);

    return StudentShellFrame(
      destination: StudentDestination.profile,
      title: accessContext.canViewPremium
          ? 'PASSAGETR PRO'
          : 'Premium ve Analytics',
      subtitle: accessContext.canViewPremium
          ? 'Abonelik durumun, hedeflerin ve haftalık performansın burada.'
          : 'Pro plan avantajlarını ve haftalık ilerleme metriklerini burada gör.',
      accessContext: accessContext,
      body: analytics.when(
        data: (snapshot) => _PremiumContent(
          snapshot: snapshot,
          isPremium: accessContext.canViewPremium,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Text(error.toString()),
      ),
    );
  }
}

class _PremiumContent extends StatelessWidget {
  const _PremiumContent({required this.snapshot, required this.isPremium});

  final StudentAnalyticsSnapshot snapshot;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= AppBreakpoints.gridWide;

        final hero = _PremiumHero(snapshot: snapshot, isPremium: isPremium);
        final benefits = _PlanBenefits(isPremium: isPremium);
        final metrics = _AnalyticsMetrics(snapshot: snapshot);
        final lifecycle = _LifecyclePanel(isPremium: isPremium);

        if (!isWide) {
          return Column(
            children: [
              hero,
              const SizedBox(height: 18),
              benefits,
              const SizedBox(height: 18),
              metrics,
              const SizedBox(height: 18),
              lifecycle,
            ],
          );
        }

        return Column(
          children: [
            hero,
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: benefits),
                const SizedBox(width: 18),
                Expanded(child: metrics),
              ],
            ),
            const SizedBox(height: 18),
            lifecycle,
          ],
        );
      },
    );
  }
}

class _PremiumHero extends StatelessWidget {
  const _PremiumHero({required this.snapshot, required this.isPremium});

  final StudentAnalyticsSnapshot snapshot;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    return StudentSurfaceCard(
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isPremium ? 'PRO Aktif' : 'FREE Plan',
              style: Theme.of(
                context,
              ).textTheme.displaySmall?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              isPremium
                  ? 'Sınırsız premium modüller ve ileri düzey analytics açık.'
                  : 'Pro plana geçerek tüm premium modüller, analytics ve gelişmiş akışlar açılır.',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.88),
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _HeroPill(label: '${snapshot.streakDays} gün streak'),
                _HeroPill(
                  label:
                      '${(snapshot.todayGoalProgress * 100).round()}% günlük hedef',
                ),
                _HeroPill(label: '${snapshot.completedGoalDays} hedef tamam'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

class _PlanBenefits extends StatelessWidget {
  const _PlanBenefits({required this.isPremium});

  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    return StudentSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Plan farkları',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 18),
          const _BenefitRow(
            title: 'Okuma kütüphanesi',
            freeValue: 'Seçili modüller',
            proValue: 'Sınırsız',
          ),
          const Divider(height: 28),
          const _BenefitRow(
            title: 'Gramer modülleri',
            freeValue: 'Temel modüller',
            proValue: 'Tüm modüller',
          ),
          const Divider(height: 28),
          const _BenefitRow(
            title: 'Analytics ve hedefler',
            freeValue: 'Özet görünüm',
            proValue: 'Tam dashboard',
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () {},
            child: Text(isPremium ? 'Aboneliği Yönet' : 'Pro\'ya Yükselt'),
          ),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.title,
    required this.freeValue,
    required this.proValue,
  });

  final String title;
  final String freeValue;
  final String proValue;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Free: $freeValue',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: tokens.secondaryText),
            ),
            const SizedBox(height: 6),
            Text(
              'Pro: $proValue',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ],
    );
  }
}

class _AnalyticsMetrics extends StatelessWidget {
  const _AnalyticsMetrics({required this.snapshot});

  final StudentAnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return StudentSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Analytics özeti',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricTile(label: 'Kelime', value: '${snapshot.weeklyWords}'),
              _MetricTile(label: 'Okuma', value: '${snapshot.weeklyReadings}'),
              _MetricTile(label: 'Gramer', value: '${snapshot.weeklyGrammar}'),
              _MetricTile(
                label: 'Günlük hedef',
                value: '${(snapshot.todayGoalProgress * 100).round()}%',
              ),
            ],
          ),
          const SizedBox(height: 18),
          StudentProgressBar(
            value: snapshot.todayGoalProgress,
            color: AppThemeTokens.of(context).accent,
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: tokens.secondaryText),
          ),
        ],
      ),
    );
  }
}

class _LifecyclePanel extends StatelessWidget {
  const _LifecyclePanel({required this.isPremium});

  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    return StudentSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Abonelik yaşam döngüsü',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 14),
          Text(
            isPremium
                ? 'Yenileme, plan değişikliği ve iptal akışlarının altyapı hazırlığı tamamlandı. Son ödeme sağlayıcısı bağlantısı bir sonraki release adımında açılır.'
                : 'Free plan aktif. Ödeme sağlayıcısı entegrasyonuna hazır upsell ve yenileme yüzeyi açıldı.',
          ),
        ],
      ),
    );
  }
}
