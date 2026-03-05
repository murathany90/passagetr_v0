import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/tr_ui_texts.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_error_state.dart';
import '../../core/widgets/app_loading_block.dart';
import '../../core/widgets/app_surface_card.dart';
import '../../domain/entities/word_level_summary.dart';
import '../../state/providers.dart';
import '../readings/reading_level_style.dart';
import 'word_level_words_page.dart';

class WordLevelHubPage extends ConsumerWidget {
  const WordLevelHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<WordLevelSummary>> levelsAsync =
        ref.watch(wordLevelsProvider);

    return levelsAsync.when(
      loading: () => const AppLoadingBlock(message: TrUiTexts.levelsLoading),
      error: (Object error, StackTrace stack) => AppErrorState(
        title: TrUiTexts.levelListLoadError,
        detail: error.toString(),
        onRetry: () => ref.invalidate(wordLevelsProvider),
      ),
      data: (List<WordLevelSummary> levels) {
        if (levels.isEmpty) {
          return const AppEmptyState(
            title: TrUiTexts.levelEmptyTitle,
            message: TrUiTexts.levelEmptyMessage,
            icon: Icons.school_outlined,
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(wordLevelsProvider);
            await ref.read(wordLevelsProvider.future);
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(14),
            itemCount: levels.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (BuildContext context, int index) {
              final WordLevelSummary level = levels[index];
              return AppSurfaceCard(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => WordLevelWordsPage(level: level.level),
                    ),
                  );
                },
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color:
                            ReadingLevelStyle.background(context, level.level),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          level.level,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color:
                                    ReadingLevelStyle.foreground(level.level),
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _titleForLevel(level.level),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${level.wordCount} kelime',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _titleForLevel(String level) {
    switch (level.trim().toUpperCase()) {
      case 'A1':
        return TrUiTexts.levelA1Title;
      case 'A2':
        return TrUiTexts.levelA2Title;
      case 'B1':
        return TrUiTexts.levelB1Title;
      case 'B2':
        return TrUiTexts.levelB2Title;
      case 'C1':
        return TrUiTexts.levelC1Title;
      case 'C2':
        return TrUiTexts.levelC2Title;
      default:
        return TrUiTexts.levelTitleDefault;
    }
  }
}
