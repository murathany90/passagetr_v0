import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../grammar/grammar_home_page.dart';
import '../home/home_dashboard_page.dart';
import '../profile/profile_page.dart';
import '../readings/reading_home_page.dart';
import '../words/word_home_page.dart';
import '../../state/nav_badge_providers.dart';

class MainShellPage extends ConsumerStatefulWidget {
  const MainShellPage({super.key});

  @override
  ConsumerState<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends ConsumerState<MainShellPage> {
  int _index = 0;

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

    return Scaffold(
      appBar: AppBar(title: Text(_titleForIndex(_index))),
      body: _buildBodyForIndex(_index),
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
