import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/translation_service.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_error_state.dart';
import '../../core/widgets/app_gradient_cta_button.dart';
import '../../core/widgets/app_loading_block.dart';
import '../../core/widgets/app_section_header.dart';
import '../../core/widgets/app_surface_card.dart';
import '../../core/utils/word_selection_utils.dart';
import '../../domain/entities/pack.dart';
import '../../domain/entities/passage_sentence.dart';
import '../../domain/entities/reading_passage.dart';
import '../../domain/entities/sentence_translation.dart';
import '../../domain/entities/user_word_progress.dart';
import '../../domain/entities/word_item.dart';
import '../../domain/repositories/reading_repository.dart';
import '../../state/providers.dart';
import '../flashcard/flashcard_session_page.dart';
import 'widgets/interactive_sentence_text.dart';
import 'widgets/word_quick_view_sheet.dart';

class ReadingDetailPage extends ConsumerStatefulWidget {
  const ReadingDetailPage({
    required this.passage,
    required this.pack,
    this.initialLastIdx = 0,
    super.key,
  });

  final ReadingPassage passage;
  final Pack pack;
  final int initialLastIdx;

  @override
  ConsumerState<ReadingDetailPage> createState() => _ReadingDetailPageState();
}

class _ReadingDetailPageState extends ConsumerState<ReadingDetailPage> {
  final Set<String> _expandedSentenceIds = <String>{};
  final Set<String> _loadingTranslationIds = <String>{};
  final Map<String, String> _runtimeTranslations = <String, String>{};
  final Map<String, String> _translationErrors = <String, String>{};

  bool _loading = true;
  String? _error;
  List<PassageSentence> _sentences = <PassageSentence>[];

  int _lastIdx = 0;
  bool _completed = false;
  bool _savingProgress = false;
  bool _quickWordSheetOpen = false;

  bool _loadingPassageWords = true;
  String? _passageWordsError;
  List<WordItem> _passageWords = <WordItem>[];
  Map<String, UserWordProgress> _passageWordsProgress =
      <String, UserWordProgress>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _sentences = <PassageSentence>[];
      _expandedSentenceIds.clear();
      _loadingTranslationIds.clear();
      _runtimeTranslations.clear();
      _translationErrors.clear();
      _passageWords = <WordItem>[];
      _passageWordsProgress = <String, UserWordProgress>{};
      _loadingPassageWords = true;
      _passageWordsError = null;
    });

    try {
      final ReadingRepository readingRepository =
          ref.read(readingRepositoryProvider);
      final List<PassageSentence> rows = await readingRepository.getSentences(
        passageId: widget.passage.id,
      );

      final int maxIdx = rows.isEmpty
          ? 0
          : rows
              .map((PassageSentence e) => e.idx)
              .reduce((int a, int b) => a > b ? a : b);

      final progress = await readingRepository.getUserReadingProgress(
        passageId: widget.passage.id,
      );

      int nextLastIdx = widget.initialLastIdx;
      bool nextCompleted = false;
      if (progress != null) {
        nextLastIdx =
            progress.lastIdx > nextLastIdx ? progress.lastIdx : nextLastIdx;
        nextCompleted = progress.completed;
      }
      if (nextLastIdx > maxIdx) {
        nextLastIdx = maxIdx;
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _sentences = rows;
        _lastIdx = nextLastIdx;
        _completed = nextCompleted;
      });

      await readingRepository.upsertUserReadingProgress(
        passageId: widget.passage.id,
        lastIdx: _lastIdx,
        completed: _completed,
      );

      await _prefetchCachedTranslations();
      await _loadPassageWords();
      ref.invalidate(readingProgressProvider(widget.passage.id));
      ref.invalidate(homeDashboardProvider);
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
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadPassageWords() async {
    setState(() {
      _loadingPassageWords = true;
      _passageWordsError = null;
    });
    try {
      final List<WordItem> words = await ref.read(
        passageWordsProvider(widget.passage.id).future,
      );

      Map<String, UserWordProgress> progress =
          const <String, UserWordProgress>{};
      if (words.isNotEmpty) {
        progress = await ref.read(progressRepositoryProvider).getProgressMap(
              wordIds: words.map((WordItem e) => e.id).toList(growable: false),
            );
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _passageWords = words;
        _passageWordsProgress = progress;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _passageWordsError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingPassageWords = false;
        });
      }
    }
  }

  Future<void> _prefetchCachedTranslations() async {
    final TranslationService translationService =
        ref.read(translationServiceProvider);
    for (final PassageSentence sentence in _sentences) {
      if ((sentence.sentenceTr ?? '').trim().isNotEmpty) {
        continue;
      }
      try {
        final SentenceTranslation? cached = await ref.read(
          sentenceTranslationControllerProvider(
            SentenceTranslationLookup(
              sentenceId: sentence.id,
              provider: translationService.providerKey,
            ),
          ).future,
        );

        if (cached != null &&
            cached.translatedText.trim().isNotEmpty &&
            mounted) {
          setState(() {
            _runtimeTranslations[sentence.id] = cached.translatedText.trim();
          });
        }
      } catch (_) {
        // Ignore cache read failures for prefetch.
      }
    }
  }

  Future<void> _toggleTranslation(PassageSentence sentence) async {
    final bool isExpanded = _expandedSentenceIds.contains(sentence.id);
    if (isExpanded) {
      setState(() {
        _expandedSentenceIds.remove(sentence.id);
      });
      return;
    }

    setState(() {
      _expandedSentenceIds.add(sentence.id);
    });

    await _markProgress(sentence.idx);

    final String? inlineTr = sentence.sentenceTr?.trim();
    if (inlineTr != null && inlineTr.isNotEmpty) {
      return;
    }

    if ((_runtimeTranslations[sentence.id] ?? '').trim().isNotEmpty) {
      return;
    }

    await _translateAndCache(sentence);
  }

  Future<void> _translateAndCache(PassageSentence sentence) async {
    if (_loadingTranslationIds.contains(sentence.id)) {
      return;
    }

    final String text = sentence.sentenceEn.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      _loadingTranslationIds.add(sentence.id);
      _translationErrors.remove(sentence.id);
    });

    final TranslationService translationService =
        ref.read(translationServiceProvider);
    if (!translationService.isConfigured) {
      _handleTranslationError(
        sentenceId: sentence.id,
        message: 'Ceviri yapilandirilmadi.',
      );
      setState(() {
        _loadingTranslationIds.remove(sentence.id);
      });
      return;
    }

    try {
      final ReadingRepository repository = ref.read(readingRepositoryProvider);
      final SentenceTranslation? cached = await repository.getCachedTranslation(
        sentenceId: sentence.id,
        provider: translationService.providerKey,
        targetLang: 'tr',
      );

      if (cached != null && cached.translatedText.trim().isNotEmpty) {
        if (mounted) {
          setState(() {
            _runtimeTranslations[sentence.id] = cached.translatedText.trim();
          });
        }
        return;
      }

      final String translated = await translationService.translate(
        text: text,
        sourceLang: 'en',
        targetLang: 'tr',
      );

      await repository.saveTranslation(
        sentenceId: sentence.id,
        provider: translationService.providerKey,
        targetLang: 'tr',
        translatedText: translated,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _runtimeTranslations[sentence.id] = translated;
      });
    } catch (error) {
      _handleTranslationError(
        sentenceId: sentence.id,
        message: _toTranslationErrorMessage(error),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingTranslationIds.remove(sentence.id);
        });
      }
    }
  }

  String _toTranslationErrorMessage(Object error) {
    if (error is TranslationException) {
      return error.message;
    }
    return 'Ceviri alinamadi. Daha sonra tekrar dene.';
  }

  void _handleTranslationError({
    required String sentenceId,
    required String message,
  }) {
    if (!mounted) {
      return;
    }
    setState(() {
      _translationErrors[sentenceId] = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _markProgress(int idx) async {
    final int maxIdx = _maxIdx;
    final int normalized = idx > maxIdx ? maxIdx : idx;
    if (normalized <= _lastIdx && !_completed) {
      return;
    }
    final int nextLastIdx = normalized > _lastIdx ? normalized : _lastIdx;
    await _persistProgress(
      lastIdx: nextLastIdx,
      completed: _completed,
    );
  }

  Future<void> _advanceProgress() async {
    final int maxIdx = _maxIdx;
    final int nextLastIdx = (_lastIdx + 1) > maxIdx ? maxIdx : (_lastIdx + 1);
    await _persistProgress(lastIdx: nextLastIdx, completed: false);
  }

  Future<void> _completeReading() async {
    await _persistProgress(lastIdx: _maxIdx, completed: true);
  }

  Future<void> _persistProgress({
    required int lastIdx,
    required bool completed,
  }) async {
    setState(() {
      _savingProgress = true;
    });
    try {
      await ref.read(readingRepositoryProvider).upsertUserReadingProgress(
            passageId: widget.passage.id,
            lastIdx: lastIdx,
            completed: completed,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _lastIdx = lastIdx;
        _completed = completed;
      });
      ref.invalidate(readingProgressProvider(widget.passage.id));
      ref.invalidate(homeDashboardProvider);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Okuma ilerlemesi kaydedilemedi: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingProgress = false;
        });
      }
    }
  }

  Future<void> _openQuickWordPopup(String normalizedWord) async {
    if (_quickWordSheetOpen) {
      return;
    }
    if (normalizedWord.trim().isEmpty) {
      return;
    }
    _quickWordSheetOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: WordQuickViewSheet(
          hostContext: context,
          pack: widget.pack,
          selectedWord: normalizedWord,
        ),
      ),
    );
    _quickWordSheetOpen = false;
  }

  String? _resolveTranslation(PassageSentence sentence) {
    final String inline = sentence.sentenceTr?.trim() ?? '';
    if (inline.isNotEmpty) {
      return inline;
    }
    final String cached = _runtimeTranslations[sentence.id]?.trim() ?? '';
    if (cached.isNotEmpty) {
      return cached;
    }
    return null;
  }

  int get _maxIdx {
    if (_sentences.isEmpty) {
      return 0;
    }
    return _sentences
        .map((PassageSentence e) => e.idx)
        .reduce((int a, int b) => a > b ? a : b);
  }

  Set<String> get _knownWordsSet {
    return _passageWords
        .map((WordItem e) => normalizeWordToken(e.enWord))
        .where((String e) => e.isNotEmpty)
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.passage.title)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const AppLoadingBlock(message: 'Okuma yukleniyor...');
    }

    if (_error != null) {
      return AppErrorState(
        title: 'Paragraf yuklenemedi.',
        detail: _error!,
        onRetry: _load,
      );
    }

    if (_sentences.isEmpty) {
      return const AppEmptyState(
        title: 'Bu paragrafta cumle yok.',
        message: 'Baska bir paragraf secip tekrar deneyin.',
        icon: Icons.menu_book_outlined,
      );
    }

    final int total = _maxIdx;
    final int shownProgress =
        _completed ? total : (_lastIdx > total ? total : _lastIdx);
    final double progress = total == 0 ? 0 : shownProgress / total;
    final Set<String> knownWordsSet = _knownWordsSet;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        itemCount: _sentences.length + 2,
        itemBuilder: (BuildContext context, int index) {
          if (index == 0) {
            return AppSurfaceCard(
              margin: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        'Ilerleme: $shownProgress/$total',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(width: 8),
                      if (_completed)
                        const Chip(
                          label: Text('Tamamlandi'),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _savingProgress || shownProgress >= total
                              ? null
                              : _advanceProgress,
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text('Ilerledim'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _savingProgress || _completed
                              ? null
                              : _completeReading,
                          icon: const Icon(Icons.task_alt_rounded),
                          label: const Text('Okumayi Bitirdim'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          if (index == _sentences.length + 1) {
            return _buildPassageWordsPanel();
          }

          final PassageSentence sentence = _sentences[index - 1];
          final bool expanded = _expandedSentenceIds.contains(sentence.id);
          final bool loadingTranslate =
              _loadingTranslationIds.contains(sentence.id);
          final String? translation = _resolveTranslation(sentence);
          final String? translateError = _translationErrors[sentence.id];

          return AppSurfaceCard(
            margin: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Chip(
                      label: Text('${sentence.idx}'),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: InteractiveSentenceText(
                        sentenceText: sentence.sentenceEn,
                        knownWordsSet: knownWordsSet,
                        onWordTap: _openQuickWordPopup,
                        baseStyle: Theme.of(context).textTheme.bodyLarge,
                        knownStyle:
                            Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _toggleTranslation(sentence),
                  icon: Icon(
                    expanded ? Icons.visibility_off : Icons.translate,
                  ),
                  label: Text(
                    expanded ? 'Ceviriyi Gizle' : 'Ceviriyi Goster',
                  ),
                ),
                if (expanded) ...<Widget>[
                  const SizedBox(height: 6),
                  if (loadingTranslate)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: <Widget>[
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Ceviri yukleniyor...'),
                        ],
                      ),
                    ),
                  if (!loadingTranslate && translation != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'TR:',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(translation),
                        ],
                      ),
                    ),
                  if (!loadingTranslate && translation == null) ...<Widget>[
                    const Text('Ceviri bulunamadi.'),
                    if (translateError != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        translateError,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () => _translateAndCache(sentence),
                      child: const Text('Retry Ceviri'),
                    ),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPassageWordsPanel() {
    return AppSurfaceCard(
      margin: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const AppSectionHeader(title: 'Bu paragraftan kelimeler'),
          const SizedBox(height: 8),
          if (_loadingPassageWords)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_passageWordsError != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(_passageWordsError!),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _loadPassageWords,
                  child: const Text('Retry'),
                ),
              ],
            )
          else if (_passageWords.isEmpty)
            const Text('Bu paragraftan eslesen kelime bulunamadi.')
          else ...<Widget>[
            ..._passageWords.map(
              (WordItem word) {
                final int mastery =
                    _passageWordsProgress[word.id]?.mastery ?? 0;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(word.enWord),
                  subtitle: Text(word.pos),
                  trailing: Chip(
                    label: Text('Mastery $mastery'),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            AppGradientCtaButton(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FlashcardSessionPage(
                      pack: widget.pack,
                      customWordIds: _passageWords
                          .map((WordItem e) => e.id)
                          .toList(growable: false),
                      sessionLabel: 'Paragraftan Kelime Calis',
                    ),
                  ),
                );
              },
              icon: Icons.school,
              label: 'Kelime Calis',
            ),
          ],
        ],
      ),
    );
  }
}
