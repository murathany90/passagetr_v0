import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/responsive_shell_scaffold.dart';
import '../../core/services/offline_sync_controller.dart';
import '../../state/content_providers.dart';
import '../../state/web_warmup_providers.dart';
import '../grammar/grammar_home_page.dart';
import '../home/home_dashboard_page.dart';
import '../profile/profile_page.dart';
import '../readings/reading_home_page.dart';
import '../words/word_home_page.dart';
import '../../state/nav_badge_providers.dart';
import '../../state/offline_sync_providers.dart';

class MainShellPage extends ConsumerStatefulWidget {
  const MainShellPage({super.key});

  @override
  ConsumerState<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends ConsumerState<MainShellPage>
    with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(contentHydrationControllerProvider.notifier).ensureHydrated();
      unawaited(
        Future<void>.delayed(
          const Duration(milliseconds: 160),
          () => ref.read(webStartupWarmupProvider).warmup(),
        ),
      );
      unawaited(ref
          .read(offlineSyncControllerProvider.notifier)
          .flushPending(silent: true));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref
          .read(offlineSyncControllerProvider.notifier)
          .flushPending(silent: true));
    }
  }

  String _titleForIndex(int index) {
    return switch (index) {
      0 => 'Ana Sayfa',
      1 => 'Kelime',
      2 => 'Okuma',
      3 => 'Gramer',
      _ => 'Profil',
    };
  }

  Widget _buildBodyForIndex(int index) {
    return switch (index) {
      0 => const HomeDashboardPage(),
      1 => const WordHomePage(),
      2 => const ReadingHomePage(),
      3 => const GrammarHomePage(),
      _ => const ProfilePage(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<int> weakCount = ref.watch(weakWordCountProvider);
    final int badgeCount = weakCount.valueOrNull ?? 0;
    final OfflineSyncStatus syncStatus = ref.watch(offlineSyncStatusProvider);
    final bool shouldUseHydrationGate = ref.watch(
      shouldUseContentHydrationProvider,
    );
    final ContentHydrationState hydrationState = ref.watch(
      contentHydrationControllerProvider,
    );
    final bool showOfflineAction =
        syncStatus.pendingTotal > 0 || syncStatus.isFlushing;
    final Widget body = _buildScaffoldBody(
      hydrationEnabled: shouldUseHydrationGate,
      hydrationState: hydrationState,
    );
    final String? warningMessage = shouldUseHydrationGate && hydrationState.isReady
        ? hydrationState.warningMessage
        : null;
    final List<ResponsiveShellDestination> destinations =
        <ResponsiveShellDestination>[
      const ResponsiveShellDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Ana Sayfa',
      ),
      ResponsiveShellDestination(
        icon: badgeCount > 0
            ? Badge.count(
                count: badgeCount,
                child: const Icon(Icons.school_outlined),
              )
            : const Icon(Icons.school_outlined),
        selectedIcon: badgeCount > 0
            ? Badge.count(
                count: badgeCount,
                child: const Icon(Icons.school),
              )
            : const Icon(Icons.school),
        label: 'Kelime',
      ),
      const ResponsiveShellDestination(
        icon: Icon(Icons.chrome_reader_mode_outlined),
        selectedIcon: Icon(Icons.chrome_reader_mode),
        label: 'Okuma',
      ),
      const ResponsiveShellDestination(
        icon: Icon(Icons.auto_stories_outlined),
        selectedIcon: Icon(Icons.auto_stories),
        label: 'Gramer',
      ),
      const ResponsiveShellDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Profil',
      ),
    ];

    return ResponsiveShellScaffold(
      title: _titleForIndex(_index),
      selectedIndex: _index,
      destinations: destinations,
      onDestinationSelected: (int value) {
        setState(() {
          _index = value;
        });
      },
      actions: <Widget>[
        if (showOfflineAction)
          OfflineSyncStatusAction(
            status: syncStatus,
            onPressed: _openOfflineStatusSheet,
          ),
      ],
      topBanner: warningMessage == null || warningMessage.trim().isEmpty
          ? null
          : _HydrationWarningBar(message: warningMessage),
      body: body,
    );
  }

  Future<void> _openOfflineStatusSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const OfflineSyncStatusSheet(),
    );
  }

  Widget _buildScaffoldBody({
    required bool hydrationEnabled,
    required ContentHydrationState hydrationState,
  }) {
    final Widget currentBody = _buildBodyForIndex(_index);
    final bool gateCurrentTab = hydrationEnabled && _index != 4;

    Widget resolvedBody = currentBody;
    if (gateCurrentTab) {
      resolvedBody = _ContentHydrationGate(
        state: hydrationState,
        onRetry: () {
          ref.read(contentHydrationControllerProvider.notifier).retry();
        },
        child: currentBody,
      );
    }
    return resolvedBody;
  }
}

class OfflineSyncStatusAction extends StatelessWidget {
  const OfflineSyncStatusAction({
    required this.status,
    required this.onPressed,
    super.key,
  });

  final OfflineSyncStatus status;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Widget icon = Icon(
      status.isFlushing ? Icons.sync_rounded : Icons.cloud_off_rounded,
      color: Theme.of(context).colorScheme.onSurface,
    );

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: IconButton(
        tooltip: 'Senkron durumu',
        onPressed: onPressed,
        icon: status.pendingTotal > 0
            ? Badge.count(
                count: status.pendingTotal,
                child: icon,
              )
            : icon,
      ),
    );
  }
}

class OfflineSyncStatusSheet extends ConsumerWidget {
  const OfflineSyncStatusSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OfflineSyncStatus status = ref.watch(offlineSyncStatusProvider);
    final OfflineSyncController controller =
        ref.watch(offlineSyncControllerProvider.notifier);
    final String lastFlushText = status.lastFlushAtMillis == null
        ? 'Henüz başarılı bir senkron yok.'
        : _formatTimestamp(status.lastFlushAtMillis!);
    final String headline = status.isFlushing
        ? 'Kayıtlar şu an senkronlanıyor.'
        : 'Çevrimdışı kayıtlar cihazda tutuluyor.';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Senkron Durumu',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              headline,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            _StatusRow(
              icon: Icons.chrome_reader_mode_outlined,
              label: 'Bekleyen okuma kaydı',
              value: '${status.pendingReadingCount}',
            ),
            const SizedBox(height: 10),
            _StatusRow(
              icon: Icons.school_outlined,
              label: 'Bekleyen kelime olayı',
              value: '${status.pendingWordEventCount}',
            ),
            const SizedBox(height: 10),
            _StatusRow(
              icon: Icons.history_toggle_off_rounded,
              label: 'Son başarılı senkron',
              value: lastFlushText,
            ),
            if (status.droppedCount > 0) ...<Widget>[
              const SizedBox(height: 10),
              _StatusRow(
                icon: Icons.warning_amber_rounded,
                label: 'Düşürülen kayıt',
                value: '${status.droppedCount}',
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: status.isFlushing
                  ? null
                  : () async {
                      try {
                        await controller.flushPending(
                          silent: false,
                          force: true,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Senkron denemesi başlatıldı.'),
                            ),
                          );
                        }
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error.toString())),
                          );
                        }
                      }
                    },
              icon: Icon(
                status.isFlushing
                    ? Icons.sync_rounded
                    : Icons.cloud_upload_outlined,
              ),
              label: Text(
                  status.isFlushing ? 'Senkronlanıyor' : 'Şimdi senkronla'),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTimestamp(int millis) {
    final DateTime date = DateTime.fromMillisecondsSinceEpoch(millis);
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${date.day}.${date.month}.${date.year} '
        '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}

class _ContentHydrationGate extends StatelessWidget {
  const _ContentHydrationGate({
    required this.state,
    required this.onRetry,
    required this.child,
  });

  final ContentHydrationState state;
  final VoidCallback onRetry;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (state.isReady) {
      return child;
    }

    if (state.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.error_outline_rounded,
                  size: 40,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Yerel icerik hazirlanamadi',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  state.errorMessage ?? 'Bilinmeyen hata',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Tekrar Dene'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Web verisi hazirlaniyor',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                state.message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: state.progress <= 0 ? null : state.progress,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HydrationWarningBar extends StatelessWidget {
  const _HydrationWarningBar({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
