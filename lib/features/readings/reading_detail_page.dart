import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/translation_service.dart';
import '../../domain/entities/passage_sentence.dart';
import '../../domain/entities/reading_passage.dart';
import '../../domain/entities/sentence_translation.dart';
import '../../domain/repositories/reading_repository.dart';
import '../../state/providers.dart';
import 'widgets/dictionary_sheet.dart';

class ReadingDetailPage extends ConsumerStatefulWidget {
  const ReadingDetailPage({required this.passage, super.key});

  final ReadingPassage passage;

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
    });

    try {
      final List<PassageSentence> rows = await ref.read(
        readingDetailProvider(widget.passage.id).future,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _sentences = rows;
      });

      await _prefetchCachedTranslations();
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
        // Silent prefetch fail; user can manually retry per sentence.
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

  void _openDictionary(PassageSentence sentence) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: DictionarySheet(initialSentence: sentence.sentenceEn),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.passage.title)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('Paragraf yuklenemedi.'),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_sentences.isEmpty) {
      return const Center(child: Text('Bu paragrafta cumle yok.'));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
        itemCount: _sentences.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (BuildContext context, int index) {
          final PassageSentence sentence = _sentences[index];
          final bool expanded = _expandedSentenceIds.contains(sentence.id);
          final bool loadingTranslate =
              _loadingTranslationIds.contains(sentence.id);
          final String? translation = _resolveTranslation(sentence);
          final String? translateError = _translationErrors[sentence.id];

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${sentence.idx}. ${sentence.sentenceEn}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _toggleTranslation(sentence),
                          icon: Icon(expanded
                              ? Icons.visibility_off
                              : Icons.translate),
                          label: Text(
                              expanded ? 'Ceviriyi Gizle' : 'Ceviriyi Goster'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Sozluk Ac',
                        onPressed: () => _openDictionary(sentence),
                        icon: const Icon(Icons.menu_book),
                      ),
                    ],
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
                          borderRadius: BorderRadius.circular(8),
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
                                    color:
                                        Theme.of(context).colorScheme.primary,
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
            ),
          );
        },
      ),
    );
  }
}
