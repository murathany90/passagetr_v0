import 'package:flutter/material.dart';

import '../../../core/widgets/app_surface_card.dart';
import '../word_search_filter.dart';

class WordResultsPanel extends StatelessWidget {
  const WordResultsPanel({
    required this.submittedQuery,
    required this.selectedFilter,
    required this.sourceLabel,
    required this.isSearching,
    required this.error,
    required this.loadingCard,
    required this.errorCard,
    required this.sections,
    required this.showInlineFilters,
    required this.onFilterSelected,
    super.key,
  });

  final String submittedQuery;
  final WordSearchFilter selectedFilter;
  final String sourceLabel;
  final bool isSearching;
  final String? error;
  final Widget loadingCard;
  final Widget errorCard;
  final List<Widget> sections;
  final bool showInlineFilters;
  final ValueChanged<WordSearchFilter> onFilterSelected;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey<String>('word-results-panel'),
      child: ListView(
        key: const ValueKey<String>('word-search-results-view'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
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
                        submittedQuery.trim().isEmpty
                            ? 'Arama Sonuclari'
                            : 'Arama Sonuclari: $submittedQuery',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (sourceLabel.isNotEmpty)
                      Chip(
                        label: Text(sourceLabel),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                if (submittedQuery.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    'Filtre: ${_filterLabel(selectedFilter)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (showInlineFilters) ...<Widget>[
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
                      selected: <WordSearchFilter>{selectedFilter},
                      onSelectionChanged: (Set<WordSearchFilter> value) {
                        onFilterSelected(value.first);
                      },
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (isSearching) loadingCard,
          if (!isSearching && error != null) errorCard,
          if (!isSearching && error == null && submittedQuery.trim().isNotEmpty)
            ...sections,
        ],
      ),
    );
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
}
