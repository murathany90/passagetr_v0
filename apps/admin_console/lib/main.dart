import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_ui/shared_ui.dart';

void main() {
  runApp(const ProviderScope(child: AdminConsoleApp()));
}

final _routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const FoundationShell(
          title: 'PASSAGETR Admin Console',
          subtitle: 'v2 foundation admin shell',
          sections: [
            'Admin CMS ayri app olarak konumlandi',
            'CRUD, preview ve publish akislari bu kabuk uzerinden eklenecek',
            'Web-oncelikli responsive shell sonraki fazda zenginlestirilecek',
          ],
        ),
      ),
    ],
  );
});

class AdminConsoleApp extends ConsumerWidget {
  const AdminConsoleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(_routerProvider);
    return MaterialApp.router(
      title: '${WorkspaceInfo.brandName} Admin',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
