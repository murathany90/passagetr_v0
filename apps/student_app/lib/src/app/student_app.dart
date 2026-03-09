import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ui/shared_ui.dart';

import '../core/student_providers.dart';
import 'student_router.dart';

class StudentApp extends ConsumerWidget {
  const StudentApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(studentRouterProvider);
    final themeMode = ref.watch(studentThemeModeProvider);

    return MaterialApp.router(
      title: 'PASSAGETR Student',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
