import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/interaction_guard.dart';
import '../../core/student_providers.dart';
import '../../core/student_word_progress_controller.dart';
import '../../core/tts/student_tts_controller.dart';
import '../../core/tts/student_tts_engine.dart';
import '../../core/tts/student_tts_icon_button.dart';
import '../common/page_parts.dart';

class StudentFlashcardsPage extends ConsumerStatefulWidget {
  const StudentFlashcardsPage({super.key, this.packId});

  final String? packId;

  @override
  ConsumerState<StudentFlashcardsPage> createState() =>
      _StudentFlashcardsPageState();
}

class _StudentFlashcardsPageState extends ConsumerState<StudentFlashcardsPage> {
  int _currentIndex = 0;
  bool _showMeaning = false;
  int _knownCount = 0;
  int _unsureCount = 0;
  int _unknownCount = 0;
  late final StudentTtsController _ttsController;

  @override
  void initState() {
    super.initState();
    _ttsController = ref.read(studentTtsControllerProvider.notifier);
  }

  @override
  void dispose() {
    unawaited(_ttsController.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accessContext = ref.watch(studentAccessProvider);
    final words = ref.watch(studentWordsProvider);
    final progress = ref.watch(studentWordProgressProvider);

    return StudentDetailFrame(
      destination: StudentDestination.words,
      accessContext: accessContext,
      header: WordsStudyHeader(
        title: widget.packId == null
            ? 'Flashcard Calismasi'
            : 'Paket Flashcard Calismasi',
        subtitle: widget.packId == null
            ? 'Zayif kelimelerden baslayarak hizli tekrar yap.'
            : 'Secili paketteki kelimelerle hizli tekrar yap.',
        onBack: () => context.go(
          widget.packId == null ? '/words' : '/words/packs/${widget.packId}',
        ),
      ),
      body: words.when(
        data: (items) {
          final progressMap =
              progress.valueOrNull ?? const <String, WordProgress>{};
          final scopedWords = widget.packId == null
              ? items
              : items
                    .where((item) => item.packId == widget.packId)
                    .toList(growable: false);
          final orderedWords = [...scopedWords]
            ..sort((left, right) {
              final leftMastery = progressMap[left.id]?.mastery ?? 0;
              final rightMastery = progressMap[right.id]?.mastery ?? 0;
              return leftMastery.compareTo(rightMastery);
            });

          if (orderedWords.isEmpty) {
            return StudentSurfaceCard(
              child: Text(
                widget.packId == null
                    ? 'Calisilacak kelime bulunamadi.'
                    : 'Secili pakette calisilacak kelime bulunamadi.',
              ),
            );
          }

          if (_currentIndex >= orderedWords.length) {
            return _FlashcardCompletionCard(
              totalCount: orderedWords.length,
              knownCount: _knownCount,
              unsureCount: _unsureCount,
              unknownCount: _unknownCount,
              onRestart: () {
                setState(() {
                  _currentIndex = 0;
                  _showMeaning = false;
                  _knownCount = 0;
                  _unsureCount = 0;
                  _unknownCount = 0;
                });
              },
              onBack: () => context.go(
                widget.packId == null
                    ? '/words'
                    : '/words/packs/${widget.packId}',
              ),
            );
          }

          final word = orderedWords[_currentIndex];
          final currentProgress =
              progressMap[word.id] ??
              const WordProgress(wordId: '', mastery: 0, seenCount: 0);
          final favorite = ref.watch(studentWordFavoriteByIdProvider(word.id));
          final canToggleFavorite = InteractionGuard.canPersist(accessContext);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WordStudyProgressCard(
                currentIndex: _currentIndex + 1,
                totalCount: orderedWords.length,
                mastery: currentProgress.mastery,
                seenCount: currentProgress.seenCount,
              ),
              const SizedBox(height: 20),
              _FlashcardCard(
                word: word,
                showMeaning: _showMeaning,
                ttsState: ref.watch(studentTtsControllerProvider),
                isFavorite: favorite.isFavorite,
                canToggleFavorite: canToggleFavorite,
                favoriteHelperText: canToggleFavorite
                    ? null
                    : 'Favoriye eklemek icin giris yap',
                onToggle: () {
                  setState(() {
                    _showMeaning = !_showMeaning;
                  });
                },
                onPlayWord: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final result = await ref
                      .read(studentTtsControllerProvider.notifier)
                      .playWord(word: word);
                  if (!mounted ||
                      result == StudentTtsActionResult.started ||
                      result == StudentTtsActionResult.stopped) {
                    return;
                  }

                  final message =
                      ref.read(studentTtsControllerProvider).errorMessage ??
                      'Metin simdi okunamadi.';
                  messenger.showSnackBar(SnackBar(content: Text(message)));
                },
                onStopWord: () =>
                    ref.read(studentTtsControllerProvider.notifier).stop(),
                onFavoriteToggle: () async {
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  final result = await ref
                      .read(studentWordFavoritesProvider.notifier)
                      .toggleFavorite(word.id);
                  if (!mounted) {
                    return;
                  }

                  final message = result.isSuccess
                      ? 'Favori durumu guncellendi.'
                      : 'Favori durumu simdi guncellenemedi.';
                  scaffoldMessenger.showSnackBar(SnackBar(content: Text(message)));
                },
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide =
                      constraints.maxWidth >= AppBreakpoints.mobileWide;
                  final buttons = [
                    _AnswerButton(
                      label: 'Bilmiyorum',
                      subtitle: 'Tekrar kuyruguna ekle',
                      color: AppThemeTokens.of(context).pink,
                      onPressed: () => _recordAnswer(
                        word: word,
                        answer: WordStudyAnswer.unknown,
                      ),
                    ),
                    _AnswerButton(
                      label: 'Kararsizim',
                      subtitle: 'Bir kez daha goster',
                      color: AppThemeTokens.of(context).warning,
                      onPressed: () => _recordAnswer(
                        word: word,
                        answer: WordStudyAnswer.unsure,
                      ),
                    ),
                    _AnswerButton(
                      label: 'Biliyorum',
                      subtitle: 'Ustalik puanini yukselt',
                      color: AppThemeTokens.of(context).green,
                      onPressed: () => _recordAnswer(
                        word: word,
                        answer: WordStudyAnswer.known,
                      ),
                    ),
                  ];

                  if (!isWide) {
                    return Column(
                      children: [
                        for (final button in buttons) ...[
                          button,
                          const SizedBox(height: 12),
                        ],
                      ],
                    );
                  }

                  return Row(
                    children: [
                      for (var index = 0; index < buttons.length; index++) ...[
                        Expanded(child: buttons[index]),
                        if (index != buttons.length - 1)
                          const SizedBox(width: 12),
                      ],
                    ],
                  );
                },
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Text(error.toString()),
      ),
    );
  }

  Future<void> _recordAnswer({
    required WordEntry word,
    required WordStudyAnswer answer,
  }) async {
    final controller = ref.read(studentWordProgressProvider.notifier);
    await controller.recordFlashcardResult(word: word, answer: answer);
    if (!mounted) {
      return;
    }

    setState(() {
      _showMeaning = false;
      _currentIndex += 1;
      switch (answer) {
        case WordStudyAnswer.known:
          _knownCount += 1;
          break;
        case WordStudyAnswer.unsure:
          _unsureCount += 1;
          break;
        case WordStudyAnswer.unknown:
          _unknownCount += 1;
          break;
      }
    });
  }
}

class WordsStudyHeader extends StatelessWidget {
  const WordsStudyHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onBack,
    this.backLabel = 'Kelimelere Don',
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final String backLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return StudentSurfaceCard(
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.chevron_left_rounded),
            label: Text(backLabel),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: tokens.secondaryText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class WordStudyProgressCard extends StatelessWidget {
  const WordStudyProgressCard({
    super.key,
    required this.currentIndex,
    required this.totalCount,
    required this.mastery,
    required this.seenCount,
    this.itemLabel = 'Kart',
    this.footerText,
  });

  final int currentIndex;
  final int totalCount;
  final int mastery;
  final int seenCount;
  final String itemLabel;
  final String? footerText;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return StudentSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$itemLabel $currentIndex / $totalCount',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: tokens.badgeOrange.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Ustalik %$mastery',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.badgeOrange,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          StudentProgressBar(
            value: totalCount == 0 ? 0 : currentIndex / totalCount,
            color: tokens.accent,
          ),
          const SizedBox(height: 12),
          Text(
            footerText ?? 'Bu kelime simdiye kadar $seenCount kez calisildi.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: tokens.secondaryText),
          ),
        ],
      ),
    );
  }
}

class _FlashcardCard extends StatelessWidget {
  const _FlashcardCard({
    required this.word,
    required this.showMeaning,
    required this.ttsState,
    required this.isFavorite,
    required this.canToggleFavorite,
    required this.favoriteHelperText,
    required this.onToggle,
    required this.onPlayWord,
    required this.onStopWord,
    required this.onFavoriteToggle,
  });

  final WordEntry word;
  final bool showMeaning;
  final StudentTtsState ttsState;
  final bool isFavorite;
  final bool canToggleFavorite;
  final String? favoriteHelperText;
  final VoidCallback onToggle;
  final Future<void> Function() onPlayWord;
  final Future<void> Function() onStopWord;
  final Future<void> Function() onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final isSpeaking =
        ttsState.isSpeaking &&
        ttsState.activeTarget == StudentTtsTarget.word &&
        ttsState.activeWordId == word.id;
    final isInitializing =
        ttsState.isInitializing &&
        ttsState.activeTarget == StudentTtsTarget.word &&
        ttsState.activeWordId == word.id;

    return StudentSurfaceCard(
      onTap: onToggle,
      padding: EdgeInsets.zero,
      minHeight: 340,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
            AppThemeTokens.of(context).cardRadius,
          ),
          gradient: LinearGradient(
            colors: <Color>[
              tokens.surface,
              tokens.accentSoft.withValues(alpha: 0.28),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'On yuzde Ingilizce, arka yuzde anlam var',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: tokens.secondaryText),
              ),
              const SizedBox(height: 28),
              Text(
                showMeaning ? word.trMeaning : word.enWord,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 12),
              AnimatedOpacity(
                opacity: showMeaning ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Text(
                  showMeaning ? word.enWord : '',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: tokens.secondaryText),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.accentBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      word.pos,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tokens.accentBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StudentTtsIconButton(
                    key: ValueKey<String>('flashcard_tts_${word.id}'),
                    isSpeaking: isSpeaking,
                    isInitializing: isInitializing,
                    isUnavailable: ttsState.isUnavailable,
                    tooltip: isSpeaking ? 'Durdur' : 'Kelimeyi dinle',
                    onPlay: onPlayWord,
                    onStop: onStopWord,
                  ),
                  Tooltip(
                    message: canToggleFavorite
                        ? (isFavorite
                              ? 'Favorilerden cikar'
                              : 'Favorilere ekle')
                        : 'Favoriye eklemek icin giris yap',
                    child: IconButton(
                      key: ValueKey<String>('flashcard_favorite_${word.id}'),
                      onPressed: canToggleFavorite ? onFavoriteToggle : null,
                      icon: Icon(
                        isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                      ),
                      tooltip: canToggleFavorite
                          ? (isFavorite
                                ? 'Favorilerden cikar'
                                : 'Favorilere ekle')
                          : 'Favoriye eklemek icin giris yap',
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onToggle,
                    icon: const Icon(Icons.flip_to_back_rounded),
                    label: Text(showMeaning ? 'On yuze don' : 'Karti cevir'),
                  ),
                ],
              ),
              if (favoriteHelperText != null) ...[
                const SizedBox(height: 12),
                Text(
                  favoriteHelperText!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: tokens.secondaryText),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return StudentSurfaceCard(
      onTap: onPressed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: color),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _FlashcardCompletionCard extends StatelessWidget {
  const _FlashcardCompletionCard({
    required this.totalCount,
    required this.knownCount,
    required this.unsureCount,
    required this.unknownCount,
    required this.onRestart,
    required this.onBack,
  });

  final int totalCount;
  final int knownCount;
  final int unsureCount;
  final int unknownCount;
  final VoidCallback onRestart;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return StudentSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tur tamamlandi',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            '$totalCount kelime uzerinde calistin. Bildigin $knownCount, kararsiz kaldigin $unsureCount, tekrar isteyen $unknownCount.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              FilledButton(
                onPressed: onRestart,
                child: const Text('Tekrar Baslat'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: onBack,
                child: const Text('Kelime Merkezine Don'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
