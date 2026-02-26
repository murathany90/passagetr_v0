import 'package:flutter/material.dart';

import '../features/bootstrap/bootstrap_page.dart';

class LearningApp extends StatelessWidget {
  const LearningApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'English Learning',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0C6D4F)),
        useMaterial3: true,
      ),
      home: const BootstrapPage(),
    );
  }
}
