import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/home_dashboard_data.dart';
import '../../state/providers.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<HomeDashboardData> dashboard = ref.watch(
      homeDashboardProvider,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Profil',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text('Faz 3 minimal profil alani.'),
                const SizedBox(height: 12),
                dashboard.when(
                  loading: () => const Text('Bugun gorulen kelime: ...'),
                  error: (_, __) =>
                      const Text('Bugun gorulen kelime: veri alinamadi'),
                  data: (HomeDashboardData data) =>
                      Text('Bugun gorulen kelime: ${data.todayWordCount}'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
