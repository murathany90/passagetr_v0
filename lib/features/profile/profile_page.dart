import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/layout/app_breakpoints.dart';
import '../../core/layout/app_page_container.dart';
import '../../core/widgets/app_error_state.dart';
import '../../core/widgets/app_gradient_cta_button.dart';
import '../../core/widgets/app_shimmer_block.dart';
import '../../core/widgets/app_section_header.dart';
import '../../core/widgets/app_stat_tile.dart';
import '../../core/widgets/app_surface_card.dart';
import '../../domain/entities/home_dashboard_data.dart';
import '../../domain/entities/pack.dart';
import '../../state/providers.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<HomeMetricsData> dashboard = ref.watch(
      homeMetricsProvider,
    );
    final AsyncValue<List<Pack>> packs = ref.watch(packListProvider);
    final ThemeMode themeMode = ref.watch(themeModeProvider);
    String? userId;
    try {
      userId = Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      userId = null;
    }
    final String shortUid = userId == null
        ? 'oturum_hazirlaniyor'
        : (userId.length > 12 ? '${userId.substring(0, 12)}...' : userId);

    return AppPageContainer(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool isDesktop = AppBreakpoints.isDesktopWidth(
            constraints.maxWidth,
          );
          final List<Widget> children = isDesktop
              ? <Widget>[
                  Row(
                    key: const ValueKey<String>('profile-page-desktop-layout'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: <Widget>[
                            _buildIdentityCard(context, shortUid),
                            const SizedBox(height: 12),
                            _buildSettingsPanel(
                              context,
                              ref,
                              packs.valueOrNull ?? const <Pack>[],
                              themeMode,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 6,
                        child: Column(
                          children: <Widget>[
                            _buildDailySummary(context, ref, dashboard),
                            const SizedBox(height: 12),
                            _buildSystemStatusCard(context, packs, themeMode),
                          ],
                        ),
                      ),
                    ],
                  ),
                ]
              : <Widget>[
                  _buildIdentityCard(context, shortUid),
                  const SizedBox(height: 12),
                  _buildDailySummary(context, ref, dashboard),
                  const SizedBox(height: 12),
                  _buildSettingsPanel(
                    context,
                    ref,
                    packs.valueOrNull ?? const <Pack>[],
                    themeMode,
                  ),
                ];

          return RefreshIndicator(
            onRefresh: () async {
              await ref
                  .read(offlineSyncControllerProvider.notifier)
                  .flushPending(silent: true);
              ref.invalidate(homeMetricsProvider);
              ref.invalidate(homeQuickStartProvider);
              ref.invalidate(homeDashboardProvider);
              ref.invalidate(packListProvider);
              try {
                await ref.read(homeMetricsProvider.future);
              } catch (_) {
                // Hata state'i ekranda gosterilecek.
              }
              try {
                await ref.read(packListProvider.future);
              } catch (_) {
                // Hata state'i ekranda gosterilecek.
              }
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: children,
            ),
          );
        },
      ),
    );
  }

  Widget _buildIdentityCard(BuildContext context, String shortUid) {
    return AppSurfaceCard(
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 28,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              Icons.person_outline_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 30,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Anonim Ogrenci',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'UID: $shortUid',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const Chip(
            label: Text('Active'),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildDailySummary(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<HomeMetricsData> dashboard,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const AppSectionHeader(title: 'Bugunun Ozeti'),
        const SizedBox(height: 8),
        dashboard.when(
          skipLoadingOnRefresh: true,
          skipLoadingOnReload: true,
          loading: () => const Column(
            children: <Widget>[
              AppShimmerCard(),
              SizedBox(height: 8),
              AppShimmerCard(),
              SizedBox(height: 8),
              AppShimmerCard(),
            ],
          ),
          error: (Object error, StackTrace stack) => AppErrorState(
            title: 'Profil metrikleri alinamadi.',
            detail: _friendlyDashboardDetail(error),
            onRetry: () => ref.invalidate(homeMetricsProvider),
          ),
          data: (HomeMetricsData data) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (data.todaySolvedQuestionText == 'Cevrimdisi')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Chip(
                      avatar: Icon(
                        Icons.cloud_off_rounded,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      label: const Text('Cevrimdisi mod'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                AppStatTile(
                  label: 'Bugun gorulen kelime',
                  value: '${data.todayWordCount}',
                  icon: Icons.school_outlined,
                ),
                const SizedBox(height: 8),
                AppStatTile(
                  label: 'Bugun okunan cumle',
                  value: '${data.todayReadSentenceCount}',
                  icon: Icons.menu_book_outlined,
                ),
                const SizedBox(height: 8),
                AppStatTile(
                  label: 'Bugun cozulen soru',
                  value: data.todaySolvedQuestionText,
                  icon: Icons.quiz_outlined,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSettingsPanel(
    BuildContext context,
    WidgetRef ref,
    List<Pack> packs,
    ThemeMode themeMode,
  ) {
    return AppSurfaceCard(
      key: const ValueKey<String>('profile-settings-panel'),
      variant: AppSurfaceVariant.grouped,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const AppSectionHeader(title: 'Ayarlar'),
          const SizedBox(height: 8),
          Text(
            'Tema, dil ve sistem bilgilerini tek alandan yonet.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              Chip(
                label: Text('Tema: ${_themeModeLabel(themeMode)}'),
                visualDensity: VisualDensity.compact,
              ),
              Chip(
                label: Text('Pack: ${packs.length}'),
                visualDensity: VisualDensity.compact,
              ),
              Chip(
                label: Text(AppConfig.translateProvider),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: AppBreakpoints.isDesktopWidth(
                      MediaQuery.sizeOf(context).width)
                  ? 220
                  : double.infinity,
              child: AppGradientCtaButton(
                onTap: () => _openSettingsSheet(context, ref, packs),
                icon: Icons.settings_outlined,
                label: 'Profil Ayarlari',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemStatusCard(
    BuildContext context,
    AsyncValue<List<Pack>> packs,
    ThemeMode themeMode,
  ) {
    final int totalWords = packs.valueOrNull
            ?.fold<int>(0, (int sum, Pack p) => sum + p.wordCount) ??
        0;

    return AppSurfaceCard(
      variant: AppSurfaceVariant.grouped,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const AppSectionHeader(title: 'Sistem Durumu'),
          const SizedBox(height: 10),
          const _InfoRow(label: 'Dil', value: 'Turkce'),
          const _InfoRow(label: 'Auth', value: 'Anonymous'),
          _InfoRow(
            label: 'Translate Provider',
            value: AppConfig.translateProvider,
          ),
          _InfoRow(label: 'Tema', value: _themeModeLabel(themeMode)),
          _InfoRow(
            label: 'Pack Sayisi',
            value: packs.maybeWhen(
              data: (List<Pack> items) => '${items.length}',
              orElse: () => '--',
            ),
          ),
          _InfoRow(label: 'Toplam Kelime', value: '$totalWords'),
        ],
      ),
    );
  }

  Future<void> _openSettingsSheet(
    BuildContext context,
    WidgetRef ref,
    List<Pack> packs,
  ) async {
    final int totalWords =
        packs.fold<int>(0, (int sum, Pack p) => sum + p.wordCount);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Profil',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                AppSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const _InfoRow(label: 'Dil', value: 'Turkce'),
                      const _InfoRow(label: 'Auth', value: 'Anonymous'),
                      _InfoRow(
                        label: 'Translate Provider',
                        value: AppConfig.translateProvider,
                      ),
                      const _InfoRow(
                        label: 'Progress Mode',
                        value: AppConfig.useProgressRpc ? 'RPC' : 'Upsert',
                      ),
                      _InfoRow(label: 'Toplam Pack', value: '${packs.length}'),
                      _InfoRow(label: 'Toplam Kelime', value: '$totalWords'),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                AppSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Gorunum Modu',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ThemeMode>(
                          segments: const <ButtonSegment<ThemeMode>>[
                            ButtonSegment<ThemeMode>(
                              value: ThemeMode.light,
                              icon: Icon(Icons.light_mode_outlined),
                              label: Text('Light'),
                            ),
                            ButtonSegment<ThemeMode>(
                              value: ThemeMode.dark,
                              icon: Icon(Icons.dark_mode_outlined),
                              label: Text('Dark'),
                            ),
                            ButtonSegment<ThemeMode>(
                              value: ThemeMode.system,
                              icon: Icon(Icons.settings_outlined),
                              label: Text('System'),
                            ),
                          ],
                          selected: <ThemeMode>{ref.watch(themeModeProvider)},
                          onSelectionChanged: (Set<ThemeMode> selected) {
                            ref
                                .read(themeModeProvider.notifier)
                                .setMode(selected.first);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _themeModeLabel(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'Light';
    case ThemeMode.dark:
      return 'Dark';
    case ThemeMode.system:
      return 'System';
  }
}

String _friendlyDashboardDetail(Object error) {
  final String text = error.toString().toLowerCase();
  if (text.contains('auth session yok') || text.contains('unauthenticated')) {
    return 'Oturum gecici olarak kesildi. Yeniden dene ile metrikleri tekrar yukleyin.';
  }
  return error.toString();
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
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
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}
