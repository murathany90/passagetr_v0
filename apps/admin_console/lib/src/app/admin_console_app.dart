import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ui/shared_ui.dart';

import 'admin_console_router.dart';

class AdminConsoleApp extends ConsumerWidget {
  const AdminConsoleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(adminConsoleRouterProvider);

    return MaterialApp.router(
      title: 'PASSAGETR Admin Console',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}
