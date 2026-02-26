import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/pack.dart';
import '../../domain/entities/word_item.dart';
import '../../domain/repositories/word_repository.dart';
import '../../domain/value_objects/paged_result.dart';
import '../../state/providers.dart';
import 'word_detail_page.dart';

class WordListPage extends ConsumerStatefulWidget {
  const WordListPage({required this.pack, super.key});

  final Pack pack;

  @override
  ConsumerState<WordListPage> createState() => _WordListPageState();
}

class _WordListPageState extends ConsumerState<WordListPage> {
  late final TextEditingController _searchController;
  late final TextEditingController _tagController;
  late final ScrollController _scrollController;

  final List<WordItem> _items = <WordItem>[];
  bool _isInitialLoading = true;
  bool _isPageLoading = false;
  bool _hasMore = true;
  int _offset = 0;
  String? _errorMessage;
  String _selectedPos = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _tagController = TextEditingController();
    _scrollController = ScrollController()..addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tagController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isInitialLoading = true;
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
      final WordRepository repository = ref.read(wordRepositoryProvider);
      final PagedResult<WordItem> result = await repository.getWordsByPack(
        widget.pack.id,
        query: _searchController.text,
        pos: _selectedPos,
        tag: _tagController.text,
        limit: AppConstants.pageSize,
        offset: _offset,
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
    final double threshold = position.maxScrollExtent - 320;
    if (position.pixels >= threshold) {
      _loadNextPage();
    }
  }

  void _onFilterChanged() {
    _loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.pack.name} - Kelimeler')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Kelime ara (en_word)',
                suffixIcon: IconButton(
                  onPressed: () {
                    _searchController.clear();
                    _onFilterChanged();
                  },
                  icon: const Icon(Icons.clear),
                ),
              ),
              onSubmitted: (_) => _onFilterChanged(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedPos,
                    items: <DropdownMenuItem<String>>[
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('Tum POS'),
                      ),
                      ...AppConstants.posValues.map(
                        (String value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ),
                      ),
                    ],
                    onChanged: (String? value) {
                      setState(() {
                        _selectedPos = value ?? '';
                      });
                      _onFilterChanged();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _tagController,
                    decoration: InputDecoration(
                      hintText: 'Tag filtre',
                      suffixIcon: IconButton(
                        onPressed: () {
                          _tagController.clear();
                          _onFilterChanged();
                        },
                        icon: const Icon(Icons.clear),
                      ),
                    ),
                    onSubmitted: (_) => _onFilterChanged(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onFilterChanged,
        icon: const Icon(Icons.filter_alt),
        label: const Text('Uygula'),
      ),
    );
  }

  Widget _buildBody() {
    if (_isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('Kelimeler yuklenemedi.'),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loadInitial,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return const Center(child: Text('Sonuc bulunamadi'));
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
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (_errorMessage != null) {
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
            return const SizedBox(height: 24);
          }

          final WordItem word = _items[index];
          return ListTile(
            title: Text(word.enWord),
            subtitle: Text(word.trMeaning),
            trailing: Chip(label: Text(word.pos)),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => WordDetailPage(word: word),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
