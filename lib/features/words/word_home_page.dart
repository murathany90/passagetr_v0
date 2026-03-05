import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/tr_ui_texts.dart';
import '../../core/utils/word_selection_utils.dart';
import '../../core/widgets/app_surface_card.dart';
import '../../domain/entities/dictionary_lookup_result.dart';
import '../../domain/entities/word_item.dart';
import '../../domain/repositories/dictionary_repository.dart';
import '../../domain/repositories/word_repository.dart';
import '../../state/providers.dart';
import '../packs/pack_list_page.dart';
import 'widgets/dictionary_fallback_sheet.dart';
import 'word_detail_page.dart';
import 'word_level_hub_page.dart';

class WordHomePage extends ConsumerStatefulWidget {
  const WordHomePage({super.key});

  @override
  ConsumerState<WordHomePage> createState() => _WordHomePageState();
}

class _WordHomePageState extends ConsumerState<WordHomePage> {
  late final TextEditingController _queryController;

  bool _isSearching = false;
  String _submittedQuery = '';
  String? _error;
  WordItem? _matchedWord;
  DictionaryLookupResult? _lookupResult;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _submitSearch([String? value]) async {
    final String raw = (value ?? _queryController.text).trim();
    if (raw.isEmpty) {
      setState(() {
        _submittedQuery = '';
        _error = null;
        _matchedWord = null;
        _lookupResult = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _submittedQuery = raw;
      _error = null;
      _matchedWord = null;
      _lookupResult = null;
    });

    try {
      final WordRepository wordRepository = ref.read(wordRepositoryProvider);
      final DictionaryRepository dictionaryRepository = ref.read(
        dictionaryRepositoryProvider,
      );

      final String cardQuery = normalizeWordToken(raw);
      final WordItem? word = cardQuery.isEmpty
          ? null
          : await wordRepository.getWordByEnWordGlobal(cardQuery);
      final DictionaryLookupResult lookup = await dictionaryRepository.lookup(
        query: raw,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _matchedWord = word;
        _lookupResult = lookup;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = TrUiTexts.searchError;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${TrUiTexts.searchErrorPrefix} $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _openDictionaryResult() async {
    final String query = _submittedQuery.trim();
    if (query.isEmpty) {
      return;
    }

    DictionaryLookupResult? lookup = _lookupResult;
    if (lookup == null) {
      final DictionaryRepository dictionaryRepository =
          ref.read(dictionaryRepositoryProvider);
      lookup = await dictionaryRepository.lookup(query: query);
      if (!mounted) {
        return;
      }
      setState(() {
        _lookupResult = lookup;
      });
    }

    if (!mounted) {
      return;
    }
    final DictionaryLookupResult resolvedLookup = lookup;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DictionaryFallbackSheet(
        query: query,
        lookup: resolvedLookup,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: AppSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  TrUiTexts.wordSearchTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _queryController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: _submitSearch,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: TrUiTexts.wordSearchHint,
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _isSearching ? null : () => _submitSearch(),
                      child: const Text(TrUiTexts.searchButton),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const WordLevelHubPage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.layers_outlined),
                      label: const Text(TrUiTexts.levelHubCta),
                    ),
                    if (_queryController.text.trim().isNotEmpty)
                      TextButton(
                        onPressed: () {
                          _queryController.clear();
                          _submitSearch('');
                        },
                        child: const Text(TrUiTexts.clear),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: _buildSearchStateCard(context),
        ),
        const SizedBox(height: 8),
        const Expanded(
          child: PackListPage(embedded: true),
        ),
      ],
    );
  }

  Widget _buildSearchStateCard(BuildContext context) {
    if (_isSearching) {
      return const AppSurfaceCard(
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Expanded(child: Text(TrUiTexts.searching)),
          ],
        ),
      );
    }

    if (_submittedQuery.trim().isEmpty) {
      return const AppSurfaceCard(
        child: Text(
          TrUiTexts.searchInfo,
        ),
      );
    }

    if (_error != null) {
      return AppSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _submitSearch,
              child: const Text(TrUiTexts.retry),
            ),
          ],
        ),
      );
    }

    final bool hasWordCard = _matchedWord != null;
    final DictionaryLookupResult? lookup = _lookupResult;
    final String sourceLabel = _dictionarySourceLabel(lookup);

    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _submittedQuery,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          if (hasWordCard) ...<Widget>[
            Text(
              '${TrUiTexts.wordCardFoundPrefix} ${_matchedWord!.enWord} -> ${_matchedWord!.trMeaning}',
            ),
            const SizedBox(height: 8),
          ] else ...<Widget>[
            const Text(TrUiTexts.wordCardMissing),
            const SizedBox(height: 8),
          ],
          if (sourceLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Chip(
                label: Text(sourceLabel),
                visualDensity: VisualDensity.compact,
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (hasWordCard)
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => WordDetailPage(word: _matchedWord!),
                      ),
                    );
                  },
                  icon: const Icon(Icons.style_outlined),
                  label: const Text(TrUiTexts.wordCardButton),
                ),
              FilledButton.icon(
                onPressed: _openDictionaryResult,
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text(TrUiTexts.dictionaryButton),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _dictionarySourceLabel(DictionaryLookupResult? lookup) {
    if (lookup == null) {
      return '';
    }
    if (lookup.hasLocalEntries) {
      return TrUiTexts.sourceLocalDictionary;
    }
    if (lookup.fromServerCache) {
      return TrUiTexts.sourceServerCache;
    }
    if (lookup.fromDeepL) {
      return TrUiTexts.sourceDeepLFallback;
    }
    if (lookup.hasFallback) {
      return TrUiTexts.sourceFallback;
    }
    if (lookup.hasError) {
      return TrUiTexts.sourceError;
    }
    return '';
  }
}
