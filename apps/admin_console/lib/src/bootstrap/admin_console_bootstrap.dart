import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/admin_console_app.dart';
import '../core/admin_providers.dart';

class AdminConsoleBootstrap extends ConsumerStatefulWidget {
  const AdminConsoleBootstrap({super.key});

  @override
  ConsumerState<AdminConsoleBootstrap> createState() =>
      _AdminConsoleBootstrapState();
}

class _AdminConsoleBootstrapState extends ConsumerState<AdminConsoleBootstrap> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      try {
        await ref.read(adminAuthStateProvider.notifier).restoreSession();
      } catch (error) {
        debugPrint('admin_bootstrap_error:$error');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const AdminConsoleApp();
  }
}
