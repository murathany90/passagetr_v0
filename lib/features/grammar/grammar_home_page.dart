import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_error_state.dart';
import '../../core/widgets/app_loading_block.dart';
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

  int? _lastModuleId;
  int? _lastPageId;

  @override
  void initState() {
    super.initState();
    _loadResume();
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

  Future<void> _saveResume({
    required int moduleId,
    int? pageId,
  }) async {
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
    final AsyncValue<List<GrammarModule>> modulesAsync = ref.watch(grammarModulesProvider);

    return modulesAsync.when(
      loading: () => const AppLoadingBlock(message: 'Gramer modulleri yukleniyor...'),
      error: (Object error, StackTrace stackTrace) {
        return AppErrorState(
          title: 'Gramer modulleri yuklenemedi.',
          detail: error.toString(),
          onRetry: () => ref.invalidate(grammarModulesProvider),
        );
      },
      data: (List<GrammarModule> modules) {
        if (modules.isEmpty) {
          return const AppEmptyState(
            title: 'Gramer modulu bulunamadi',
            message: 'Supabase grammar tablolarini ve yukleme scriptini kontrol edin.',
            icon: Icons.menu_book_outlined,
          );
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

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(grammarModulesProvider);
            await ref.read(grammarModulesProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              if (resumeModule != null)
                Builder(
                  builder: (BuildContext context) {
                    final GrammarModule resume = resumeModule!;
                    return _ResumeCard(
                      module: resume,
                      onTap: () => _openModule(resume),
                    );
                  },
                ),
              if (resumeModule != null) const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: modules.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.05,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemBuilder: (BuildContext context, int index) {
                  final GrammarModule module = modules[index];
                  return _ModuleCard(
                    module: module,
                    onTap: () => _openModule(module),
                  );
                },
              ),
            ],
          ),
        );
      },
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
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.module,
    required this.onTap,
  });

  final GrammarModule module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = _parseColor(module.renk);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Text(module.icon, style: const TextStyle(fontSize: 18)),
              ),
              const Spacer(),
              Text(
                module.baslik,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                '${module.toplamSayfa} sayfa',
                style: Theme.of(context).textTheme.bodySmall,
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
  const _ResumeCard({
    required this.module,
    required this.onTap,
  });

  final GrammarModule module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: ListTile(
        onTap: onTap,
        leading: Text(module.icon, style: const TextStyle(fontSize: 22)),
        title: const Text('Son kaldigin yer'),
        subtitle: Text(module.baslik),
        trailing: const Icon(Icons.play_arrow_rounded),
      ),
    );
  }
}
