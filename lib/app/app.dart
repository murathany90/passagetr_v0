import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/bootstrap/bootstrap_page.dart';

class LearningApp extends StatelessWidget {
  const LearningApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'English Learning',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const BootstrapPage(),
    );
  }
}
