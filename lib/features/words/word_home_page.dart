import 'package:flutter/foundation.dart';
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

enum WordSearchFilter {
  all,
  wordCard,
  dictionary,
}

class WordHomePage extends ConsumerStatefulWidget {
  const WordHomePage({super.key});

  @override
  ConsumerState<WordHomePage> createState() => _WordHomePageState();
}

class _WordHomePageState extends ConsumerState<WordHomePage> {
  late final TextEditingController _queryController;
  late final FocusNode _queryFocusNode;

  bool _isSearching = false;
  String _submittedQuery = '';
  String? _error;
  WordItem? _matchedWord;
  DictionaryLookupResult? _lookupResult;
  WordSearchFilter _selectedFilter = WordSearchFilter.all;

  bool get _showResultsMode =>
      _isSearching || _submittedQuery.trim().isNotEmpty || _error != null;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController();
    _queryFocusNode = FocusNode(debugLabel: 'wordSearchField');
  }

  @override
  void dispose() {
    _queryController.dispose();
    _queryFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submitSearch({
    String? value,
    String source = 'button',
  }) async {
    if (_isSearching) {
      return;
    }

    final String raw = (value ?? _queryController.text).trim();
    if (raw.isEmpty) {
      _clearSearch();
      return;
    }

    _logSearchEvent('submit', query: raw, source: source);
    FocusScope.of(context).unfocus();

    setState(() {
      _isSearching = true;
      _submittedQuery = raw;
      _error = null;
      _matchedWord = null;
      _lookupResult = null;
      _selectedFilter = WordSearchFilter.all;
    });

    try {
      final WordRepository wordRepository = ref.read(wordRepositoryProvider);
      final DictionaryRepository dictionaryRepository = ref.read(
        dictionaryRepositoryProvider,
      );

      final String cardQuery = normalizeWordToken(raw);
      WordItem? word;
      DictionaryLookupResult lookup = DictionaryLookupResult.empty();
      Object? wordError;
      Object? dictionaryError;

      await Future.wait(<Future<void>>[
        Future<void>(() async {
          if (cardQuery.isEmpty) {
            return;
          }
          try {
            word = await wordRepository.getWordByEnWordGlobal(cardQuery);
          } catch (error) {
            wordError = error;
          }
        }),
        Future<void>(() async {
          try {
            lookup = await dictionaryRepository.lookup(query: raw);
          } catch (error) {
            dictionaryError = error;
            lookup = DictionaryLookupResult.error(error.toString());
          }
        }),
      ]);

      if (!mounted) {
        return;
      }

      if (wordError != null && dictionaryError != null) {
        throw dictionaryError!;
      }

      final String resultType = _resolveSearchResultType(
        word: word,
        lookup: lookup,
      );
      _logSearchEvent(
        'result',
        query: raw,
        source: source,
        result: resultType,
      );

      setState(() {
        _matchedWord = word;
        _lookupResult = lookup;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      _logSearchEvent('result', query: raw, source: source, result: 'error');
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

  void _clearSearch() {
    _queryFocusNode.unfocus();
    setState(() {
      _queryController.clear();
      _submittedQuery = '';
      _error = null;
      _matchedWord = null;
      _lookupResult = null;
      _selectedFilter = WordSearchFilter.all;
      _isSearching = false;
    });
  }

  void _logSearchEvent(
    String event, {
    required String query,
    required String source,
    String? result,
  }) {
    if (!kDebugMode && !kProfileMode) {
      return;
    }

    final StringBuffer buffer = StringBuffer(
      'WordHomePage search $event query="$query" source=$source',
    );
    if (result != null && result.trim().isNotEmpty) {
      buffer.write(' result=$result');
    }
    debugPrint(buffer.toString());
  }

  String _resolveSearchResultType({
    required WordItem? word,
    required DictionaryLookupResult lookup,
  }) {
    if (word != null) {
      return 'word';
    }
    if (_lookupHasVisibleContent(lookup) || lookup.hasError) {
      return 'dictionary';
    }
    return 'empty';
  }

  bool _lookupHasVisibleContent(DictionaryLookupResult lookup) {
    return lookup.hasLocalEntries || lookup.hasFallback;
  }

  String _filterLabel(WordSearchFilter filter) {
    switch (filter) {
      case WordSearchFilter.all:
        return 'Tumu';
      case WordSearchFilter.wordCard:
        return 'Kelime Karti';
      case WordSearchFilter.dictionary:
        return 'Sozluk';
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
          child: Column(
            children: <Widget>[
              AppSurfaceCard(
                key: const ValueKey<String>('word-search-card'),
                variant: AppSurfaceVariant.feature,
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
                    TextField(
                      key: const ValueKey<String>('word-search-field'),
                      controller: _queryController,
                      focusNode: _queryFocusNode,
                      textInputAction: TextInputAction.search,
                      autocorrect: false,
                      enableSuggestions: false,
                      onSubmitted: (String value) => _submitSearch(
                        value: value,
                        source: 'keyboard',
                      ),
                      onEditingComplete: () => _submitSearch(
                        source: 'keyboard',
                      ),
                      onTapOutside: (_) => _queryFocusNode.unfocus(),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: TrUiTexts.wordSearchHint,
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const ValueKey<String>(
                          'word-search-submit-button',
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: _isSearching
                            ? null
                            : () => _submitSearch(source: 'button'),
                        icon: const Icon(Icons.search),
                        label: const Text(TrUiTexts.searchButton),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        key: const ValueKey<String>('word-level-hub-button'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const WordLevelHubPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.layers_outlined),
                        label: const Text(TrUiTexts.levelHubCta),
                      ),
                    ),
                    if (_queryController.text.trim().isNotEmpty ||
                        _showResultsMode) ...<Widget>[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          key:
                              const ValueKey<String>('word-search-clear-button'),
                          onPressed: _clearSearch,
                          child: const Text(TrUiTexts.clear),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _showResultsMode
              ? _buildResultsPane(context)
              : const PackListPage(embedded: true),
        ),
      ],
    );
  }

  Widget _buildResultsPane(BuildContext context) {
    return ListView(
      key: const ValueKey<String>('word-search-results-view'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      children: <Widget>[
        AppSurfaceCard(
          variant: AppSurfaceVariant.grouped,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _submittedQuery.trim().isEmpty
                          ? 'Arama Sonuclari'
                          : 'Arama Sonuclari: $_submittedQuery',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  if ((_dictionarySourceLabel(_lookupResult)).isNotEmpty)
                    Chip(
                      label: Text(_dictionarySourceLabel(_lookupResult)),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              if (_submittedQuery.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  'Filtre: ${_filterLabel(_selectedFilter)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 10),
                SegmentedButton<WordSearchFilter>(
                  key: const ValueKey<String>('word-search-filter-bar'),
                  showSelectedIcon: false,
                  segments: const <ButtonSegment<WordSearchFilter>>[
                    ButtonSegment<WordSearchFilter>(
                      value: WordSearchFilter.all,
                      label: Text('Tumu'),
                    ),
                    ButtonSegment<WordSearchFilter>(
                      value: WordSearchFilter.wordCard,
                      label: Text('Kelime Karti'),
                    ),
                    ButtonSegment<WordSearchFilter>(
                      value: WordSearchFilter.dictionary,
                      label: Text('Sozluk'),
                    ),
                  ],
                  selected: <WordSearchFilter>{_selectedFilter},
                  onSelectionChanged: (Set<WordSearchFilter> value) {
                    setState(() {
                      _selectedFilter = value.first;
                    });
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_isSearching) _buildLoadingCard(),
        if (!_isSearching && _error != null) _buildErrorCard(context),
        if (!_isSearching &&
            _error == null &&
            _submittedQuery.trim().isNotEmpty)
          ..._buildResultSections(context),
      ],
    );
  }

  Widget _buildLoadingCard() {
    return const AppSurfaceCard(
      variant: AppSurfaceVariant.grouped,
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

  Widget _buildErrorCard(BuildContext context) {
    return AppSurfaceCard(
      variant: AppSurfaceVariant.grouped,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => _submitSearch(source: 'retry'),
            child: const Text(TrUiTexts.retry),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildResultSections(BuildContext context) {
    final List<Widget> sections = <Widget>[];
    final bool showWordCard = _selectedFilter != WordSearchFilter.dictionary;
    final bool showDictionary = _selectedFilter != WordSearchFilter.wordCard;
    final DictionaryLookupResult lookup =
        _lookupResult ?? DictionaryLookupResult.empty();
    final bool hasWordResult = _matchedWord != null;
    final bool hasDictionaryResult =
        _lookupHasVisibleContent(lookup) || lookup.hasError;

    if (!hasWordResult &&
        !hasDictionaryResult &&
        showWordCard &&
        showDictionary) {
      return <Widget>[_buildNoResultsSection(context)];
    }

    if (showWordCard) {
      sections.add(
        _matchedWord != null
            ? _buildWordCardSection(context, _matchedWord!)
            : _buildWordCardEmptySection(context),
      );
    }

    if (showWordCard && showDictionary) {
      sections.add(const SizedBox(height: 8));
    }

    if (showDictionary) {
      sections.add(_buildDictionarySection(context));
    }

    return sections;
  }

  Widget _buildWordCardSection(BuildContext context, WordItem word) {
    final String level = (word.level ?? '').trim().toUpperCase();
    return AppSurfaceCard(
      key: const ValueKey<String>('word-card-result-section'),
      variant: AppSurfaceVariant.grouped,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Kelime Karti',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            word.enWord,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            word.trMeaning,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              Chip(
                label: Text(word.pos),
                visualDensity: VisualDensity.compact,
              ),
              if (level.isNotEmpty)
                Chip(
                  label: Text(level),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          if ((word.exampleEn).trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              word.exampleEn,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => WordDetailPage(word: word),
                ),
              );
            },
            icon: const Icon(Icons.style_outlined),
            label: const Text(TrUiTexts.wordCardButton),
          ),
        ],
      ),
    );
  }

  Widget _buildWordCardEmptySection(BuildContext context) {
    return AppSurfaceCard(
      key: const ValueKey<String>('word-card-empty-section'),
      variant: AppSurfaceVariant.grouped,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Kelime Karti',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            TrUiTexts.wordCardMissing,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsSection(BuildContext context) {
    return AppSurfaceCard(
      key: const ValueKey<String>('word-search-empty-results-section'),
      variant: AppSurfaceVariant.grouped,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Sonuc bulunamadi',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bu arama icin kelime karti veya sozluk sonucu bulunamadi.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildDictionarySection(BuildContext context) {
    final DictionaryLookupResult lookup =
        _lookupResult ?? DictionaryLookupResult.empty();
    final List<String> lines = dictionaryPreviewLines(lookup.entries, limit: 3);
    final String fallbackText = (lookup.fallbackTranslatedText ?? '').trim();
    final String errorText = (lookup.error ?? '').trim();
    final String sourceLabel = _dictionarySourceLabel(_lookupResult);

    return AppSurfaceCard(
      key: const ValueKey<String>('dictionary-result-section'),
      variant: AppSurfaceVariant.grouped,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Sozluk',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              if (sourceLabel.isNotEmpty)
                Chip(
                  label: Text(sourceLabel),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (lines.isNotEmpty)
            ...lines.map(
              (String line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(line),
              ),
            )
          else if (fallbackText.isNotEmpty)
            Text(
              fallbackText,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            )
          else if (errorText.isNotEmpty)
            Text(
              errorText,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            )
          else
            Text(
              'Bu sorgu icin sozluk sonucu bulunamadi.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _openDictionaryResult,
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text(TrUiTexts.dictionaryButton),
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
