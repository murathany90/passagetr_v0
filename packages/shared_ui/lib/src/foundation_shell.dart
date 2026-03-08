import 'package:flutter/material.dart';
import 'package:shared_core/shared_core.dart';

class FoundationShell extends StatelessWidget {
  const FoundationShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.sections,
  });

  final String title;
  final String subtitle;
  final List<String> sections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(title, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text(subtitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: 16),
              Text(
                'Durum: ${WorkspaceInfo.branchName} / ${WorkspaceInfo.architecture}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              for (final section in sections)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text(section),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
