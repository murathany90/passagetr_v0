import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/admin_console_app.dart';
import '../core/admin_providers.dart';

class AdminConsoleBootstrap extends ConsumerWidget {
  const AdminConsoleBootstrap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(adminBootstrapProvider);

    return bootstrap.when(
      data: (_) => const AdminConsoleApp(),
      loading: () => const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (error, stackTrace) => MaterialApp(
        home: Scaffold(body: Center(child: Text(error.toString()))),
      ),
    );
  }
}
