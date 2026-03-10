import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/admin_console_app.dart';
import '../core/admin_providers.dart';

class AdminConsoleBootstrap extends ConsumerWidget {
  const AdminConsoleBootstrap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(adminBootstrapProvider);
    if (bootstrap.hasError) {
      debugPrint('admin_bootstrap_error:${bootstrap.error}');
    }

    return const AdminConsoleApp();
  }
}
