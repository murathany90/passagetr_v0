import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/raw_splitter.dart';
import '../../domain/entities/pack.dart';
import '../../domain/entities/reading_passage.dart';
import '../../domain/value_objects/paged_result.dart';
import '../../state/providers.dart';
import 'reading_detail_page.dart';

class ReadingListPage extends ConsumerStatefulWidget {
  const ReadingListPage({required this.pack, super.key});

  final Pack pack;

  @override
  ConsumerState<ReadingListPage> createState() => _ReadingListPageState();
}

class _ReadingListPageState extends ConsumerState<ReadingListPage> {
  final List<ReadingPassage> _items = <ReadingPassage>[];
  final ScrollController _scrollController = ScrollController();

  int _offset = 0;
  bool _hasMore = true;
  bool _isInitialLoading = true;
  bool _isPageLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isInitialLoading = true;
      _isPageLoading = false;
      _error = null;
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
      _error = null;
    });

    try {
      final PagedResult<ReadingPassage> page = await ref.read(
        readingListProvider(
          ReadingListRequest(
            packId: widget.pack.id,
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
    if (_isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.error_outline, size: 36),
              const SizedBox(height: 8),
              const Text(
                'Paragraf listesi yuklenemedi.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _loadInitial, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.menu_book_outlined, size: 36),
              SizedBox(height: 8),
              Text(
                'Bu pack icin paragraf bulunamadi.',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4),
              Text(
                'CSV import adimlarini docs/supabase_readings_import.md dosyasindan kontrol edin.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
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

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              title: Text(passage.title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if ((passage.level ?? '').trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('Level: ${passage.level}'),
                    ),
                  if (tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: tags
                            .map((String tag) => Chip(label: Text(tag)))
                            .toList(growable: false),
                      ),
                    ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ReadingDetailPage(
                      passage: passage,
                      pack: widget.pack,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
