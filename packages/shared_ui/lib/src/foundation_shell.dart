import 'package:flutter/material.dart';
import 'package:shared_core/shared_core.dart';

import 'app_breakpoints.dart';

class FoundationShell extends StatelessWidget {
  const FoundationShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.accessContext,
    this.actions = const <Widget>[],
  });

  final String title;
  final String subtitle;
  final Widget body;
  final AccessContext accessContext;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppBreakpoints.foundationMaxWidth,
          ),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(title, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text(subtitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _InfoChip(label: WorkspaceInfo.branchName),
                  _InfoChip(label: WorkspaceInfo.architecture),
                  _InfoChip(label: 'role=${accessContext.role.value}'),
                  _InfoChip(label: 'plan=${accessContext.plan.value}'),
                ],
              ),
              const SizedBox(height: 24),
              body,
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label));
  }
}
