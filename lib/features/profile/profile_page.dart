import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
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
    final AsyncValue<HomeDashboardData> dashboard = ref.watch(
      homeDashboardProvider,
    );
    final AsyncValue<List<Pack>> packs = ref.watch(packListProvider);
    final String? userId = Supabase.instance.client.auth.currentUser?.id;
    final String shortUid = userId == null
        ? 'oturum_hazirlaniyor'
        : (userId.length > 12 ? '${userId.substring(0, 12)}...' : userId);

    return RefreshIndicator(
      onRefresh: () async {
        await ref
            .read(offlineSyncControllerProvider.notifier)
            .flushPending(silent: true);
        ref.invalidate(homeDashboardProvider);
        ref.invalidate(packListProvider);
        try {
          await ref.read(homeDashboardProvider.future);
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
        children: <Widget>[
          AppSurfaceCard(
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 28,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
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
          ),
          const SizedBox(height: 12),
          const AppSectionHeader(title: 'Bugunun Ozeti'),
          const SizedBox(height: 8),
          dashboard.when(
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
              onRetry: () => ref.invalidate(homeDashboardProvider),
            ),
            data: (HomeDashboardData data) {
              return Column(
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
          const SizedBox(height: 12),
          AppGradientCtaButton(
            onTap: () => _openSettingsSheet(
              context,
              ref,
              packs.valueOrNull ?? const <Pack>[],
            ),
            icon: Icons.settings_outlined,
            label: 'Profil Ayarlari',
          ),
          const SizedBox(height: 8),
          Text(
            'Dil, seviye, tema ve sistem durumunu alt menuden yonetebilirsin.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
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
