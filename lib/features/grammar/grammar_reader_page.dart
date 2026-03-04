import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html_table/flutter_html_table.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/grammar_module.dart';
import '../../domain/entities/grammar_page.dart';
import '../../domain/entities/grammar_page_detail.dart';
import '../../domain/entities/grammar_mini_test.dart';
import '../../state/providers.dart';

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
                return _PageContent(
                  page: page,
                  pageDisplayText: '${index + 1}/$total',
                );
              },
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
  });

  final GrammarPage page;
  final String pageDisplayText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<GrammarPageDetail> detailAsync =
        ref.watch(grammarPageDetailProvider(page.id));

    return detailAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stackTrace) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.error_outline, size: 28),
                const SizedBox(height: 8),
                Text(
                  'Sayfa yuklenemedi.\n${error.toString()}',
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
        return SingleChildScrollView(
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
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Chip(label: Text(pageDisplayText)),
                ],
              ),
              const SizedBox(height: 12),
              Html(
                data: detail.page.icerikHtml,
                extensions: const <HtmlExtension>[
                  TableHtmlExtension(),
                ],
                style: <String, Style>{
                  'body': Style(
                    margin: Margins.zero,
                    fontSize: FontSize(15),
                    lineHeight: const LineHeight(1.55),
                  ),
                  'h1': Style(fontSize: FontSize(22), fontWeight: FontWeight.w700),
                  'h2': Style(fontSize: FontSize(20), fontWeight: FontWeight.w700),
                  'h3': Style(fontSize: FontSize(18), fontWeight: FontWeight.w600),
                  'table': Style(
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 0.8,
                    ),
                    margin: Margins.symmetric(vertical: 8),
                  ),
                  'th': Style(
                    padding: HtmlPaddings.all(6),
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 0.6,
                    ),
                    fontWeight: FontWeight.w700,
                  ),
                  'td': Style(
                    padding: HtmlPaddings.all(6),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 0.6,
                    ),
                  ),
                  '.strateji-kutusu': Style(
                    backgroundColor: const Color(0xFFE3F2FD),
                    padding: HtmlPaddings.all(12),
                    margin: Margins.symmetric(vertical: 10),
                  ),
                  '.uyari-kutusu': Style(
                    backgroundColor: const Color(0xFFFFEBEE),
                    padding: HtmlPaddings.all(12),
                    margin: Margins.symmetric(vertical: 10),
                  ),
                },
              ),
              if (detail.examples.isNotEmpty) ...<Widget>[
                const SizedBox(height: 18),
                Text(
                  'Ornekler',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                ...detail.examples.map((example) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('EN: ${example.ingilizce}'),
                          const SizedBox(height: 6),
                          Text('TR: ${example.turkce}'),
                          if (example.aciklama.trim().isNotEmpty) ...<Widget>[
                            const SizedBox(height: 6),
                            Text('Aciklama: ${example.aciklama}'),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ],
              if (detail.tests.isNotEmpty) ...<Widget>[
                const SizedBox(height: 18),
                Text(
                  'Mini Test',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                ...detail.tests.map(_TestCard.new),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TestCard extends StatelessWidget {
  const _TestCard(this.test);

  final GrammarMiniTest test;

  @override
  Widget build(BuildContext context) {
    final List<String> keys = test.secenekler.keys.toList(growable: false)..sort();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              test.soru,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            for (final String key in keys)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('$key) ${test.secenekler[key] ?? ''}'),
              ),
            if (test.dogruCevap.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Dogru Cevap: ${test.dogruCevap}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
            if (test.aciklama.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text('Aciklama: ${test.aciklama}'),
            ],
          ],
        ),
      ),
    );
  }
}
