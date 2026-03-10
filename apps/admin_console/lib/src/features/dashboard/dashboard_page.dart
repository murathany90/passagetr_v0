import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/admin_providers.dart';
import '../common/admin_page_parts.dart';

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessContext = ref.watch(adminAccessProvider);
    final summary = ref.watch(adminDashboardSummaryProvider);
    final audits = ref.watch(adminAuditLogProvider);

    return AdminShellFrame(
      destination: AdminDestination.dashboard,
      title: 'PASSAGETR Dashboard',
      subtitle: 'Kullanıcı, içerik ve audit akışlarını tek ekrandan yönet.',
      accessContext: accessContext,
      headerAction: FilledButton.icon(
        onPressed: () => context.go('/content/readings'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('İçeriğe Git'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          summary.when(
            data: (data) => LayoutBuilder(
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
                final cards = <AdminSummaryCard>[
                  AdminSummaryCard(
                    title: 'Toplam Kullanıcı',
                    subtitle: 'Aktif ve seeded hesaplar',
                    value: '${data.userCount}',
                  ),
                  AdminSummaryCard(
                    title: 'Pro Kullanıcı',
                    subtitle: 'Premium erişimi açık hesaplar',
                    value: '${data.proUserCount}',
                  ),
                  AdminSummaryCard(
                    title: 'Toplam İçerik',
                    subtitle: 'Kelime + okuma + gramer toplami',
                    value:
                        '${data.wordCount + data.readingCount + data.grammarCount}',
                  ),
                  AdminSummaryCard(
                    title: 'Kelime Havuzu',
                    subtitle: 'Yayınlanan ve taslak kelimeler',
                    value: '${data.wordCount}',
                  ),
                  AdminSummaryCard(
                    title: 'Okuma Kütüphanesi',
                    subtitle: 'Parçalar ve detay modülleri',
                    value: '${data.readingCount}',
                  ),
                  AdminSummaryCard(
                    title: 'Audit Kayıtları',
                    subtitle: 'Son yönetim aksiyonları',
                    value: '${data.auditCount}',
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
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Text(error.toString()),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= AppBreakpoints.desktopWide;
              final quickActions = AdminPanelCard(
                title: 'Hızlı Aksiyonlar',
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton(
                      onPressed: () => context.go('/users'),
                      child: const Text('Kullanıcıları Yönet'),
                    ),
                    FilledButton.tonal(
                      onPressed: () => context.go('/content/words'),
                      child: const Text('Kelime CMS'),
                    ),
                    FilledButton.tonal(
                      onPressed: () => context.go('/content/readings'),
                      child: const Text('Okuma CMS'),
                    ),
                    FilledButton.tonal(
                      onPressed: () => context.go('/content/grammar'),
                      child: const Text('Gramer CMS'),
                    ),
                  ],
                ),
              );

              final auditPanel = AdminPanelCard(
                title: 'Son Audit Kayıtları',
                child: audits.when(
                  data: (items) => Column(
                    children: [
                      for (final item in items.take(6)) ...[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.title),
                          subtitle: Text(item.subtitle),
                          trailing: Text(item.timestampLabel),
                        ),
                        const Divider(height: 1),
                      ],
                    ],
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) => Text(error.toString()),
                ),
              );

              if (!isWide) {
                return Column(
                  children: [
                    quickActions,
                    const SizedBox(height: 16),
                    auditPanel,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: quickActions),
                  const SizedBox(width: 16),
                  Expanded(child: auditPanel),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
