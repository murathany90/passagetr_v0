import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/tr_ui_texts.dart';
import '../../core/layout/app_breakpoints.dart';
import '../../core/layout/app_page_container.dart';
import '../../core/utils/word_selection_utils.dart';
import '../../core/widgets/app_surface_card.dart';
import '../../domain/entities/dictionary_lookup_result.dart';
import '../../domain/entities/word_item.dart';
import '../../domain/repositories/dictionary_repository.dart';
import '../../domain/repositories/word_repository.dart';
import '../../state/providers.dart';
import '../packs/pack_list_page.dart';
import 'widgets/word_pack_list_desktop.dart';
import 'widgets/word_results_panel.dart';
import 'widgets/word_search_sidebar.dart';
import 'word_search_filter.dart';
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

  Future<void> _submitSearch({String? value, String source = 'button'}) async {
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
      _logSearchEvent('result', query: raw, source: source, result: resultType);

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

  Future<void> _openDictionaryResult() async {
    final String query = _submittedQuery.trim();
    if (query.isEmpty) {
      return;
    }

    DictionaryLookupResult? lookup = _lookupResult;
    if (lookup == null) {
      final DictionaryRepository dictionaryRepository = ref.read(
        dictionaryRepositoryProvider,
      );
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
      builder: (_) =>
          DictionaryFallbackSheet(query: query, lookup: resolvedLookup),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageContainer(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool isDesktop = AppBreakpoints.isDesktopWidth(
            constraints.maxWidth,
          );
          return isDesktop
              ? _buildDesktopLayout(context)
              : _buildMobileLayout(context);
        },
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      key: const ValueKey<String>('word-home-mobile-layout'),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: WordSearchSidebar(
            queryController: _queryController,
            queryFocusNode: _queryFocusNode,
            onSubmitted: (String value) =>
                _submitSearch(value: value, source: 'keyboard'),
            onEditingComplete: () => _submitSearch(source: 'keyboard'),
            onTextChanged: () => setState(() {}),
            onSubmitPressed: () => _submitSearch(source: 'button'),
            onLevelHubPressed: _openLevelHub,
            onClearPressed: _clearSearch,
            isSearching: _isSearching,
            showClearAction:
                _queryController.text.trim().isNotEmpty || _showResultsMode,
            showFilters: false,
            selectedFilter: _selectedFilter,
            onFilterSelected: _onFilterSelected,
            resultSummary: _buildSearchSummary(),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _showResultsMode
              ? _buildResultsPane(context, showInlineFilters: true)
              : const PackListPage(embedded: true),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      key: const ValueKey<String>('word-home-desktop-layout'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          width: 344,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
            child: SingleChildScrollView(
              child: WordSearchSidebar(
                compact: true,
                queryController: _queryController,
                queryFocusNode: _queryFocusNode,
                onSubmitted: (String value) =>
                    _submitSearch(value: value, source: 'keyboard'),
                onEditingComplete: () => _submitSearch(source: 'keyboard'),
                onTextChanged: () => setState(() {}),
                onSubmitPressed: () => _submitSearch(source: 'button'),
                onLevelHubPressed: _openLevelHub,
                onClearPressed: _clearSearch,
                isSearching: _isSearching,
                showClearAction:
                    _queryController.text.trim().isNotEmpty || _showResultsMode,
                showFilters: _showResultsMode,
                selectedFilter: _selectedFilter,
                onFilterSelected: _onFilterSelected,
                resultSummary: _buildSearchSummary(),
              ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
            child: _showResultsMode
                ? _buildResultsPane(context, showInlineFilters: false)
                : const WordPackListDesktop(),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsPane(
    BuildContext context, {
    required bool showInlineFilters,
  }) {
    return WordResultsPanel(
      submittedQuery: _submittedQuery,
      selectedFilter: _selectedFilter,
      sourceLabel: _dictionarySourceLabel(_lookupResult),
      isSearching: _isSearching,
      error: _error,
      loadingCard: _buildLoadingCard(),
      errorCard: _buildErrorCard(context),
      sections:
          !_isSearching && _error == null && _submittedQuery.trim().isNotEmpty
          ? _buildResultSections(context)
          : const <Widget>[],
      showInlineFilters: showInlineFilters,
      onFilterSelected: _onFilterSelected,
    );
  }

  void _onFilterSelected(WordSearchFilter filter) {
    setState(() {
      _selectedFilter = filter;
    });
  }

  void _openLevelHub() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const WordLevelHubPage()));
  }

  String? _buildSearchSummary() {
    if (!_showResultsMode) {
      return null;
    }
    if (_isSearching) {
      return 'Arama yapiliyor...';
    }
    if (_error != null) {
      return 'Son arama tamamlanamadi.';
    }
    final String query = _submittedQuery.trim();
    if (query.isEmpty) {
      return null;
    }
    final DictionaryLookupResult lookup =
        _lookupResult ?? DictionaryLookupResult.empty();
    final bool hasWord = _matchedWord != null;
    final bool hasDictionary =
        _lookupHasVisibleContent(lookup) || lookup.hasError;

    if (!hasWord && !hasDictionary) {
      return '"$query" icin sonuc bulunamadi.';
    }
    if (hasWord && hasDictionary) {
      return '"$query" icin kelime karti ve sozluk sonucu hazir.';
    }
    if (hasWord) {
      return '"$query" icin kelime karti bulundu.';
    }
    return '"$query" icin sozluk sonucu bulundu.';
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
    final String? errorMessage = _error;
    if (errorMessage == null) {
      return const SizedBox.shrink();
    }
    return AppSurfaceCard(
      variant: AppSurfaceVariant.grouped,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            errorMessage,
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
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            word.enWord,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
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
              Chip(label: Text(word.pos), visualDensity: VisualDensity.compact),
              if (level.isNotEmpty)
                Chip(label: Text(level), visualDensity: VisualDensity.compact),
            ],
          ),
          if ((word.exampleEn).trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(word.exampleEn, maxLines: 2, overflow: TextOverflow.ellipsis),
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
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
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
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
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
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
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
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            )
          else if (errorText.isNotEmpty)
            Text(
              errorText,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
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
