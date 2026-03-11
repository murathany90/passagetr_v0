import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/admin_providers.dart';
import '../common/admin_page_parts.dart';

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessContext = ref.watch(adminAccessProvider);
    final snapshot = ref.watch(adminDashboardSnapshotProvider);
    final selectedWindow = ref.watch(adminDashboardWindowProvider);
    final auditFeed = ref.watch(adminAuditFeedProvider);

    return AdminShellFrame(
      destination: AdminDestination.dashboard,
      title: 'PASSAGETR Dashboard',
      subtitle: 'Kullanici, icerik ve audit akislarini trend bazli izle.',
      accessContext: accessContext,
      headerAction: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 7, label: Text('7 gun')),
              ButtonSegment(value: 30, label: Text('30 gun')),
              ButtonSegment(value: 90, label: Text('90 gun')),
            ],
            selected: <int>{selectedWindow},
            onSelectionChanged: (selection) =>
                ref.read(adminDashboardWindowProvider.notifier).state =
                    selection.first,
          ),
          FilledButton.icon(
            onPressed: () => context.go('/content/readings'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Icerige Git'),
          ),
        ],
      ),
      body: snapshot.when(
        data: (data) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final columns =
                    constraints.maxWidth >= AppBreakpoints.dashboardWide
                    ? 3
                    : constraints.maxWidth >= AppBreakpoints.tablet
                    ? 2
                    : 1;
                final spacing = 16.0;
                final itemWidth =
                    (constraints.maxWidth - ((columns - 1) * spacing)) /
                    columns;
                final cards = <Widget>[
                  _DeltaMetricCard(
                    title: 'Toplam Kullanici',
                    subtitle: '${data.windowDays} gunluk pencereye gore delta',
                    metric: data.userCount,
                  ),
                  _DeltaMetricCard(
                    title: 'Pro Kullanici',
                    subtitle: 'Aktif premium hesaplar',
                    metric: data.proUserCount,
                  ),
                  _DeltaMetricCard(
                    title: 'Kelime Havuzu',
                    subtitle: 'Words tablolarinin toplam hacmi',
                    metric: data.wordCount,
                  ),
                  _DeltaMetricCard(
                    title: 'Okuma Kutuphanesi',
                    subtitle: 'Reading passages toplam hacmi',
                    metric: data.readingCount,
                  ),
                  _DeltaMetricCard(
                    title: 'Gramer Modulleri',
                    subtitle: 'Yonetilen gramer modulu sayisi',
                    metric: data.grammarCount,
                  ),
                  _DeltaMetricCard(
                    title: 'Audit Kayitlari',
                    subtitle: 'Son pencereye gore degisim',
                    metric: data.auditCount,
                  ),
                ];

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final card in cards)
                      SizedBox(width: itemWidth, child: card),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide =
                    constraints.maxWidth >= AppBreakpoints.desktopWide;
                final trendPanel = AdminPanelCard(
                  title: 'Kullanici Trend Serisi',
                  trailing: _InfoChip(label: '${data.userTrend.length} nokta'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 240,
                        child: CustomPaint(
                          painter: _AdminTrendPainter(
                            color: AppThemeTokens.of(context).hero,
                            fillColor: AppThemeTokens.of(
                              context,
                            ).surfaceMuted.withValues(alpha: 0.75),
                            values: _normalizeTrend(data.userTrend),
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final point in data.userTrend.take(10))
                            _InfoChip(
                              label:
                                  '${point.label}: ${point.value.toStringAsFixed(point.value.truncateToDouble() == point.value ? 0 : 1)}',
                            ),
                        ],
                      ),
                    ],
                  ),
                );

                final statusPanel = AdminPanelCard(
                  title: 'Sistem Durumu',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StatusRow(
                        label: 'Maintenance',
                        value: data.maintenanceMode ? 'aktif' : 'kapali',
                        emphasize: data.maintenanceMode,
                      ),
                      _StatusRow(
                        label: 'Window',
                        value: '${data.windowDays} gun',
                      ),
                      _StatusRow(
                        label: 'Son audit delta',
                        value: _formatDelta(data.auditCount.delta),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: () => context.go('/settings'),
                        child: const Text('Ayarlari Ac'),
                      ),
                    ],
                  ),
                );

                final auditPanel = AdminPanelCard(
                  title: 'Son Audit Kayitlari',
                  child: auditFeed.when(
                    data: (feed) {
                      if (!feed.hasRecords) {
                        return AdminEmptyState(
                          title: feed.isUnavailable
                              ? 'Audit akisi kullanilamiyor'
                              : 'Henuz audit kaydi yok',
                          message:
                              feed.message ??
                              'Ilk yonetim islemi burada listelenecek.',
                          icon: feed.isUnavailable
                              ? Icons.lock_outline_rounded
                              : Icons.history_toggle_off_rounded,
                        );
                      }
                      return Column(
                        children: [
                          for (final item in feed.records.take(6)) ...[
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(item.title),
                              subtitle: Text(item.subtitle),
                              trailing: Text(item.timestampLabel),
                            ),
                            const Divider(height: 1),
                          ],
                        ],
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stackTrace) => Text(error.toString()),
                  ),
                );

                if (!isWide) {
                  return Column(
                    children: [
                      trendPanel,
                      const SizedBox(height: 16),
                      statusPanel,
                      const SizedBox(height: 16),
                      auditPanel,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: trendPanel),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          statusPanel,
                          const SizedBox(height: 16),
                          auditPanel,
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Text(error.toString()),
      ),
    );
  }
}

class _DeltaMetricCard extends StatelessWidget {
  const _DeltaMetricCard({
    required this.title,
    required this.subtitle,
    required this.metric,
  });

  final String title;
  final String subtitle;
  final AdminDashboardMetric metric;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final deltaPositive = metric.delta >= 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '${metric.total}',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: deltaPositive ? tokens.success : tokens.badgeOrange,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _formatDelta(metric.delta),
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: tokens.secondaryText),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: emphasize ? tokens.badgeOrange : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminTrendPainter extends CustomPainter {
  const _AdminTrendPainter({
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

    for (var index = 0; index < points.length - 1; index++) {
      final current = points[index];
      final next = points[index + 1];
      final control1 = Offset((current.dx + next.dx) / 2, current.dy);
      final control2 = Offset((current.dx + next.dx) / 2, next.dy);
      linePath.cubicTo(
        control1.dx,
        control1.dy,
        control2.dx,
        control2.dy,
        next.dx,
        next.dy,
      );
      fillPath.cubicTo(
        control1.dx,
        control1.dy,
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
  bool shouldRepaint(covariant _AdminTrendPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.color != color ||
        oldDelegate.fillColor != fillColor;
  }
}

List<double> _normalizeTrend(List<AdminTrendPoint> points) {
  if (points.isEmpty) {
    return const <double>[0, 0];
  }
  final maxValue = points.map((point) => point.value).fold<double>(0, math.max);
  if (maxValue <= 0) {
    return List<double>.filled(points.length, 0.05, growable: false);
  }
  return points
      .map((point) => (point.value / maxValue).clamp(0.0, 1.0))
      .toList(growable: false);
}

String _formatDelta(int delta) {
  if (delta > 0) {
    return '+$delta';
  }
  return '$delta';
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label), visualDensity: VisualDensity.compact);
  }
}
