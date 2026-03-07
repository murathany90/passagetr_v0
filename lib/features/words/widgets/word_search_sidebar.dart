import 'package:flutter/material.dart';

import '../../../core/i18n/tr_ui_texts.dart';
import '../../../core/widgets/app_surface_card.dart';
import '../word_search_filter.dart';

class WordSearchSidebar extends StatelessWidget {
  const WordSearchSidebar({
    required this.queryController,
    required this.queryFocusNode,
    required this.onSubmitted,
    required this.onEditingComplete,
    required this.onTextChanged,
    required this.onSubmitPressed,
    required this.onLevelHubPressed,
    required this.onClearPressed,
    required this.isSearching,
    required this.showClearAction,
    required this.showFilters,
    required this.selectedFilter,
    required this.onFilterSelected,
    this.resultSummary,
    this.compact = false,
    super.key,
  });

  final TextEditingController queryController;
  final FocusNode queryFocusNode;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onEditingComplete;
  final VoidCallback onTextChanged;
  final VoidCallback onSubmitPressed;
  final VoidCallback onLevelHubPressed;
  final VoidCallback onClearPressed;
  final bool isSearching;
  final bool showClearAction;
  final bool showFilters;
  final WordSearchFilter selectedFilter;
  final ValueChanged<WordSearchFilter> onFilterSelected;
  final String? resultSummary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      key: compact
          ? const ValueKey<String>('word-search-sidebar')
          : const ValueKey<String>('word-search-card'),
      variant: AppSurfaceVariant.feature,
      padding: EdgeInsets.all(compact ? 12 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            TrUiTexts.wordSearchTitle,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (resultSummary != null &&
              resultSummary!.trim().isNotEmpty) ...<Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                resultSummary!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          TextField(
            key: const ValueKey<String>('word-search-field'),
            controller: queryController,
            focusNode: queryFocusNode,
            textInputAction: TextInputAction.search,
            autocorrect: false,
            enableSuggestions: false,
            onSubmitted: onSubmitted,
            onEditingComplete: onEditingComplete,
            onTapOutside: (_) => queryFocusNode.unfocus(),
            onChanged: (_) => onTextChanged(),
            decoration: const InputDecoration(
              hintText: TrUiTexts.wordSearchHint,
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey<String>('word-search-submit-button'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: isSearching ? null : onSubmitPressed,
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
              onPressed: onLevelHubPressed,
              icon: const Icon(Icons.layers_outlined),
              label: const Text(TrUiTexts.levelHubCta),
            ),
          ),
          if (showClearAction) ...<Widget>[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const ValueKey<String>('word-search-clear-button'),
                onPressed: onClearPressed,
                child: const Text(TrUiTexts.clear),
              ),
            ),
          ],
          if (showFilters) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'Sonuclar',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
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
      ),
    );
  }
}
