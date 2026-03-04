import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/widgets/app_error_state.dart';
import '../../core/widgets/app_loading_block.dart';
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
    final AsyncValue<void> authBootstrap = ref.watch(authBootstrapProvider);
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
        ref.invalidate(authBootstrapProvider);
        try {
          await ref.read(authBootstrapProvider.future);
        } catch (_) {
          // Hata state'i ekranda AppErrorState ile gosterilecek.
        }
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
          authBootstrap.when(
            loading: () =>
                const AppLoadingBlock(message: 'Anonim oturum hazirlaniyor...'),
            error: (Object error, StackTrace stack) => AppErrorState(
              title: 'Oturum kurulamadigi icin profil metrikleri alinamadi.',
              detail: _friendlyAuthDetail(error),
              onRetry: () => ref.invalidate(authBootstrapProvider),
            ),
            data: (_) => dashboard.when(
              loading: () => const AppLoadingBlock(
                  message: 'Profil metrikleri yukleniyor...'),
              error: (Object error, StackTrace stack) => AppErrorState(
                title: 'Profil metrikleri alinamadi.',
                detail: _friendlyDashboardDetail(error),
                onRetry: () => ref.invalidate(homeDashboardProvider),
              ),
              data: (HomeDashboardData data) {
                return Column(
                  children: <Widget>[
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
          ),
          const SizedBox(height: 12),
          const AppSectionHeader(title: 'Sistem Durumu'),
          const SizedBox(height: 8),
          AppSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _InfoRow(
                  label: 'Auth',
                  value: 'Anonymous',
                ),
                _InfoRow(
                  label: 'Translate Provider',
                  value: AppConfig.translateProvider,
                ),
                const _InfoRow(
                  label: 'Progress Mode',
                  value: AppConfig.useProgressRpc ? 'RPC' : 'Upsert',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const AppSectionHeader(title: 'Icerik'),
          const SizedBox(height: 8),
          packs.when(
            loading: () =>
                const AppLoadingBlock(message: 'Pack ozeti yukleniyor...'),
            error: (Object error, StackTrace stack) => AppErrorState(
              title: 'Pack ozeti alinamadi.',
              detail: error.toString(),
              onRetry: () => ref.invalidate(packListProvider),
            ),
            data: (List<Pack> items) {
              final int totalWords =
                  items.fold<int>(0, (int sum, Pack p) => sum + p.wordCount);
              return AppSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _InfoRow(label: 'Toplam Pack', value: '${items.length}'),
                    _InfoRow(label: 'Toplam Kelime', value: '$totalWords'),
                    const SizedBox(height: 4),
                    Text(
                      'Faz 3 premium uyum profili aktif.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

String _friendlyAuthDetail(Object error) {
  final String text = error.toString().toLowerCase();
  if (text.contains('anonymous') || text.contains('auth')) {
    return 'Anonim oturum su an olusturulamadi. Ag baglantisini kontrol edip tekrar deneyin.';
  }
  return error.toString();
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
