import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/student_providers.dart';
import '../common/page_parts.dart';

class StudentChangelogPage extends ConsumerWidget {
  const StudentChangelogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessContext = ref.watch(studentAccessProvider);
    final latestRelease = releaseCatalog.first;

    return StudentShellFrame(
      destination: StudentDestination.changelog,
      title: 'Surum Notlari',
      subtitle:
          'Canlidaki guncel ve onceki yayin notlarini bu sayfada takip edebilirsin.',
      accessContext: accessContext,
      browserTitle: 'Surum Notlari',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReleaseHeroCard(entry: latestRelease),
          const SizedBox(height: 24),
          const StudentSectionTitle(title: 'Yayin Gecmisi'),
          const SizedBox(height: 16),
          for (var index = 0; index < releaseCatalog.length; index++) ...[
            _ReleaseEntryCard(entry: releaseCatalog[index]),
            if (index != releaseCatalog.length - 1) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _ReleaseHeroCard extends StatelessWidget {
  const _ReleaseHeroCard({required this.entry});

  final ReleaseNoteEntry entry;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return StudentSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ReleasePill(
                label: entry.version,
                color: tokens.accent,
                foreground: Colors.white,
              ),
              _ReleasePill(
                label: entry.releaseDate,
                color: tokens.accentSoft,
                foreground: tokens.primaryText,
              ),
              _ReleasePill(
                label: 'Canli surum',
                color: tokens.hero.withValues(alpha: 0.14),
                foreground: tokens.hero,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(entry.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 10),
          Text(entry.summary, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _ReleaseEntryCard extends StatelessWidget {
  const _ReleaseEntryCard({required this.entry});

  final ReleaseNoteEntry entry;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return StudentSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.version,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.releaseDate,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(
                        color: tokens.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              if (entry.isCurrent)
                _ReleasePill(
                  label: 'guncel',
                  color: tokens.success.withValues(alpha: 0.14),
                  foreground: tokens.success,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(entry.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(entry.summary, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          for (final highlight in entry.highlights) ...[
            _ReleaseBullet(text: highlight),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _ReleasePill extends StatelessWidget {
  const _ReleasePill({
    required this.label,
    required this.color,
    required this.foreground,
  });

  final String label;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ReleaseBullet extends StatelessWidget {
  const _ReleaseBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: tokens.accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    );
  }
}
