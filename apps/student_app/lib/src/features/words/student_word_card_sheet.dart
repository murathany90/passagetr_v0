import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/interaction_guard.dart';
import '../../core/student_providers.dart';
import '../../core/tts/student_tts_controller.dart';
import '../../core/tts/student_tts_engine.dart';
import '../../core/tts/student_tts_icon_button.dart';
import '../common/page_parts.dart';

Future<void> showStudentWordCardSheet(
  BuildContext context, {
  required WordEntry initialWord,
  String? readingId,
}) async {
  await showGeneralDialog<void>(
    context: context,
    barrierLabel: 'Kelime kartini kapat',
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.54),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(dialogContext).viewInsets.bottom + 16,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  key: const ValueKey<String>('word_card_dismiss_area'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(dialogContext).pop(),
                  child: const SizedBox.expand(),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: GestureDetector(
                    onTap: () {},
                    child: SingleChildScrollView(
                      child: StudentWordCardSheet(
                        initialWord: initialWord,
                        readingId: readingId,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curvedAnimation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        ),
      );
    },
  );
}

class StudentWordCardSheet extends ConsumerStatefulWidget {
  const StudentWordCardSheet({
    super.key,
    required this.initialWord,
    this.readingId,
  });

  final WordEntry initialWord;
  final String? readingId;

  @override
  ConsumerState<StudentWordCardSheet> createState() =>
      _StudentWordCardSheetState();
}

class _StudentWordCardSheetState extends ConsumerState<StudentWordCardSheet> {
  late _WordSheetContent _content = _WordSheetContent.word(widget.initialWord);
  late final StudentTtsController _ttsController;
  bool _isResolvingRelated = false;
  bool _ownsTtsPlayback = false;

  @override
  void initState() {
    super.initState();
    _ttsController = ref.read(studentTtsControllerProvider.notifier);
  }

  @override
  void dispose() {
    if (_ownsTtsPlayback) {
      unawaited(
        _ttsController.stopIfMatching(
          target: StudentTtsTarget.word,
          readingId: widget.readingId,
          wordId: _content.word?.id,
        ),
      );
    }
    super.dispose();
  }

  Future<void> _openRelatedWord(String label) async {
    final normalizedQuery = _normalizeStudentWordQuery(label);
    if (normalizedQuery.isEmpty || _isResolvingRelated) {
      return;
    }

    final activeWord = _content.word;
    if (activeWord != null &&
        _normalizeStudentWordQuery(activeWord.enWord) == normalizedQuery) {
      return;
    }

    setState(() {
      _isResolvingRelated = true;
    });

    try {
      final cachedWords = ref.read(studentWordsProvider).valueOrNull;
      late final List<WordEntry> allWords;
      if (cachedWords != null) {
        allWords = cachedWords;
      } else {
        allWords = await ref.read(studentWordsProvider.future);
      }
      final matchedWord = _findWordCardByQuery(allWords, normalizedQuery);
      if (!mounted) {
        return;
      }

      if (matchedWord != null) {
        setState(() {
          _content = _WordSheetContent.word(matchedWord);
        });
        return;
      }

      final dictionaryEntry = await ref.read(
        studentDictionaryEntryProvider(normalizedQuery).future,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _content = dictionaryEntry != null
            ? _WordSheetContent.dictionary(
                query: label.trim(),
                dictionaryEntry: dictionaryEntry,
              )
            : _WordSheetContent.missing(query: label.trim());
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResolvingRelated = false;
        });
      }
    }
  }

  Future<void> _playWord(WordEntry word) async {
    final result = await _ttsController.playWord(
      word: word,
      readingId: widget.readingId,
    );
    if (!mounted) {
      return;
    }

    if (result == StudentTtsActionResult.started) {
      setState(() {
        _ownsTtsPlayback = true;
      });
      return;
    }

    _showTtsFeedback();
  }

  Future<void> _stopWord(WordEntry word) async {
    await _ttsController.stopIfMatching(
      target: StudentTtsTarget.word,
      readingId: widget.readingId,
      wordId: word.id,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _ownsTtsPlayback = false;
    });
  }

  void _showTtsFeedback() {
    final message =
        ref.read(studentTtsControllerProvider).errorMessage ??
        'Metin simdi okunamadi.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleFavorite(WordEntry word) async {
    final result = await ref
        .read(studentWordFavoritesProvider.notifier)
        .toggleFavorite(word.id);
    if (!mounted) {
      return;
    }

    final message = switch (result) {
      AppSuccess<void>() => 'Favori durumu guncellendi.',
      AppFailure<void>() => 'Favori durumu simdi guncellenemedi.',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final accessContext = ref.watch(studentAccessProvider);
    final word = _content.word;
    final favorite = word == null
        ? null
        : ref.watch(studentWordFavoriteByIdProvider(word.id));
    final canToggleFavorite = InteractionGuard.canPersist(accessContext);
    final dictionaryEntry = _content.dictionaryEntry;
    final synonyms = _splitWordList(word?.synonymsRaw);
    final antonyms = _splitWordList(word?.antonymsRaw);
    final title = word?.enWord ?? _content.query;
    final partOfSpeech = word?.pos ?? dictionaryEntry?.pos ?? '';
    final meaning = word?.trMeaning ?? dictionaryEntry?.trMeaning;
    final ttsState = ref.watch(studentTtsControllerProvider);
    final isPlayingWord =
        word != null &&
        ttsState.isSpeaking &&
        ttsState.activeTarget == StudentTtsTarget.word &&
        ttsState.activeWordId == word.id;
    final isInitializingWord =
        word != null &&
        ttsState.isInitializing &&
        ttsState.activeTarget == StudentTtsTarget.word &&
        ttsState.activeWordId == word.id;

    return StudentSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (word == null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.surfaceMuted,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Sozluk cevirisi',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: tokens.secondaryText,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_isResolvingRelated) ...[
                const Padding(
                  padding: EdgeInsets.only(top: 10, right: 8),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ],
              if (word != null)
                StudentTtsIconButton(
                  key: ValueKey<String>('word_card_tts_${word.id}'),
                  isSpeaking: isPlayingWord,
                  isInitializing: isInitializingWord,
                  isUnavailable: ttsState.isUnavailable,
                  tooltip: isPlayingWord ? 'Durdur' : 'Kelimeyi dinle',
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  onPlay: () => _playWord(word),
                  onStop: () => _stopWord(word),
                ),
              if (word != null)
                Tooltip(
                  message: canToggleFavorite
                      ? (favorite?.isFavorite ?? false)
                            ? 'Favorilerden cikar'
                            : 'Favorilere ekle'
                      : 'Favoriye eklemek icin giris yap',
                  child: IconButton(
                    key: ValueKey<String>('word_card_favorite_${word.id}'),
                    onPressed: canToggleFavorite
                        ? () => _toggleFavorite(word)
                        : null,
                    icon: Icon(
                      favorite?.isFavorite ?? false
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                    ),
                    tooltip: canToggleFavorite
                        ? (favorite?.isFavorite ?? false)
                              ? 'Favorilerden cikar'
                              : 'Favorilere ekle'
                        : 'Favoriye eklemek icin giris yap',
                  ),
                ),
              if (partOfSpeech.trim().isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(left: 4, right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.accentBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    partOfSpeech,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.accentBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              IconButton(
                key: const ValueKey<String>('word_card_close_button'),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Kapat',
              ),
            ],
          ),
          if (word != null && !canToggleFavorite) ...[
            const SizedBox(height: 6),
            Text(
              'Favoriye eklemek icin giris yap',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.secondaryText),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            meaning ?? 'Bu kelime icin ceviri bulunamadi.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (word != null &&
              (word.exampleEn.trim().isNotEmpty ||
                  (word.exampleTr?.trim().isNotEmpty ?? false))) ...[
            const SizedBox(height: 18),
            _WordCardSection(
              title: 'Ornek',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (word.exampleEn.trim().isNotEmpty)
                    Text(
                      word.exampleEn.trim(),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (word.exampleTr?.trim().isNotEmpty ?? false) ...[
                    const SizedBox(height: 8),
                    Text(
                      word.exampleTr!.trim(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tokens.secondaryText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (word != null && synonyms.isNotEmpty) ...[
            const SizedBox(height: 18),
            _WordCardSection(
              title: 'Es anlamli',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in synonyms)
                    _WordListChip(
                      label: item,
                      color: tokens.accentBlue,
                      onTap: () => _openRelatedWord(item),
                    ),
                ],
              ),
            ),
          ],
          if (word != null && antonyms.isNotEmpty) ...[
            const SizedBox(height: 18),
            _WordCardSection(
              title: 'Zit anlamli',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in antonyms)
                    _WordListChip(
                      label: item,
                      color: tokens.warning,
                      onTap: () => _openRelatedWord(item),
                    ),
                ],
              ),
            ),
          ],
          if (word != null && (word.notes?.trim().isNotEmpty ?? false)) ...[
            const SizedBox(height: 18),
            _WordCardSection(
              title: 'Not',
              child: Text(
                word.notes!.trim(),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: tokens.secondaryText),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WordSheetContent {
  const _WordSheetContent.word(this.word) : query = '', dictionaryEntry = null;

  const _WordSheetContent.dictionary({
    required this.query,
    required this.dictionaryEntry,
  }) : word = null;

  const _WordSheetContent.missing({required this.query})
    : word = null,
      dictionaryEntry = null;

  final WordEntry? word;
  final String query;
  final DictionaryEntry? dictionaryEntry;
}

class _WordCardSection extends StatelessWidget {
  const _WordCardSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _WordListChip extends StatelessWidget {
  const _WordListChip({required this.label, required this.color, this.onTap});

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

List<String> _splitWordList(String? rawValue) {
  if (rawValue == null || rawValue.trim().isEmpty) {
    return const <String>[];
  }

  final values = rawValue
      .split(RegExp(r'[,\n;|]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList(growable: false);
  values.sort();
  return values;
}

WordEntry? _findWordCardByQuery(List<WordEntry> words, String query) {
  for (final word in words) {
    if (_normalizeStudentWordQuery(word.enWord) == query) {
      return word;
    }
  }

  return null;
}

String _normalizeStudentWordQuery(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('’', "'")
      .replaceAll(_edgePunctuationPattern, '');
}

final RegExp _edgePunctuationPattern = RegExp(r'^[^A-Za-z0-9]+|[^A-Za-z0-9]+$');
