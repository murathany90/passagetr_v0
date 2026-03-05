import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/i18n/tr_ui_texts.dart';
import '../../core/utils/pos_label_mapper.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_error_state.dart';
import '../../core/widgets/app_loading_block.dart';
import '../../core/widgets/app_surface_card.dart';
import '../../domain/entities/tag_count.dart';
import '../../domain/entities/word_item.dart';
import '../../domain/value_objects/paged_result.dart';
import '../../state/providers.dart';
import '../readings/reading_level_style.dart';
import 'word_detail_page.dart';

class WordLevelWordsPage extends ConsumerStatefulWidget {
  const WordLevelWordsPage({
    required this.level,
    super.key,
  });

  final String level;

  @override
  ConsumerState<WordLevelWordsPage> createState() => _WordLevelWordsPageState();
}

class _WordLevelWordsPageState extends ConsumerState<WordLevelWordsPage> {
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;

  final List<WordItem> _items = <WordItem>[];
  List<TagCount> _availableTags = <TagCount>[];

  String _selectedPos = '';
  String? _selectedTag;
  int _offset = 0;
  bool _hasMore = true;
  bool _isInitialLoading = true;
  bool _isPageLoading = false;
  bool _isTagsLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _scrollController = ScrollController()..addListener(_onScroll);
    _loadTags();
    _loadInitial();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadTags() async {
    setState(() {
      _isTagsLoading = true;
    });
    try {
      final List<TagCount> tags = await ref.read(
        wordLevelTagsProvider(
          WordLevelTagRequest(level: widget.level),
        ).future,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _availableTags = tags;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _availableTags = <TagCount>[];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isTagsLoading = false;
        });
      }
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isInitialLoading = true;
      _isPageLoading = false;
      _errorMessage = null;
      _items.clear();
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
      _errorMessage = null;
    });

    try {
      final PagedResult<WordItem> result = await ref.read(
        wordLevelWordsProvider(
          WordLevelListRequest(
            level: widget.level,
            query: _searchController.text,
            pos: _selectedPos,
            tag: _selectedTag,
            limit: AppConstants.pageSize,
            offset: _offset,
          ),
        ).future,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _items.addAll(result.items);
        _offset = result.nextOffset;
        _hasMore = result.hasMore;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPageLoading = false;
        });
      }
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final ScrollPosition position = _scrollController.position;
    if (position.maxScrollExtent <= 0) {
      return;
    }
    if (position.pixels >= position.maxScrollExtent - 280) {
      _loadNextPage();
    }
  }

  Future<void> _openTagSelector() async {
    final String? selected = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return _TagSelectorSheet(
          currentTag: _selectedTag,
          tags: _availableTags,
        );
      },
    );

    if (!mounted) {
      return;
    }
    if (selected == _selectedTag) {
      return;
    }
    setState(() {
      _selectedTag = selected;
    });
    await _loadInitial();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedPos = '';
      _selectedTag = null;
    });
    _loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    final String levelLabel = widget.level.trim().toUpperCase();
    final AsyncValue<List<String>> posValuesAsync = ref.watch(
      distinctPosValuesProvider(
        DistinctPosRequest(level: widget.level),
      ),
    );
    final List<String> posValues = _resolvePosValues(posValuesAsync);

    return Scaffold(
      appBar: AppBar(
        title: Text('$levelLabel Kelimeleri'),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Chip(
                      label: Text(levelLabel),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: ReadingLevelStyle.background(
                        context,
                        levelLabel,
                      ),
                      labelStyle:
                          Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: ReadingLevelStyle.foreground(levelLabel),
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text(TrUiTexts.clear),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: TrUiTexts.searchWordHint,
                    suffixIcon: IconButton(
                      onPressed: () {
                        _searchController.clear();
                        _loadInitial();
                      },
                      icon: const Icon(Icons.clear),
                    ),
                  ),
                  onSubmitted: (_) => _loadInitial(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedPos,
                        items: <DropdownMenuItem<String>>[
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text(TrUiTexts.allPos),
                          ),
                          ...posValues.map(
                            (String value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(PosLabelMapper.labelFor(value)),
                            ),
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: TrUiTexts.posFilterLabel,
                        ),
                        onChanged: (String? value) async {
                          setState(() {
                            _selectedPos = value ?? '';
                          });
                          await _loadInitial();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: _isTagsLoading ? null : _openTagSelector,
                        borderRadius: BorderRadius.circular(8),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: TrUiTexts.tagFilterLabel,
                            suffixIcon: Icon(Icons.arrow_drop_down),
                          ),
                          child: Text(
                            _isTagsLoading
                                ? TrUiTexts.tagLoading
                                : (_selectedTag == null
                                    ? TrUiTexts.allTags
                                    : _formatTagLabel(_selectedTag!)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isInitialLoading) {
      return const AppLoadingBlock(message: TrUiTexts.wordsLoading);
    }

    if (_errorMessage != null && _items.isEmpty) {
      return AppErrorState(
        title: TrUiTexts.wordListLoadError,
        detail: _errorMessage!,
        onRetry: _loadInitial,
      );
    }

    if (_items.isEmpty) {
      return const AppEmptyState(
        title: TrUiTexts.wordListEmptyTitle,
        message: TrUiTexts.wordListEmptyMessage,
        icon: Icons.search_off_rounded,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _items.length + 1,
        itemBuilder: (BuildContext context, int index) {
          if (index >= _items.length) {
            if (_isPageLoading) {
              return const Padding(
                padding: EdgeInsets.all(14),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (_errorMessage != null) {
              return Padding(
                padding: const EdgeInsets.all(12),
                child: OutlinedButton(
                  onPressed: _loadNextPage,
                  child: const Text(
                      '${TrUiTexts.wordsLoadMoreError} - ${TrUiTexts.retry}'),
                ),
              );
            }
            if (_hasMore) {
              return Padding(
                padding: const EdgeInsets.all(12),
                child: OutlinedButton(
                  onPressed: _loadNextPage,
                  child: const Text(TrUiTexts.wordsLoadMore),
                ),
              );
            }
            return const SizedBox(height: 20);
          }

          final WordItem word = _items[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: AppSurfaceCard(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => WordDetailPage(word: word),
                  ),
                );
              },
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          word.enWord,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          word.trMeaning,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Chip(
                        label: Text(PosLabelMapper.labelFor(word.pos)),
                        visualDensity: VisualDensity.compact,
                      ),
                      if ((word.level ?? '').trim().isNotEmpty)
                        Chip(
                          label: Text((word.level ?? '').trim().toUpperCase()),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: ReadingLevelStyle.background(
                            context,
                            word.level,
                          ),
                          labelStyle: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                                color: ReadingLevelStyle.foreground(word.level),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<String> _resolvePosValues(AsyncValue<List<String>> async) {
    final List<String>? values = async.valueOrNull;
    if (values != null && values.isNotEmpty) {
      return values;
    }
    return AppConstants.posValues;
  }
}

class _TagSelectorSheet extends StatefulWidget {
  const _TagSelectorSheet({
    required this.tags,
    required this.currentTag,
  });

  final List<TagCount> tags;
  final String? currentTag;

  @override
  State<_TagSelectorSheet> createState() => _TagSelectorSheetState();
}

class _TagSelectorSheetState extends State<_TagSelectorSheet> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String search = _searchController.text.trim().toLowerCase();
    final List<TagCount> filtered = widget.tags
        .where(
          (TagCount tag) =>
              search.isEmpty || tag.tag.toLowerCase().contains(search),
        )
        .toList(growable: false);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 14,
          right: 14,
          top: 10,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: TrUiTexts.searchTagHint,
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  ListTile(
                    title: const Text(TrUiTexts.allTags),
                    trailing: widget.currentTag == null
                        ? const Icon(Icons.check_rounded)
                        : null,
                    onTap: () => Navigator.of(context).pop(null),
                  ),
                  ...filtered.map(
                    (TagCount tag) => ListTile(
                      title: Text(_formatTagLabel(tag.tag)),
                      subtitle: Text('${tag.count} kelime'),
                      trailing: widget.currentTag == tag.tag
                          ? const Icon(Icons.check_rounded)
                          : null,
                      onTap: () => Navigator.of(context).pop(tag.tag),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTagLabel(String raw) {
  final List<String> parts = raw
      .trim()
      .split(RegExp(r'\s+'))
      .where((String e) => e.isNotEmpty)
      .map((String e) => e.trim())
      .toList(growable: false);

  if (parts.isEmpty) {
    return raw;
  }

  return parts
      .map(
        (String token) => token.isEmpty
            ? token
            : '${token[0].toUpperCase()}${token.substring(1).toLowerCase()}',
      )
      .join(' ');
}
