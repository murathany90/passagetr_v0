import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_ui/shared_ui.dart';

void main() {
  runApp(const ProviderScope(child: StudentApp()));
}

final _routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const FoundationShell(
          title: 'PASSAGETR Student App',
          subtitle: 'v2 foundation student shell',
          sections: [
            'Shared package yapisi olusturuldu',
            'Student ve admin uygulamalari ayrildi',
            'Supabase ve offline data katmani sonraki fazda acilacak',
          ],
        ),
      ),
    ],
  );
});

class StudentApp extends ConsumerWidget {
  const StudentApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(_routerProvider);
    return MaterialApp.router(
      title: WorkspaceInfo.brandName,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
