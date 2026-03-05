import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/raw_splitter.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_error_state.dart';
import '../../core/widgets/app_shimmer_block.dart';
import '../../core/widgets/app_surface_card.dart';
import '../../domain/entities/pack.dart';
import '../../domain/entities/reading_passage.dart';
import '../../domain/entities/user_reading_progress.dart';
import '../../domain/repositories/reading_repository.dart';
import '../../domain/value_objects/paged_result.dart';
import '../../state/providers.dart';
import 'reading_detail_page.dart';
import 'reading_level_style.dart';
import 'reading_list_ui_state_store.dart';

class ReadingListPage extends ConsumerStatefulWidget {
  const ReadingListPage({required this.pack, super.key});

  final Pack pack;

  @override
  ConsumerState<ReadingListPage> createState() => _ReadingListPageState();
}

class _ReadingListPageState extends ConsumerState<ReadingListPage> {
  static const List<String> _allLevels = <String>[
    'A1',
    'A2',
    'B1',
    'B2',
    'C1',
    'C2',
  ];
  static const int _maxVisibleTagCount = 4;

  final ReadingListUiStateStore _uiStateStore = const ReadingListUiStateStore();
  final List<ReadingPassage> _items = <ReadingPassage>[];
  final ScrollController _scrollController = ScrollController();
  final Set<String> _selectedLevels = <String>{};
  final Map<String, bool> _completionOverrides = <String, bool>{};
  final Map<String, UserReadingProgress> _progressByPassage =
      <String, UserReadingProgress>{};

  int _offset = 0;
  bool _hasMore = true;
  bool _isInitialLoading = true;
  bool _isPageLoading = false;
  bool _isUiStateLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initializeUiState();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _initializeUiState() async {
    final ReadingLevelFilterState levelState =
        await _uiStateStore.loadLevelFilter(widget.pack.id);
    final ReadingCompletionOverrideState completionState =
        await _uiStateStore.loadCompletionOverrides(widget.pack.id);

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedLevels
        ..clear()
        ..addAll(levelState.selectedLevels);
      _completionOverrides
        ..clear()
        ..addAll(completionState.overrides);
      _isUiStateLoading = false;
    });

    await _loadInitial();
  }

  Future<void> _loadInitial() async {
    if (_isUiStateLoading) {
      return;
    }

    setState(() {
      _isInitialLoading = true;
      _isPageLoading = false;
      _error = null;
      _items.clear();
      _progressByPassage.clear();
      _offset = 0;
      _hasMore = true;
    });
    await _loadNextPage();
    if (mounted) {
      setState(() {
        _isInitialLoading = false;
      });
    }
  }

  Future<void> _loadNextPage() async {
    if (_isPageLoading || !_hasMore) {
      return;
    }

    setState(() {
      _isPageLoading = true;
      _error = null;
    });

    try {
      final PagedResult<ReadingPassage> page = await ref.read(
        readingListProvider(
          ReadingListRequest(
            packId: widget.pack.id,
            selectedLevels: _selectedLevels,
            limit: 20,
            offset: _offset,
          ),
        ).future,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _items.addAll(page.items);
        _offset = page.nextOffset;
        _hasMore = page.hasMore;
      });

      await _refreshProgressForPassages(
        page.items.map((ReadingPassage e) => e.id).toList(growable: false),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPageLoading = false;
        });
      }
    }
  }

  Future<void> _refreshProgressForPassages(List<String> passageIds) async {
    if (passageIds.isEmpty) {
      return;
    }
    final ReadingRepository repository = ref.read(readingRepositoryProvider);
    final Map<String, UserReadingProgress> latest =
        await repository.getProgressMapForPassages(passageIds);
    if (!mounted) {
      return;
    }
    setState(() {
      _progressByPassage.addAll(latest);
    });
  }

  Future<void> _toggleLevel(String level) async {
    final String normalized = level.trim().toUpperCase();
    setState(() {
      if (_selectedLevels.contains(normalized)) {
        _selectedLevels.remove(normalized);
      } else {
        _selectedLevels.add(normalized);
      }
    });
    await _uiStateStore.saveLevelFilter(
      packId: widget.pack.id,
      selectedLevels: _selectedLevels,
    );
    await _loadInitial();
  }

  Future<void> _clearLevels() async {
    if (_selectedLevels.isEmpty) {
      return;
    }
    setState(() {
      _selectedLevels.clear();
    });
    await _uiStateStore.saveLevelFilter(
      packId: widget.pack.id,
      selectedLevels: _selectedLevels,
    );
    await _loadInitial();
  }

  Future<void> _toggleCompletionOverride(String passageId) async {
    final bool autoCompleted = _progressByPassage[passageId]?.completed ?? false;
    setState(() {
      if (_completionOverrides.containsKey(passageId)) {
        _completionOverrides.remove(passageId);
      } else {
        _completionOverrides[passageId] = !autoCompleted;
      }
    });
    await _uiStateStore.saveCompletionOverrides(
      packId: widget.pack.id,
      overrides: _completionOverrides,
    );
  }

  bool _isCompleted(String passageId) {
    final bool autoCompleted = _progressByPassage[passageId]?.completed ?? false;
    final bool? manualOverride = _completionOverrides[passageId];
    return manualOverride ?? autoCompleted;
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final ScrollPosition position = _scrollController.position;
    if (position.maxScrollExtent <= 0) {
      return;
    }
    if (position.pixels >= position.maxScrollExtent - 260) {
      _loadNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.pack.name} - Paragraf Calis')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isUiStateLoading || _isInitialLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            AppShimmerCard(),
            SizedBox(height: 8),
            AppShimmerCard(),
            SizedBox(height: 8),
            AppShimmerCard(),
            SizedBox(height: 8),
            AppShimmerCard(),
          ],
        ),
      );
    }

    if (_error != null && _items.isEmpty) {
      return AppErrorState(
        title: 'Paragraf listesi yuklenemedi.',
        detail: _error!,
        onRetry: _loadInitial,
      );
    }

    if (_items.isEmpty) {
      return AppEmptyState(
        title: 'Bu filtreye uygun paragraf bulunamadi.',
        message: _selectedLevels.isEmpty
            ? 'Bu pack icin paragraf bulunamadi.'
            : 'Level filtresini temizleyip tekrar deneyin.',
        icon: Icons.menu_book_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref
            .read(offlineSyncControllerProvider.notifier)
            .flushPending(silent: true);
        await _loadInitial();
      },
      child: Column(
        children: <Widget>[
          _buildLevelFilterBar(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _items.length + 1,
              itemBuilder: (BuildContext context, int index) {
                if (index >= _items.length) {
                  if (_isPageLoading) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (_error != null) {
                    return Padding(
                      padding: const EdgeInsets.all(12),
                      child: OutlinedButton(
                        onPressed: _loadNextPage,
                        child: const Text('Sayfa yukleme hatasi - Retry'),
                      ),
                    );
                  }
                  if (_hasMore) {
                    return Padding(
                      padding: const EdgeInsets.all(12),
                      child: OutlinedButton(
                        onPressed: _loadNextPage,
                        child: const Text('Daha fazla yukle'),
                      ),
                    );
                  }
                  return const SizedBox(height: 20);
                }

                final ReadingPassage passage = _items[index];
                final List<String> tags = parseRawList(passage.tagsRaw);
                final bool completed = _isCompleted(passage.id);
                final bool hasManualOverride =
                    _completionOverrides.containsKey(passage.id);

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  child: AppSurfaceCard(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ReadingDetailPage(
                            passage: passage,
                            pack: widget.pack,
                          ),
                        ),
                      );
                      await _refreshProgressForPassages(<String>[passage.id]);
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                passage.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      height: 1.22,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: hasManualOverride
                                  ? 'Manuel tikli (tekrar tikla: otomatik moda don)'
                                  : 'Okundu durumunu elle degistir',
                              onPressed: () => _toggleCompletionOverride(passage.id),
                              visualDensity: VisualDensity.compact,
                              style: IconButton.styleFrom(
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: Icon(
                                completed
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                color: completed
                                    ? (hasManualOverride
                                        ? Theme.of(context).colorScheme.tertiary
                                        : Theme.of(context).colorScheme.primary)
                                    : Theme.of(context).colorScheme.outline,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.only(top: 5),
                              child: Icon(Icons.chevron_right, size: 20),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: <Widget>[
                            if ((passage.level ?? '').trim().isNotEmpty)
                              _buildLevelBadge(
                                context: context,
                                level: (passage.level ?? '').trim().toUpperCase(),
                              ),
                            if ((passage.category ?? '').trim().isNotEmpty)
                              _buildCompactChip(
                                context: context,
                                label: (passage.category ?? '').trim(),
                                icon: Icons.category_outlined,
                              ),
                            _buildCompactChip(
                              context: context,
                              label: completed ? 'Okundu' : 'Okunmadi',
                              icon: completed
                                  ? Icons.done_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              foregroundColor: completed
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                              backgroundColor: completed
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                            ),
                          ],
                        ),
                        if (tags.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 7),
                            child: Wrap(
                              spacing: 5,
                              runSpacing: 5,
                              children: _buildTagChips(context, tags),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'Level Filtresi',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _selectedLevels.isEmpty ? null : _clearLevels,
                child: const Text('Temizle'),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allLevels.map((String level) {
              final bool selected = _selectedLevels.contains(level);
              return FilterChip(
                label: Text(level),
                selected: selected,
                onSelected: (_) => _toggleLevel(level),
                selectedColor: ReadingLevelStyle.background(context, level),
                checkmarkColor: ReadingLevelStyle.foreground(level),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected
                          ? ReadingLevelStyle.foreground(level)
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
              );
            }).toList(growable: false),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildLevelBadge({
    required BuildContext context,
    required String level,
  }) {
    final Color fg = ReadingLevelStyle.foreground(level);
    final Color bg = ReadingLevelStyle.background(context, level);
    return Chip(
      avatar: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: fg,
          shape: BoxShape.circle,
        ),
      ),
      label: Text(level),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
      backgroundColor: bg,
      side: BorderSide(color: fg.withValues(alpha: 0.3)),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: fg,
            fontWeight: FontWeight.w800,
          ),
    );
  }

  Widget _buildCompactChip({
    required BuildContext context,
    required String label,
    IconData? icon,
    Color? foregroundColor,
    Color? backgroundColor,
  }) {
    final Color fg = foregroundColor ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Chip(
      avatar: icon == null
          ? null
          : Icon(
              icon,
              size: 14,
              color: fg,
            ),
      label: Text(label),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
      backgroundColor:
          backgroundColor ?? Theme.of(context).colorScheme.surfaceContainerHighest,
      side: BorderSide(color: fg.withValues(alpha: 0.18)),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: fg,
            fontWeight: FontWeight.w600,
          ),
    );
  }

  List<Widget> _buildTagChips(BuildContext context, List<String> tags) {
    final List<String> trimmed = tags
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty)
        .toList(growable: false);
    if (trimmed.isEmpty) {
      return const <Widget>[];
    }

    final List<String> visible = trimmed.length <= _maxVisibleTagCount
        ? trimmed
        : trimmed.take(_maxVisibleTagCount).toList(growable: false);
    final List<Widget> chips = visible
        .map((String tag) => _buildCompactChip(context: context, label: tag))
        .toList(growable: true);

    final int hiddenCount = trimmed.length - visible.length;
    if (hiddenCount > 0) {
      chips.add(
        _buildCompactChip(
          context: context,
          label: '+$hiddenCount',
          icon: Icons.more_horiz_rounded,
        ),
      );
    }
    return chips;
  }
}
