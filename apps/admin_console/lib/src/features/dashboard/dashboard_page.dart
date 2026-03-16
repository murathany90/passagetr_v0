import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/admin_console_models.dart';
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
      subtitle: 'Icerik kapsami, operasyon ritmi ve audit akislarini izle.',
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
                  _InventoryMetricCard(
                    title: 'Okuma Kutuphanesi',
                    subtitle: 'Toplam reading kaydi',
                    total: data.readingInventory.total,
                    helperLabel:
                        'Yayinda ${data.readingInventory.publishedCount}',
                  ),
                  _CoverageMetricCard(
                    title: 'Mini Test Hazirligi',
                    subtitle: 'Hazir / Eksik',
                    metric: data.miniTestCoverage,
                  ),
                  _CoverageMetricCard(
                    title: 'Kapak Hazirligi',
                    subtitle: 'Hazir / Eksik',
                    metric: data.coverCoverage,
                  ),
                  _CoverageMetricCard(
                    title: 'Odak Kelime Baglantisi',
                    subtitle: 'Hazir / Eksik',
                    metric: data.linkedWordCoverage,
                  ),
                  _InventoryMetricCard(
                    title: 'Kelime Kartlari',
                    subtitle: 'Toplam word karti',
                    total: data.wordInventory.total,
                    helperLabel: 'Yayinda ${data.wordInventory.publishedCount}',
                  ),
                  _CoverageMetricCard(
                    title: 'Sozluk Eslesmesi',
                    subtitle: 'Eslesen / Eslesmeyen',
                    metric: data.dictionaryMatchCoverage,
                    primaryLabel: 'Eslesen',
                    secondaryLabel: 'Eslesmeyen',
                  ),
                  _SimpleMetricCard(
                    title: 'Sozluk Havuzu',
                    subtitle: 'Aktif dictionary entry sayisi',
                    total: data.dictionaryEntryCount,
                  ),
                  _InventoryMetricCard(
                    title: 'Gramer Modulleri',
                    subtitle: 'Toplam gramer modulu',
                    total: data.grammarInventory.total,
                    helperLabel:
                        'Yayinda ${data.grammarInventory.publishedCount}',
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
                  title: 'Icerik Operasyon Trendi',
                  trailing: _InfoChip(
                    label: '${data.contentTrend.length} nokta',
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 240,
                        child: _InteractiveTrendChart(
                          values: _normalizeTrend(data.contentTrend),
                          rawValues: data.contentTrend,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final point in data.contentTrend.take(7))
                            _TrendChip(point: point),
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
                            // C6: Her audit kaydına navigasyon butonu eklendi.
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(item.title),
                              subtitle: Text(item.subtitle),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    item.timestampLabel,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  const SizedBox(width: 8),
                                  _AuditActionChip(record: item),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                          ],
                        ],
                      );
                    },
                    // C4: Audit feed loading shimmer.
                    loading: () => const _AuditFeedSkeleton(),
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
        // C4: Ana loading durumu için shimmer skeleton.
        loading: () => const _DashboardSkeleton(),
        error: (error, stackTrace) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 36),
              const SizedBox(height: 12),
              Text('Dashboard yüklenemedi', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(error.toString(), style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(adminDashboardSnapshotProvider),
                child: const Text('Yeniden Dene'),
              ),
            ],
          ),
        ),
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

class _InventoryMetricCard extends StatelessWidget {
  const _InventoryMetricCard({
    required this.title,
    required this.subtitle,
    required this.total,
    required this.helperLabel,
  });

  final String title;
  final String subtitle;
  final int total;
  final String helperLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

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
          Text('$total', style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 8),
          _InfoChip(label: helperLabel),
          const SizedBox(height: 10),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _CoverageMetricCard extends StatelessWidget {
  const _CoverageMetricCard({
    required this.title,
    required this.subtitle,
    required this.metric,
    this.primaryLabel = 'Hazir',
    this.secondaryLabel = 'Eksik',
  });

  final String title;
  final String subtitle;
  final AdminDashboardCoverageMetric metric;
  final String primaryLabel;
  final String secondaryLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

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
            '${metric.readyCount} / ${metric.missingCount}',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(label: '$primaryLabel ${metric.readyCount}'),
              _InfoChip(label: '$secondaryLabel ${metric.missingCount}'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$subtitle | Toplam ${metric.total}',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: tokens.secondaryText),
          ),
        ],
      ),
    );
  }
}

class _SimpleMetricCard extends StatelessWidget {
  const _SimpleMetricCard({
    required this.title,
    required this.subtitle,
    required this.total,
  });

  final String title;
  final String subtitle;
  final int total;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

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
          Text('$total', style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: tokens.secondaryText),
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
    this.hoveredIndex,
    this.rawValues = const [],
  });

  final Color color;
  final Color fillColor;
  final List<double> values;
  final int? hoveredIndex;
  final List<AdminTrendPoint> rawValues;

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

    // C5: Tüm veri noktalarına küçük daire çiz
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (final pt in points) {
      canvas.drawCircle(pt, 3, dotPaint);
    }

    // C5: Hover noktasında büyük daire + etiket
    final hi = hoveredIndex;
    if (hi != null && hi >= 0 && hi < points.length) {
      final hp = points[hi];
      canvas.drawCircle(hp, 6, dotPaint);
      canvas.drawCircle(hp, 6, Paint()..color = fillColor..style = PaintingStyle.stroke..strokeWidth = 2);

      if (hi < rawValues.length) {
        final pt = rawValues[hi];
        final val = pt.value.truncateToDouble() == pt.value
            ? pt.value.toInt().toString()
            : pt.value.toStringAsFixed(1);
        final label = '${pt.label}: $val';
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final dx = (hp.dx + 8).clamp(0.0, size.width - tp.width);
        final dy = (hp.dy - tp.height - 6).clamp(0.0, size.height - tp.height);
        tp.paint(canvas, Offset(dx, dy));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AdminTrendPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.color != color ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.hoveredIndex != hoveredIndex;
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

/// C5: Trend grafiği üzerine hover veri noktaları ve Y-ekseni gridlines ekler.
class _InteractiveTrendChart extends StatefulWidget {
  const _InteractiveTrendChart({
    required this.values,
    required this.rawValues,
  });

  final List<double> values;
  final List<AdminTrendPoint> rawValues;

  @override
  State<_InteractiveTrendChart> createState() => _InteractiveTrendChartState();
}

class _InteractiveTrendChartState extends State<_InteractiveTrendChart> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return MouseRegion(
      onHover: (event) {
        if (widget.values.length < 2) return;
        final stepX = context.size!.width / (widget.values.length - 1);
        final index = (event.localPosition.dx / stepX).round()
            .clamp(0, widget.values.length - 1);
        if (_hoveredIndex != index) {
          setState(() => _hoveredIndex = index);
        }
      },
      onExit: (_) => setState(() => _hoveredIndex = null),
      child: CustomPaint(
        painter: _AdminTrendPainter(
          color: tokens.hero,
          fillColor: tokens.surfaceMuted.withValues(alpha: 0.75),
          values: widget.values,
          hoveredIndex: _hoveredIndex,
          rawValues: widget.rawValues,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// C6: Audit kayıt tipine göre hedef sayfaya yönlendiren chip.
class _AuditActionChip extends StatelessWidget {
  const _AuditActionChip({required this.record});

  final AdminAuditRecord record;

  String? _routeFor(String action, String subtitle) {
    final lower = action.toLowerCase();
    final sub = subtitle.toLowerCase();
    if (lower.contains('reading') || sub.contains('reading')) {
      return '/content/readings';
    }
    if (lower.contains('word') || sub.contains('word')) {
      return '/content/words';
    }
    if (lower.contains('grammar') || sub.contains('grammar')) {
      return '/content/grammar';
    }
    if (lower.contains('user') || sub.contains('user')) {
      return '/users';
    }
    if (lower.contains('setting') || sub.contains('setting')) {
      return '/settings';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final route = _routeFor(record.title, record.subtitle);
    if (route == null) return const SizedBox.shrink();
    return ActionChip(
      label: const Text('Aç'),
      visualDensity: VisualDensity.compact,
      onPressed: () => context.go(route),
    );
  }
}

/// C5: Trend chip'i — etiket + değer vurgulu.
class _TrendChip extends StatelessWidget {
  const _TrendChip({required this.point});

  final AdminTrendPoint point;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final value = point.value.truncateToDouble() == point.value
        ? point.value.toInt().toString()
        : point.value.toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tokens.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            point.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tokens.secondaryText,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// C4: Dashboard ana yükleme durumu skeleton.
class _DashboardSkeleton extends StatefulWidget {
  const _DashboardSkeleton();

  @override
  State<_DashboardSkeleton> createState() => _DashboardSkeletonState();
}

class _DashboardSkeletonState extends State<_DashboardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final tokens = AppThemeTokens.of(context);
        final color = tokens.secondaryText.withValues(alpha: 0.08 + _anim.value * 0.07);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: List.generate(
                6,
                (_) => Container(
                  width: 200,
                  height: 120,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// C4: Audit feed yükleme skeleton.
class _AuditFeedSkeleton extends StatelessWidget {
  const _AuditFeedSkeleton();

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final color = tokens.secondaryText.withValues(alpha: 0.1);
    return Column(
      children: List.generate(
        4,
        (_) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 14, width: 180, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6))),
                    const SizedBox(height: 6),
                    Container(height: 12, width: 120, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6))),
                  ],
                ),
              ),
              Container(height: 14, width: 60, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6))),
            ],
          ),
        ),
      ),
    );
  }
}

