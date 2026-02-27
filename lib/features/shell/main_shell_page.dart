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
    return Scaffold(
      appBar: AppBar(title: Text(_titleForIndex(_index))),
      body: _buildBodyForIndex(_index),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (int value) {
          setState(() {
            _index = value;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Ana Sayfa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.school_outlined),
            activeIcon: Icon(Icons.school),
            label: 'Kelime',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book),
            label: 'Okuma',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
