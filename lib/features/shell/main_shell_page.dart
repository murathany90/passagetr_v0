import 'package:flutter/material.dart';

import '../home/home_dashboard_page.dart';
import '../packs/pack_list_page.dart';
import '../profile/profile_page.dart';
import '../readings/reading_home_page.dart';

class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _index = 0;

  String _titleForIndex(int index) {
    return switch (index) {
      0 => 'Ana Sayfa',
      1 => 'Kelime',
      2 => 'Okuma',
      _ => 'Profil',
    };
  }

  Widget _buildBodyForIndex(int index) {
    return switch (index) {
      0 => const HomeDashboardPage(),
      1 => const PackListPage(embedded: true),
      2 => const ReadingHomePage(),
      _ => const ProfilePage(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

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
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Ana Sayfa',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'Kelime',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Okuma',
          ),
          NavigationDestination(
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
