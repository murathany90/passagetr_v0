import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/layout/app_page_container.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_error_state.dart';
import '../../core/widgets/app_shimmer_block.dart';
import '../../core/widgets/app_surface_card.dart';
import '../../data/repositories/hybrid_grammar_repository.dart';
import '../../domain/entities/grammar_module.dart';
import '../../state/providers.dart';
import 'grammar_module_pages_page.dart';

class GrammarHomePage extends ConsumerStatefulWidget {
  const GrammarHomePage({super.key});

  @override
  ConsumerState<GrammarHomePage> createState() => _GrammarHomePageState();
}

class _GrammarHomePageState extends ConsumerState<GrammarHomePage> {
  static const String _lastModuleKey = 'grammar_last_module_id';
  static const String _lastPageKey = 'grammar_last_page_id';
  static const String _readPagesPrefix = 'grammar_read_pages_';

  int? _lastModuleId;
  int? _lastPageId;
  Map<int, int> _readPageCounts = const <int, int>{};
  bool _syncStarted = false;

  @override
  void initState() {
    super.initState();
    _loadResume();
    _startBackgroundSync();
  }

  Future<void> _loadResume() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    setState(() {
      _lastModuleId = prefs.getInt(_lastModuleKey);
      _lastPageId = prefs.getInt(_lastPageKey);
    });
  }

  Future<void> _loadProgressCounts(List<GrammarModule> modules) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<int, int> counts = <int, int>{};
    for (final GrammarModule module in modules) {
      final String key = '$_readPagesPrefix${module.id}';
      final List<String> readPages = prefs.getStringList(key) ?? <String>[];
      counts[module.id] = readPages.length;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _readPageCounts = counts;
    });
  }

  Future<void> _saveResume({required int moduleId, int? pageId}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastModuleKey, moduleId);
    if (pageId != null) {
      await prefs.setInt(_lastPageKey, pageId);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _lastModuleId = moduleId;
      if (pageId != null) {
        _lastPageId = pageId;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<GrammarModule>> modulesAsync = ref.watch(
      grammarModulesProvider,
    );

    return AppPageContainer(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool isDesktop = AppBreakpoints.isDesktopWidth(
            constraints.maxWidth,
          );
          final bool isWideDesktop = constraints.maxWidth >= 1480;
          final int gridColumns = isWideDesktop ? 4 : (isDesktop ? 3 : 2);
          final double? mainAxisExtent = isDesktop ? 170 : null;
          final double childAspectRatio = isDesktop ? 1.0 : 0.92;

          return modulesAsync.when(
            skipLoadingOnRefresh: true,
            skipLoadingOnReload: true,
            loading: () => Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                key: const ValueKey<String>('grammar-home-loading-grid'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: isDesktop ? 6 : 4,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridColumns,
                  mainAxisExtent: isDesktop ? 170 : null,
                  childAspectRatio: isDesktop ? 1.0 : 1.05,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemBuilder: (_, __) => const AppShimmerCard(lineCount: 3),
              ),
            ),
            error: (Object error, StackTrace stackTrace) {
              final bool localMissing = _isLocalMissingError(error);
              return AppErrorState(
                title: localMissing
                    ? 'Lokal icerik yok'
                    : 'Guncelleme alinamadi, lokal icerik kullaniliyor',
                detail: localMissing
                    ? 'Gramer paketi cihazda bulunamadi. Internete baglanip bir kez acmayi deneyin.'
                    : error.toString(),
                onRetry: () => ref.invalidate(grammarModulesProvider),
              );
            },
            data: (List<GrammarModule> modules) {
              if (modules.isEmpty) {
                return const AppEmptyState(
                  title: 'Gramer modulu bulunamadi',
                  message:
                      'Supabase grammar tablolarini ve yukleme scriptini kontrol edin.',
                  icon: Icons.menu_book_outlined,
                );
              }

              if (_readPageCounts.isEmpty && modules.isNotEmpty) {
                _loadProgressCounts(modules);
              }

              GrammarModule? resumeModule;
              if (_lastModuleId != null) {
                for (final GrammarModule item in modules) {
                  if (item.id == _lastModuleId) {
                    resumeModule = item;
                    break;
                  }
                }
              }

              final int totalPages = modules.fold<int>(
                0,
                (int sum, GrammarModule module) => sum + module.toplamSayfa,
              );

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(grammarModulesProvider);
                  await ref.read(grammarModulesProvider.future);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    if (isDesktop)
                      Row(
                        key: const ValueKey<String>(
                          'grammar-home-desktop-layout',
                        ),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            flex: 7,
                            child: _GrammarOverviewCard(
                              moduleCount: modules.length,
                              totalPages: totalPages,
                            ),
                          ),
                          if (resumeModule != null) ...<Widget>[
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 5,
                              child: _ResumeCard(
                                module: resumeModule,
                                onTap: () => _openModule(resumeModule!),
                              ),
                            ),
                          ],
                        ],
                      )
                    else if (resumeModule != null)
                      _ResumeCard(
                        module: resumeModule,
                        onTap: () => _openModule(resumeModule!),
                      ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      key: const ValueKey<String>('grammar-home-grid'),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: modules.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: gridColumns,
                        mainAxisExtent: mainAxisExtent,
                        childAspectRatio: childAspectRatio,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemBuilder: (BuildContext context, int index) {
                        final GrammarModule module = modules[index];
                        final int readCount = _readPageCounts[module.id] ?? 0;
                        return _ModuleCard(
                          module: module,
                          readPageCount: readCount,
                          onTap: () => _openModule(module),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openModule(GrammarModule module) async {
    await _saveResume(
      moduleId: module.id,
      pageId: _lastModuleId == module.id ? _lastPageId : null,
    );

    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GrammarModulePagesPage(
          module: module,
          initialPageId: _lastModuleId == module.id ? _lastPageId : null,
        ),
      ),
    );

    await _loadResume();
    final AsyncValue<List<GrammarModule>> modulesAsync = ref.read(
      grammarModulesProvider,
    );
    if (modulesAsync.hasValue) {
      await _loadProgressCounts(modulesAsync.value!);
    }
  }

  void _startBackgroundSync() {
    if (_syncStarted) {
      return;
    }
    _syncStarted = true;
    Future<void>.microtask(() async {
      final repository = ref.read(grammarRepositoryProvider);
      if (repository is! HybridGrammarRepository) {
        return;
      }
      try {
        await repository.syncIfStale();
        if (mounted) {
          ref.invalidate(grammarModulesProvider);
        }
      } catch (_) {
        // Non-blocking sync: UI should keep rendering local content.
      }
    });
  }

  bool _isLocalMissingError(Object error) {
    final String text = error.toString().toLowerCase();
    return text.contains('lokal gramer icerigi yok') ||
        text.contains('lokal icerik yok');
  }
}

class _GrammarOverviewCard extends StatelessWidget {
  const _GrammarOverviewCard({
    required this.moduleCount,
    required this.totalPages,
  });

  final int moduleCount;
  final int totalPages;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      variant: AppSurfaceVariant.feature,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Gramer Kutuphanesi',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Modulleri sirayla ilerlet, kaldigin yerden devam et ve ilerlemeni tek ekranda izle.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              Chip(
                label: Text('$moduleCount modul'),
                visualDensity: VisualDensity.compact,
              ),
              Chip(
                label: Text('$totalPages sayfa'),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.module,
    required this.readPageCount,
    required this.onTap,
  });

  final GrammarModule module;
  final int readPageCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = _parseColor(module.renk);
    final int total = module.toplamSayfa;
    final int read = readPageCount > total ? total : readPageCount;
    final double progress = total == 0 ? 0 : read / total;
    final bool isComplete = read >= total && total > 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Text(
                      module.icon,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const Spacer(),
                  if (isComplete)
                    Icon(
                      Icons.check_circle_rounded,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                module.baslik,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                '$read/$total sayfa',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: color.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    final String value = hex.trim().replaceFirst('#', '');
    final int colorValue = int.tryParse('FF$value', radix: 16) ?? 0xFF4776E6;
    return Color(colorValue);
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.module, required this.onTap});

  final GrammarModule module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      variant: AppSurfaceVariant.grouped,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.secondaryContainer.withValues(alpha: 0.9),
            child: Text(module.icon, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Son kaldigin yer',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  module.baslik,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.play_arrow_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}
