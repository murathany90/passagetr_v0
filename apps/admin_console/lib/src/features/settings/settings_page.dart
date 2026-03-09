import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/admin_providers.dart';
import '../common/admin_page_parts.dart';

class AdminSettingsPage extends ConsumerWidget {
  const AdminSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessContext = ref.watch(adminAccessProvider);
    final config = ref.watch(adminAppConfigProvider);
    final audits = ref.watch(adminAuditLogProvider);

    return AdminShellFrame(
      destination: AdminDestination.settings,
      title: 'Ayarlar ve Audit',
      subtitle: 'Console konfigurasyonu, env durumu ve son yonetim kayitlari.',
      accessContext: accessContext,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= AppBreakpoints.desktop;
          final envPanel = AdminPanelCard(
            title: 'Sistem Ozeti',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SettingRow(
                  label: 'Environment',
                  value: config.environment.value,
                ),
                _SettingRow(
                  label: 'Platform',
                  value: config.platformMode.value,
                ),
                _SettingRow(
                  label: 'Supabase',
                  value: config.supabaseEnabled ? 'bagli' : 'preview',
                ),
                _SettingRow(label: 'Branch', value: config.branchName),
              ],
            ),
          );

          final auditPanel = AdminPanelCard(
            title: 'Audit Akisi',
            child: audits.when(
              data: (items) => Column(
                children: [
                  for (final item in items) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.title),
                      subtitle: Text(item.subtitle),
                      trailing: Text(item.timestampLabel),
                    ),
                    const Divider(height: 1),
                  ],
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Text(error.toString()),
            ),
          );

          if (!isWide) {
            return Column(
              children: [envPanel, const SizedBox(height: 16), auditPanel],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: envPanel),
              const SizedBox(width: 16),
              Expanded(child: auditPanel),
            ],
          );
        },
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: tokens.secondaryText),
            ),
          ),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
