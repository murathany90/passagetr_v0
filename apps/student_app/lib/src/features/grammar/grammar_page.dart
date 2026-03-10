import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/student_providers.dart';
import '../common/page_parts.dart';
import 'grammar_seed_data.dart';

class StudentGrammarPage extends ConsumerWidget {
  const StudentGrammarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessContext = ref.watch(studentAccessProvider);
    final modules = ref.watch(studentGrammarModulesProvider);
    final progressMap =
        ref.watch(studentGrammarProgressProvider).valueOrNull ??
        const <int, GrammarProgress>{};

    return StudentShellFrame(
      destination: StudentDestination.grammar,
      title: 'Gramer Modülleri',
      subtitle: 'İngilizce dilbilgisini adım adım ve sistematik olarak öğren.',
      accessContext: accessContext,
      body: modules.when(
        data: (items) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _GrammarIntroCard(),
            const SizedBox(height: 28),
            for (final item in items) ...[
              _GrammarModuleCard(
                module: item,
                seed: grammarSeedFor(item.id),
                progress: progressMap[item.id],
                accessContext: accessContext,
              ),
              const SizedBox(height: 18),
            ],
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Text(error.toString()),
      ),
    );
  }
}

class _GrammarIntroCard extends StatelessWidget {
  const _GrammarIntroCard();

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return StudentSurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tokens.accentBlue,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.menu_book_rounded, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gramer Nasıl Çalışılmalı?',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Text(
                  'Gramer konularını sırayla tamamlamanı öneririz. Her bölüm sonunda kısa bir quiz var. Free kullanıcılar kilitli modülleri yalnızca önizleyebilir.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: tokens.secondaryText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GrammarModuleCard extends StatelessWidget {
  const _GrammarModuleCard({
    required this.module,
    required this.seed,
    required this.progress,
    required this.accessContext,
  });

  final GrammarModule module;
  final GrammarModuleSeed seed;
  final GrammarProgress? progress;
  final AccessContext accessContext;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final isLocked =
        seed.state == GrammarModuleState.locked &&
        !accessContext.canViewPremium;
    final completedPages = progress?.completedPages ?? 0;
    final progressPercent = progress == null
        ? seed.progressPercent
        : ((completedPages / module.pageCount) * 100).round().clamp(0, 100);
    final isCompleted =
        progress?.completed ?? seed.state == GrammarModuleState.completed;

    return StudentSurfaceCard(
      minHeight: isCompleted || progressPercent > 0 ? 236 : 164,
      onTap: () => _handleTap(context, isLocked),
      child: Stack(
        children: [
          Positioned(
            right: 8,
            bottom: -12,
            child: Text(
              '${module.id}',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: tokens.surfaceMuted,
                fontSize: 96,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: seed.tint.withValues(alpha: isCompleted ? 0.18 : 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(
                  isCompleted ? Icons.check_circle_outline_rounded : seed.icon,
                  color: seed.tint,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '${module.id}. ${module.title}',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  height: 1.15,
                                  color: isLocked ? tokens.secondaryText : null,
                                ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: tokens.surfaceMuted,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            child: Text(
                              '${module.pageCount} Sayfa',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      module.description.isNotEmpty
                          ? module.description
                          : seed.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: tokens.secondaryText,
                      ),
                    ),
                    if (isCompleted || progressPercent > 0) ...[
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Text(
                            isCompleted ? 'TAMAMLANDI' : 'İLERLEME',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: tokens.secondaryText,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const Spacer(),
                          Text(
                            '$progressPercent%',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      StudentProgressBar(
                        value: progressPercent / 100,
                        color: isCompleted ? tokens.green : tokens.accent,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleTap(BuildContext context, bool isLocked) {
    if (isLocked) {
      context.go('/premium');
      return;
    }

    context.go('/grammar/${module.id}');
  }
}
