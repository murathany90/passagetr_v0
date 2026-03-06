// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html_table/flutter_html_table.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/widgets/app_shimmer_block.dart';
import '../../core/widgets/app_speak_button.dart';
import '../../core/widgets/app_surface_card.dart';
import '../../domain/entities/dictionary_lookup_result.dart';
import '../../domain/entities/grammar_mini_test.dart';
import '../../domain/entities/grammar_module.dart';
import '../../domain/entities/grammar_page.dart';
import '../../domain/entities/grammar_page_detail.dart';
import '../../domain/entities/word_item.dart';
import '../../domain/repositories/dictionary_repository.dart';
import '../../domain/repositories/word_repository.dart';
import '../../state/providers.dart';
import '../words/widgets/dictionary_fallback_sheet.dart';
import '../words/word_detail_page.dart';

class GrammarReaderPage extends ConsumerStatefulWidget {
  const GrammarReaderPage({
    super.key,
    required this.module,
    required this.pages,
    required this.initialIndex,
  });

  final GrammarModule module;
  final List<GrammarPage> pages;
  final int initialIndex;

  @override
  ConsumerState<GrammarReaderPage> createState() => _GrammarReaderPageState();
}

class _GrammarReaderPageState extends ConsumerState<GrammarReaderPage> {
  static const String _lastModuleKey = 'grammar_last_module_id';
  static const String _lastPageKey = 'grammar_last_page_id';
  static const String _readPagesPrefix = 'grammar_read_pages_';

  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _saveResume(widget.pages[widget.initialIndex].id);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _saveResume(int pageId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastModuleKey, widget.module.id);
    await prefs.setInt(_lastPageKey, pageId);
    await _markPageRead(prefs, pageId);
  }

  Future<void> _markPageRead(SharedPreferences prefs, int pageId) async {
    final String key = '$_readPagesPrefix${widget.module.id}';
    final List<String> readPages = prefs.getStringList(key) ?? <String>[];
    final String pageIdStr = pageId.toString();
    if (!readPages.contains(pageIdStr)) {
      readPages.add(pageIdStr);
      await prefs.setStringList(key, readPages);
    }
  }

  @override
  Widget build(BuildContext context) {
    final int total = widget.pages.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.module.baslik),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      '${_currentIndex + 1}/$total',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : (_currentIndex + 1) / total,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.pages.length,
              onPageChanged: (int index) {
                setState(() {
                  _currentIndex = index;
                });
                _saveResume(widget.pages[index].id);
              },
              itemBuilder: (BuildContext context, int index) {
                final GrammarPage page = widget.pages[index];
                final bool isLastPage = index == widget.pages.length - 1;

                return _PageContent(
                  page: page,
                  pageDisplayText: '${index + 1}/$total',
                  isLastPage: isLastPage,
                  onNext: () {
                    if (isLastPage) {
                      Navigator.of(context).pop();
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                );
              },
              physics: const NeverScrollableScrollPhysics(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageContent extends ConsumerWidget {
  const _PageContent({
    required this.page,
    required this.pageDisplayText,
    required this.isLastPage,
    required this.onNext,
  });

  final GrammarPage page;
  final String pageDisplayText;
  final bool isLastPage;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<GrammarPageDetail> detailAsync =
        ref.watch(grammarPageDetailProvider(page.id));

    return detailAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            AppShimmerCard(lineCount: 5),
            SizedBox(height: 10),
            AppShimmerCard(lineCount: 3),
            SizedBox(height: 10),
            AppShimmerCard(),
          ],
        ),
      ),
      error: (Object error, StackTrace stackTrace) {
        final bool localMissing = _isLocalMissingError(error);
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.error_outline, size: 28),
                const SizedBox(height: 8),
                Text(
                  localMissing
                      ? 'Lokal içerik yok.\nİnternete bağlanıp tekrar deneyin.'
                      : 'Sayfa yüklenemedi.\n${error.toString()}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    ref.invalidate(grammarPageDetailProvider(page.id));
                  },
                  child: const Text('Tekrar Dene'),
                ),
              ],
            ),
          ),
        );
      },
      data: (GrammarPageDetail detail) {
        return Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            detail.page.baslik,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Chip(label: Text(pageDisplayText)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildHtml(context, ref, detail.page.icerikHtml),
                    if (detail.examples.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 18),
                      Text(
                        'Örnekler',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 8),
                      ...detail.examples.map(
                        (example) => AppSurfaceCard(
                          variant: AppSurfaceVariant.grouped,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text('EN: ${example.ingilizce}'),
                                  ),
                                  AppSpeakButton(
                                    text: example.ingilizce,
                                    iconSize: 18,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('TR: ${example.turkce}'),
                              if (example.aciklama.trim().isNotEmpty) ...<Widget>[
                                const SizedBox(height: 6),
                                Text('Açıklama: ${example.aciklama}'),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (detail.tests.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 18),
                      Text(
                        'Mini Test',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 8),
                      ...detail.tests.map(_InteractiveTestCard.new),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.72),
                  ),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color:
                        Theme.of(context).shadowColor.withValues(alpha: 0.05),
                    offset: const Offset(0, -4),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: FilledButton(
                  onPressed: onNext,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    isLastPage ? 'Dersi Bitir' : 'Devam Et',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  bool _isLocalMissingError(Object error) {
    final String text = error.toString().toLowerCase();
    return text.contains('lokal gramer içeriği yok') ||
        text.contains('lokal icerik yok');
  }

  Future<void> _lookupWord(
    BuildContext context,
    WidgetRef ref,
    String rawWord,
  ) async {
    final String normalized =
        rawWord.trim().toLowerCase().replaceAll(RegExp(r'[^a-zA-Z\-]'), '');
    if (normalized.isEmpty) {
      return;
    }

    final WordRepository wordRepo = ref.read(wordRepositoryProvider);
    final WordItem? existing = await wordRepo.getWordByEnWordGlobal(normalized);

    if (!context.mounted) {
      return;
    }

    if (existing != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => WordDetailPage(word: existing),
        ),
      );
      return;
    }

    final DictionaryRepository dictRepo =
        ref.read(dictionaryRepositoryProvider);
    final DictionaryLookupResult lookup =
        await dictRepo.lookup(query: normalized);

    if (!context.mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) =>
          DictionaryFallbackSheet(query: normalized, lookup: lookup),
    );
  }

  Widget _buildHtml(BuildContext context, WidgetRef ref, String htmlContent) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return SelectionArea(
      contextMenuBuilder: (
        BuildContext context,
        SelectableRegionState selectableRegionState,
      ) {
        final List<ContextMenuButtonItem> buttonItems =
            List<ContextMenuButtonItem>.of(
          selectableRegionState.contextMenuButtonItems,
        );
        buttonItems.insert(
          0,
          ContextMenuButtonItem(
            label: 'Sözlükte Ara',
            onPressed: () {
              final String selectedText =
                  selectableRegionState.textEditingValue.selection.textInside(
                selectableRegionState.textEditingValue.text,
              );
              ContextMenuController.removeAny();
              _lookupWord(context, ref, selectedText);
            },
          ),
        );
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: selectableRegionState.contextMenuAnchors,
          buttonItems: buttonItems,
        );
      },
      child: Html(
        data: htmlContent,
        extensions: const <HtmlExtension>[
          TableHtmlExtension(),
        ],
        style: <String, Style>{
          'body': Style(
            margin: Margins.zero,
            fontSize: FontSize(15),
            lineHeight: const LineHeight(1.55),
          ),
          'h1': Style(
            fontSize: FontSize(22),
            fontWeight: FontWeight.w700,
          ),
          'h2': Style(
            fontSize: FontSize(20),
            fontWeight: FontWeight.w700,
          ),
          'h3': Style(
            fontSize: FontSize(18),
            fontWeight: FontWeight.w600,
          ),
          'strong': Style(fontWeight: FontWeight.w700),
          'em': Style(fontStyle: FontStyle.italic),
          'table': Style(
            backgroundColor: colors.surfaceContainerLowest,
            border: Border.all(
              color: colors.outlineVariant,
              width: 0.8,
            ),
            margin: Margins.symmetric(vertical: 8),
          ),
          'th': Style(
            padding: HtmlPaddings.all(6),
            backgroundColor: colors.surfaceContainerHigh,
            border: Border.all(
              color: colors.outlineVariant,
              width: 0.6,
            ),
            fontWeight: FontWeight.w700,
          ),
          'td': Style(
            padding: HtmlPaddings.all(6),
            border: Border.all(
              color: colors.outlineVariant,
              width: 0.6,
            ),
          ),
          'code': Style(
            backgroundColor: colors.surfaceContainerHigh,
            fontFamily: 'monospace',
            fontSize: FontSize(13),
            padding: HtmlPaddings.symmetric(horizontal: 4, vertical: 2),
          ),
          'pre': Style(
            backgroundColor: colors.surfaceContainerHigh,
            padding: HtmlPaddings.all(12),
            margin: Margins.symmetric(vertical: 8),
          ),
          'blockquote': Style(
            border: Border(
              left: BorderSide(color: colors.primary, width: 3),
            ),
            padding: HtmlPaddings.only(left: 12),
            margin: Margins.symmetric(vertical: 8),
            fontStyle: FontStyle.italic,
          ),
          '.strateji-kutusu': Style(
            backgroundColor:
                isDark ? const Color(0xFF1A3A5C) : const Color(0xFFE3F2FD),
            padding: HtmlPaddings.all(12),
            margin: Margins.symmetric(vertical: 10),
          ),
          '.uyari-kutusu': Style(
            backgroundColor:
                isDark ? const Color(0xFF5C1A1A) : const Color(0xFFFFEBEE),
            padding: HtmlPaddings.all(12),
            margin: Margins.symmetric(vertical: 10),
          ),
        },
      ),
    );
  }
}

class _InteractiveTestCard extends StatefulWidget {
  const _InteractiveTestCard(this.test);

  final GrammarMiniTest test;

  @override
  State<_InteractiveTestCard> createState() => _InteractiveTestCardState();
}

class _InteractiveTestCardState extends State<_InteractiveTestCard> {
  String? _selectedKey;
  bool _revealed = false;

  void _checkAnswer() {
    if (_selectedKey == null) {
      return;
    }
    setState(() {
      _revealed = true;
    });
  }

  void _reset() {
    setState(() {
      _selectedKey = null;
      _revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<String> keys =
        widget.test.secenekler.keys.toList(growable: false)..sort();
    final bool isCorrect = _selectedKey == widget.test.dogruCevap;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return AppSurfaceCard(
      variant: AppSurfaceVariant.grouped,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            widget.test.soru,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          for (final String key in keys) _buildOption(context, key, colors),
          const SizedBox(height: 8),
          if (!_revealed)
            FilledButton.tonal(
              onPressed: _selectedKey != null ? _checkAnswer : null,
              child: const Text('Cevabı Kontrol Et'),
            )
          else ...<Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:
                    isCorrect ? colors.primaryContainer : colors.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        isCorrect
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: isCorrect ? colors.primary : colors.error,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          isCorrect ? 'Doğru!' : 'Yanlış.',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color:
                                        isCorrect ? colors.primary : colors.error,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  if (!isCorrect &&
                      widget.test.dogruCevap.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      'Doğru cevap: ${widget.test.dogruCevap}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                  if (widget.test.aciklama.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(widget.test.aciklama),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context,
    String key,
    ColorScheme colors,
  ) {
    final bool isSelected = _selectedKey == key;
    final bool isCorrectKey = key == widget.test.dogruCevap;
    final String optionText = widget.test.secenekler[key] ?? '';

    Color? tileColor;
    if (_revealed) {
      if (isCorrectKey) {
        tileColor = colors.primaryContainer.withValues(alpha: 0.5);
      } else if (isSelected && !isCorrectKey) {
        tileColor = colors.errorContainer.withValues(alpha: 0.5);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: _revealed
            ? null
            : () {
                setState(() {
                  _selectedKey = key;
                });
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: <Widget>[
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: _revealed
                    ? (isCorrectKey
                        ? colors.primary
                        : (isSelected ? colors.error : colors.outline))
                    : (isSelected ? colors.primary : colors.outline),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('$key) $optionText'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
