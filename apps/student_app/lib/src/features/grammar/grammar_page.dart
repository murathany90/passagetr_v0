import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/student_providers.dart';
import '../common/page_parts.dart';

class StudentGrammarPage extends ConsumerStatefulWidget {
  const StudentGrammarPage({super.key});

  @override
  ConsumerState<StudentGrammarPage> createState() => _StudentGrammarPageState();
}

class _StudentGrammarPageState extends ConsumerState<StudentGrammarPage> {
  bool _isRefreshing = false;
  bool _hasTriggeredInitialRefresh = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || kIsWeb || _hasTriggeredInitialRefresh) {
        return;
      }
      _hasTriggeredInitialRefresh = true;
      _refreshContent(showFeedback: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final accessContext = ref.watch(studentAccessProvider);
    final modules = ref.watch(studentGrammarModulesProvider);
    final progressMap =
        ref.watch(studentGrammarProgressProvider).valueOrNull ??
        const <int, GrammarProgress>{};

    return StudentShellFrame(
      destination: StudentDestination.grammar,
      title: 'Gramer Konulari',
      subtitle:
          'Ingilizce dil bilgisini yapilandirilmis bir sekilde adim adim ogren.',
      accessContext: accessContext,
      browserTitle: 'Gramer Konulari',
      body: modules.when(
        data: (items) {
          if (items.isEmpty) {
            return _GrammarStateCard(
              title: 'Gramer konulari henuz hazir degil',
              message:
                  'Yeni moduller yayinlandiginda burada otomatik olarak gorunecek.',
              onRetry: () => _refreshContent(showFeedback: true),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GrammarIntroCard(
                moduleCount: items.length,
                isRefreshing: _isRefreshing,
                onRefresh: () => _refreshContent(showFeedback: true),
              ),
              const SizedBox(height: 24),
              _GrammarTimeline(modules: items, progressMap: progressMap),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _GrammarStateCard(
          title: 'Gramer konulari simdi yuklenemiyor',
          message:
              'Baglanti tekrar geldiginde bu sayfa yenilenecek. Biraz sonra tekrar dene.',
          onRetry: () => _refreshContent(showFeedback: true),
        ),
      ),
    );
  }

  Future<void> _refreshContent({required bool showFeedback}) async {
    if (_isRefreshing) {
      return;
    }

    setState(() {
      _isRefreshing = true;
    });

    final messenger = ScaffoldMessenger.maybeOf(context);
    final result = await ref
        .read(studentSyncRepositoryProvider)
        .syncNow(SyncScope.content);
    ref.invalidate(studentGrammarModulesProvider);

    if (!mounted) {
      return;
    }

    setState(() {
      _isRefreshing = false;
    });

    if (!showFeedback) {
      return;
    }

    if (result.isFailure) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Gramer icerigi simdi yenilenemedi.')),
      );
      return;
    }

    messenger?.showSnackBar(
      const SnackBar(content: Text('Gramer icerigi yenilendi.')),
    );
  }
}

class _GrammarIntroCard extends StatelessWidget {
  const _GrammarIntroCard({
    required this.moduleCount,
    required this.isRefreshing,
    required this.onRefresh,
  });

  final int moduleCount;
  final bool isRefreshing;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return StudentSurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: tokens.accentBlue.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.auto_stories_rounded, color: tokens.accentBlue),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sirali ama acik bir ogrenme akisi',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '$moduleCount canli gramer modulu su an veritabanindan geliyor. Tum moduller acik; ilerleme rozetleri kendi calisma durumuna gore guncellenir.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: tokens.secondaryText),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: isRefreshing ? null : () => onRefresh(),
                      icon: isRefreshing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded),
                      label: Text(
                        isRefreshing ? 'Yenileniyor' : 'Icerigi yenile',
                      ),
                    ),
                    Text(
                      'Android acilisinda zorunlu sync de calisir.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tokens.secondaryText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GrammarTimeline extends StatelessWidget {
  const _GrammarTimeline({required this.modules, required this.progressMap});

  final List<GrammarModule> modules;
  final Map<int, GrammarProgress> progressMap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return StudentSurfaceCard(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(tokens.cardRadius),
          gradient: LinearGradient(
            colors: [
              tokens.surface.withValues(alpha: 0.96),
              tokens.surfaceMuted.withValues(alpha: 0.82),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              if (isWide) {
                return Column(
                  children: [
                    for (var index = 0; index < modules.length; index++)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: index == modules.length - 1 ? 0 : 20,
                        ),
                        child: _WideTimelineRow(
                          key: ValueKey<String>(
                            'grammar_timeline_row_${modules[index].id}',
                          ),
                          module: modules[index],
                          progress: progressMap[modules[index].id],
                          visibleIndex: index + 1,
                          isLeftAligned: index.isEven,
                          isFirst: index == 0,
                          isLast: index == modules.length - 1,
                        ),
                      ),
                  ],
                );
              }

              return Column(
                children: [
                  for (var index = 0; index < modules.length; index++)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: index == modules.length - 1 ? 0 : 16,
                      ),
                      child: _CompactTimelineRow(
                        key: ValueKey<String>(
                          'grammar_timeline_row_${modules[index].id}',
                        ),
                        module: modules[index],
                        progress: progressMap[modules[index].id],
                        visibleIndex: index + 1,
                        isFirst: index == 0,
                        isLast: index == modules.length - 1,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WideTimelineRow extends StatelessWidget {
  const _WideTimelineRow({
    super.key,
    required this.module,
    required this.progress,
    required this.visibleIndex,
    required this.isLeftAligned,
    required this.isFirst,
    required this.isLast,
  });

  final GrammarModule module;
  final GrammarProgress? progress;
  final int visibleIndex;
  final bool isLeftAligned;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final accentColor = _grammarAccentColor(context, module.color);
    final status = _statusFor(progress);

    final card = _GrammarModuleCard(
      key: ValueKey<String>('grammar_timeline_card_${module.id}'),
      module: module,
      progress: progress,
      visibleIndex: visibleIndex,
      status: status,
      accentColor: accentColor,
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: isLeftAligned
                ? Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: card,
                  )
                : const SizedBox.shrink(),
          ),
          SizedBox(
            width: 88,
            child: _TimelineAxis(
              status: status,
              accentColor: accentColor,
              icon: _grammarIcon(module.icon),
              isFirst: isFirst,
              isLast: isLast,
            ),
          ),
          Expanded(
            child: isLeftAligned
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: card,
                  ),
          ),
        ],
      ),
    );
  }
}

class _CompactTimelineRow extends StatelessWidget {
  const _CompactTimelineRow({
    super.key,
    required this.module,
    required this.progress,
    required this.visibleIndex,
    required this.isFirst,
    required this.isLast,
  });

  final GrammarModule module;
  final GrammarProgress? progress;
  final int visibleIndex;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final accentColor = _grammarAccentColor(context, module.color);
    final status = _statusFor(progress);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 60,
            child: _TimelineAxis(
              status: status,
              accentColor: accentColor,
              icon: _grammarIcon(module.icon),
              isFirst: isFirst,
              isLast: isLast,
            ),
          ),
          Expanded(
            child: _GrammarModuleCard(
              key: ValueKey<String>('grammar_timeline_card_${module.id}'),
              module: module,
              progress: progress,
              visibleIndex: visibleIndex,
              status: status,
              accentColor: accentColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineAxis extends StatelessWidget {
  const _TimelineAxis({
    required this.status,
    required this.accentColor,
    required this.icon,
    required this.isFirst,
    required this.isLast,
  });

  final _GrammarModuleStatus status;
  final Color accentColor;
  final IconData icon;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final lineColor = tokens.surfaceBorder;
    final foreground = switch (status) {
      _GrammarModuleStatus.completed => tokens.green,
      _GrammarModuleStatus.inProgress => accentColor,
      _GrammarModuleStatus.ready => tokens.secondaryText,
    };

    return Column(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: 2,
              color: isFirst ? Colors.transparent : lineColor,
            ),
          ),
        ),
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: foreground.withValues(alpha: 0.18),
            shape: BoxShape.circle,
            border: Border.all(color: foreground.withValues(alpha: 0.55)),
          ),
          child: Icon(
            status == _GrammarModuleStatus.completed
                ? Icons.check_rounded
                : icon,
            size: 22,
            color: foreground,
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: 2,
              color: isLast ? Colors.transparent : lineColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _GrammarModuleCard extends StatelessWidget {
  const _GrammarModuleCard({
    super.key,
    required this.module,
    required this.progress,
    required this.visibleIndex,
    required this.status,
    required this.accentColor,
  });

  final GrammarModule module;
  final GrammarProgress? progress;
  final int visibleIndex;
  final _GrammarModuleStatus status;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final completedPages = progress?.completedPages ?? 0;
    final progressPercent = module.pageCount <= 0
        ? 0
        : ((completedPages / module.pageCount) * 100).round().clamp(0, 100);

    return StudentSurfaceCard(
      onTap: () => context.go('/grammar/${module.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Konu $visibleIndex',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              _StatusPill(status: status, accentColor: accentColor),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(_grammarIcon(module.icon), color: accentColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  module.title,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(height: 1.15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                Icons.menu_book_outlined,
                size: 18,
                color: tokens.secondaryText,
              ),
              const SizedBox(width: 8),
              Text(
                '${module.pageCount} sayfa',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: tokens.secondaryText),
              ),
            ],
          ),
          if (progressPercent > 0) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: StudentProgressBar(
                    value: progressPercent / 100,
                    color: accentColor,
                    backgroundColor: accentColor.withValues(alpha: 0.14),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '%$progressPercent',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.primaryText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Text(
            _ctaLabelFor(status),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: accentColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.accentColor});

  final _GrammarModuleStatus status;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final text = switch (status) {
      _GrammarModuleStatus.completed => 'Tamamlandi',
      _GrammarModuleStatus.inProgress => 'Devam Ediyor',
      _GrammarModuleStatus.ready => 'Hazir',
    };
    final color = switch (status) {
      _GrammarModuleStatus.completed => tokens.green,
      _GrammarModuleStatus.inProgress => accentColor,
      _GrammarModuleStatus.ready => tokens.secondaryText,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _GrammarStateCard extends StatelessWidget {
  const _GrammarStateCard({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return StudentSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 10),
          Text(message, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tekrar dene'),
          ),
        ],
      ),
    );
  }
}

enum _GrammarModuleStatus { completed, inProgress, ready }

_GrammarModuleStatus _statusFor(GrammarProgress? progress) {
  if (progress == null) {
    return _GrammarModuleStatus.ready;
  }
  if (progress.completed) {
    return _GrammarModuleStatus.completed;
  }
  if (progress.completedPages > 0) {
    return _GrammarModuleStatus.inProgress;
  }
  return _GrammarModuleStatus.ready;
}

String _ctaLabelFor(_GrammarModuleStatus status) {
  return switch (status) {
    _GrammarModuleStatus.completed => 'Tekrar ac',
    _GrammarModuleStatus.inProgress => 'Derse devam et',
    _GrammarModuleStatus.ready => 'Derse basla',
  };
}

Color _grammarAccentColor(BuildContext context, String rawColor) {
  final tokens = AppThemeTokens.of(context);
  final normalized = rawColor.trim().replaceFirst('#', '');
  if (normalized.length == 6) {
    final parsed = int.tryParse(normalized, radix: 16);
    if (parsed != null) {
      return Color(0xFF000000 | parsed);
    }
  }
  return tokens.accentBlue;
}

IconData _grammarIcon(String rawIcon) {
  switch (rawIcon.trim().toLowerCase()) {
    case 'schedule':
    case 'timer':
      return Icons.schedule_rounded;
    case 'school':
      return Icons.school_rounded;
    case 'quiz':
      return Icons.quiz_rounded;
    case 'description':
    case 'article':
      return Icons.description_outlined;
    case 'auto_stories':
      return Icons.auto_stories_rounded;
    case 'bookmark':
      return Icons.bookmark_rounded;
    case 'book':
    case 'menu_book':
    case '📘':
    case '📗':
    default:
      return Icons.menu_book_rounded;
  }
}
