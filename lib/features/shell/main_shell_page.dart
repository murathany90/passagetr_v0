import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/offline_sync_controller.dart';
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
      ref.read(offlineSyncControllerProvider.notifier).flushPending(silent: true);
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
      ref.read(offlineSyncControllerProvider.notifier).flushPending(silent: true);
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
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final AsyncValue<int> weakCount = ref.watch(weakWordCountProvider);
    final int badgeCount = weakCount.valueOrNull ?? 0;
    final OfflineSyncStatus syncStatus = ref.watch(offlineSyncStatusProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_titleForIndex(_index))),
      body: Column(
        children: <Widget>[
          if (syncStatus.pendingTotal > 0) OfflineSyncBanner(status: syncStatus),
          Expanded(child: _buildBodyForIndex(_index)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int value) {
          setState(() {
            _index = value;
          });
        },
        destinations: <NavigationDestination>[
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Ana Sayfa',
          ),
          NavigationDestination(
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
          const NavigationDestination(
            icon: Icon(Icons.chrome_reader_mode_outlined),
            selectedIcon: Icon(Icons.chrome_reader_mode),
            label: 'Okuma',
          ),
          const NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories),
            label: 'Gramer',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
        surfaceTintColor: colorScheme.surfaceTint,
      ),
    );
  }
}

class OfflineSyncBanner extends StatelessWidget {
  const OfflineSyncBanner({required this.status, super.key});

  final OfflineSyncStatus status;

  @override
  Widget build(BuildContext context) {
    final String text = status.isFlushing
        ? 'Cevrimdisi kayitlar senkronlaniyor... (${status.pendingTotal})'
        : 'Cevrimdisi: ilerleme cihazda saklaniyor (${status.pendingTotal})';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            status.isFlushing ? Icons.sync : Icons.cloud_off_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
