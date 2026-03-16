import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/admin_console_models.dart';
import '../../core/admin_providers.dart';
import '../common/admin_page_parts.dart';
import '../ai_assistant/widgets/ai_draft_editor.dart';
import '../ai_assistant/widgets/ai_questions_panel.dart';
import 'widgets/reading_cover_panel.dart';

class AdminContentPage extends ConsumerStatefulWidget {
  const AdminContentPage({super.key, required this.destination});

  final AdminDestination destination;

  @override
  ConsumerState<AdminContentPage> createState() => _AdminContentPageState();
}

class _AdminContentPageState extends ConsumerState<AdminContentPage> {
  late final TextEditingController _wordsQueryController;
  late final TextEditingController _readingsQueryController;
  late final TextEditingController _grammarQueryController;

  AdminWordsFilterState _wordsFilters = const AdminWordsFilterState();
  AdminReadingsFilterState _readingsFilters = const AdminReadingsFilterState();
  AdminGrammarFilterState _grammarFilters = const AdminGrammarFilterState();
  bool _isBulkAssigningFocusWords = false;
  AdminAiReadingRun? _activeQuestionRun;
  AdminAiReadingRun? _activeCoverRun;

  bool get _isPreviewMode => !ref.read(adminAppConfigProvider).supabaseEnabled;

  @override
  void initState() {
    super.initState();
    _wordsQueryController = TextEditingController();
    _readingsQueryController = TextEditingController();
    _grammarQueryController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_restoreActiveReadingAiRuns());
    });
  }

  @override
  void didUpdateWidget(covariant AdminContentPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.destination != widget.destination &&
        widget.destination == AdminDestination.readings) {
      unawaited(_restoreActiveReadingAiRuns());
    }
  }

  @override
  void dispose() {
    _wordsQueryController.dispose();
    _readingsQueryController.dispose();
    _grammarQueryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accessContext = ref.watch(adminAccessProvider);

    return AdminShellFrame(
      destination: widget.destination,
      title: _titleFor(widget.destination),
      subtitle: _subtitleFor(widget.destination),
      accessContext: accessContext,
      headerAction: SegmentedButton<AdminDestination>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: AdminDestination.readings,
            label: Text('Okumalar'),
          ),
          ButtonSegment(
            value: AdminDestination.words,
            label: Text('Kelimeler'),
          ),
          ButtonSegment(value: AdminDestination.grammar, label: Text('Gramer')),
        ],
        selected: <AdminDestination>{widget.destination},
        onSelectionChanged: (selection) {
          final next = selection.first;
          final route = switch (next) {
            AdminDestination.readings => '/content/readings',
            AdminDestination.words => '/content/words',
            AdminDestination.grammar => '/content/grammar',
            _ => '/content/readings',
          };
          context.go(route);
        },
      ),
      body: _buildDestinationBody(context),
    );
  }

  Widget _buildDestinationBody(BuildContext context) {
    final pageSize = ref.watch(adminDefaultListPageSizeProvider);
    switch (widget.destination) {
      case AdminDestination.words:
        final packs = ref.watch(adminPacksProvider);
        return packs.when(
          data: (packItems) {
            _ensureSelectedPack(packItems);
            final words = ref.watch(
              adminWordPageProvider(
                AdminWordPageRequest(
                  packId: _wordsFilters.packId,
                  query: _wordsFilters.query,
                  offset: _wordsFilters.offset,
                  limit: pageSize,
                  isPublished: _wordsFilters.isPublished,
                ),
              ),
            );
            return words.when(
              data: (wordItems) {
                return _buildWordsLayout(context, packItems, wordItems);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Text(error.toString()),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Text(error.toString()),
        );
      case AdminDestination.readings:
        final packs = ref.watch(adminPacksProvider);
        final readings = ref.watch(
          adminReadingPageProvider(
            AdminReadingPageRequest(
              query: _readingsFilters.query,
              offset: _readingsFilters.offset,
              limit: pageSize,
              level: _readingsFilters.level,
              isPublished: _readingsFilters.isPublished,
              hasQuestions: _readingsFilters.hasQuestions,
              hasCover: _readingsFilters.hasCover,
            ),
          ),
        );
        return packs.when(
          data: (packItems) => readings.when(
            data: (readingItems) =>
                _buildReadingsLayout(context, packItems, readingItems),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Text(error.toString()),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Text(error.toString()),
        );
      case AdminDestination.grammar:
        return ref
            .watch(adminGrammarModulesProvider)
            .when(
              data: (items) => _buildGrammarLayout(context, items),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Text(error.toString()),
            );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildWordsLayout(
    BuildContext context,
    List<AdminPackRecord> packs,
    AdminPage<AdminWordRecord> wordsPage,
  ) {
    AdminPackRecord? selectedPack;
    for (final item in packs) {
      if (item.id == _wordsFilters.packId) {
        selectedPack = item;
        break;
      }
    }
    final activePack = selectedPack;
    final visibleWords = wordsPage.items;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1080;
        final packPanel = AdminPanelCard(
          title: 'Paketler',
          trailing: FilledButton.icon(
            onPressed: () => _openPackEditor(context, existing: null),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Yeni Paket'),
          ),
          child: Column(
            children: [
              if (packs.isEmpty)
                _EmptyState(
                  title: 'Paket yok',
                  subtitle:
                      'Ilk paketi olusturup kelime operasyonlarini baslat.',
                  actionLabel: 'Paket Olustur',
                  onAction: () => _openPackEditor(context, existing: null),
                )
              else
                for (final pack in packs) ...[
                  _PackTile(
                    pack: pack,
                    isSelected: pack.id == selectedPack?.id,
                    onTap: () {
                      setState(() {
                        _wordsFilters = _wordsFilters.copyWith(
                          packId: pack.id,
                          offset: 0,
                        );
                      });
                    },
                    onEdit: () => _openPackEditor(context, existing: pack),
                    onDelete: () => _deletePack(context, pack),
                    onTogglePublished: (value) =>
                        _togglePublishedForPack(context, pack, value),
                  ),
                  const Divider(height: 1),
                ],
            ],
          ),
        );

        final wordsPanel = AdminPanelCard(
          title: activePack == null
              ? 'Kelime Paketi Sec'
              : '${activePack.name} Kelimeleri',
          trailing: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.tonalIcon(
                onPressed: activePack == null
                    ? null
                    : () => _openCsvImportDialog(context, activePack),
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('CSV Yukle'),
              ),
              FilledButton.icon(
                onPressed: activePack == null
                    ? null
                    : () => _openWordEditor(
                        context,
                        packs: packs,
                        selectedPackId: activePack.id,
                      ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Yeni Kelime'),
              ),
            ],
          ),
          child: Column(
            children: [
              TextField(
                controller: _wordsQueryController,
                decoration: const InputDecoration(
                  hintText: 'Kelime, anlam veya etiket ara',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (value) {
                  setState(() {
                    _wordsFilters = _wordsFilters.copyWith(
                      query: value.trim().toLowerCase(),
                      offset: 0,
                    );
                  });
                },
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<bool?>(
                        initialValue: _wordsFilters.isPublished,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Durum'),
                        items: const [
                          DropdownMenuItem<bool?>(
                            value: null,
                            child: Text('Tum durumlar'),
                          ),
                          DropdownMenuItem<bool?>(
                            value: true,
                            child: Text('Yayinda'),
                          ),
                          DropdownMenuItem<bool?>(
                            value: false,
                            child: Text('Taslak'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _wordsFilters = _wordsFilters.copyWith(
                              isPublished: value,
                              offset: 0,
                              clearPublished: value == null,
                            );
                          });
                        },
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _resetWordFilters(),
                      icon: const Icon(Icons.filter_alt_off_rounded),
                      label: const Text('Filtreleri sifirla'),
                    ),
                    if (activePack != null) ...[
                      _MetricChip(
                        label:
                            '${wordsPage.offset + 1}-${wordsPage.offset + visibleWords.length} / ${activePack.wordCount} kelime',
                      ),
                      _MetricChip(label: 'guncel ${activePack.updatedAtLabel}'),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (activePack == null)
                const _EmptyState(
                  title: 'Paket secilmedi',
                  subtitle:
                      'Soldan bir paket sec. Bu alan pakete bagli kelime CRUD ve import islemlerini acacak.',
                )
              else if (visibleWords.isEmpty)
                _EmptyState(
                  title: 'Kelime bulunamadi',
                  subtitle: _wordsFilters.query.isEmpty
                      ? 'Bu pakette henuz kelime yok. Yeni kelime ekle veya CSV import et.'
                      : 'Arama filtresi sonuc vermedi.',
                  actionLabel: _wordsFilters.query.isEmpty
                      ? 'Yeni Kelime'
                      : null,
                  onAction: _wordsFilters.query.isEmpty
                      ? () => _openWordEditor(
                          context,
                          packs: packs,
                          selectedPackId: activePack.id,
                        )
                      : null,
                )
              else ...[
                for (final word in visibleWords) ...[
                  _WordRow(
                    word: word,
                    onEdit: () => _openWordEditor(
                      context,
                      packs: packs,
                      existing: word,
                      selectedPackId: activePack.id,
                    ),
                    onDelete: () => _deleteWord(context, word),
                    onTogglePublished: (value) =>
                        _togglePublishedForWord(context, word, value),
                  ),
                  const Divider(height: 1),
                ],
                const SizedBox(height: 16),
                _PagedListFooter(
                  hasPrevious: wordsPage.hasPreviousPage,
                  hasNext: wordsPage.hasNextPage,
                  onPrevious: () {
                    setState(() {
                      _wordsFilters = _wordsFilters.copyWith(
                        offset: math.max(
                          0,
                          _wordsFilters.offset - wordsPage.limit,
                        ),
                      );
                    });
                  },
                  onNext: () {
                    setState(() {
                      _wordsFilters = _wordsFilters.copyWith(
                        offset: _wordsFilters.offset + wordsPage.limit,
                      );
                    });
                  },
                ),
              ],
            ],
          ),
        );

        if (!isWide) {
          return Column(
            children: [packPanel, const SizedBox(height: 18), wordsPanel],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 4, child: packPanel),
            const SizedBox(width: 18),
            Expanded(flex: 7, child: wordsPanel),
          ],
        );
      },
    );
  }

  Widget _buildReadingsLayout(
    BuildContext context,
    List<AdminPackRecord> packs,
    AdminPage<AdminReadingRecord> readingsPage,
  ) {
    const levels = <String>['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
    final visibleReadings = readingsPage.items;

    return AdminPanelCard(
      title: 'Okuma Operasyonlari',
      trailing: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          Tooltip(
            message: 'Filtre sonucundaki mini testi eksik kayitlar icin soru uret',
            child: FilledButton.tonalIcon(
              onPressed: _isPreviewMode
                  ? null
                  : () => _startReadingAiBackfill(
                      context,
                      jobType: 'question_backfill',
                    ),
              icon: const Icon(Icons.quiz_outlined),
              label: const Text('Eksik Mini Testler'),
            ),
          ),
          Tooltip(
            message: 'Filtre sonucundaki gorseli eksik kayitlar icin kapak uret',
            child: FilledButton.tonalIcon(
              onPressed: _isPreviewMode
                  ? null
                  : () => _startReadingAiBackfill(
                      context,
                      jobType: 'cover_backfill',
                    ),
              icon: const Icon(Icons.image_outlined),
              label: const Text('Eksik Kapaklar'),
            ),
          ),
          Tooltip(
            message: 'Tum okumalar icin odak kelimeleri otomatik ata',
            child: FilledButton.tonalIcon(
              onPressed: _isPreviewMode || _isBulkAssigningFocusWords
                  ? null
                  : () => _autoAssignFocusWordsForAllReadings(context),
              icon: _isBulkAssigningFocusWords
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: const Text('Tumune Ata'),
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: () => _openReadingImportDialog(context, packs: packs),
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('CSV Yukle'),
          ),
          FilledButton.icon(
            onPressed: () => _openReadingEditor(context, packs: packs),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Yeni Parca Ekle'),
          ),
        ],
      ),
          child: Column(
        children: [
          if (_activeQuestionRun != null || _activeCoverRun != null) ...[
            _ReadingAiRunProgressCard(
              questionRun: _activeQuestionRun,
              coverRun: _activeCoverRun,
              onOpenQuestionRun: _activeQuestionRun == null
                  ? null
                  : () => _showReadingAiRunDialog(
                      context,
                      jobType: 'question_backfill',
                      initialRun: _activeQuestionRun!,
                    ),
              onOpenCoverRun: _activeCoverRun == null
                  ? null
                  : () => _showReadingAiRunDialog(
                      context,
                      jobType: 'cover_backfill',
                      initialRun: _activeCoverRun!,
                    ),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _readingsQueryController,
            decoration: const InputDecoration(
              hintText: 'Baslik, kategori veya tag ara',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (value) {
              setState(() {
                _readingsFilters = _readingsFilters.copyWith(
                  query: value.trim().toLowerCase(),
                  offset: 0,
                );
              });
            },
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _readingsFilters.level,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Seviye'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Tum seviyeler'),
                      ),
                      ...levels.map(
                        (item) => DropdownMenuItem<String?>(
                          value: item,
                          child: Text(item),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _readingsFilters = _readingsFilters.copyWith(
                          level: value,
                          offset: 0,
                          clearLevel: value == null,
                        );
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<bool?>(
                    initialValue: _readingsFilters.isPublished,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Durum'),
                    items: const [
                      DropdownMenuItem<bool?>(
                        value: null,
                        child: Text('Tum durumlar'),
                      ),
                      DropdownMenuItem<bool?>(
                        value: true,
                        child: Text('Yayinda'),
                      ),
                      DropdownMenuItem<bool?>(
                        value: false,
                        child: Text('Taslak'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _readingsFilters = _readingsFilters.copyWith(
                          isPublished: value,
                          offset: 0,
                          clearPublished: value == null,
                        );
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<bool?>(
                    initialValue: _readingsFilters.hasQuestions,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Mini Test'),
                    items: const [
                      DropdownMenuItem<bool?>(
                        value: null,
                        child: Text('Tum kayitlar'),
                      ),
                      DropdownMenuItem<bool?>(
                        value: true,
                        child: Text('Mini test var'),
                      ),
                      DropdownMenuItem<bool?>(
                        value: false,
                        child: Text('Mini test yok'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _readingsFilters = _readingsFilters.copyWith(
                          hasQuestions: value,
                          offset: 0,
                          clearHasQuestions: value == null,
                        );
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<bool?>(
                    initialValue: _readingsFilters.hasCover,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Gorsel'),
                    items: const [
                      DropdownMenuItem<bool?>(
                        value: null,
                        child: Text('Tum kayitlar'),
                      ),
                      DropdownMenuItem<bool?>(
                        value: true,
                        child: Text('Kapak var'),
                      ),
                      DropdownMenuItem<bool?>(
                        value: false,
                        child: Text('Kapak yok'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _readingsFilters = _readingsFilters.copyWith(
                          hasCover: value,
                          offset: 0,
                          clearHasCover: value == null,
                        );
                      });
                    },
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _resetReadingFilters(),
                  icon: const Icon(Icons.filter_alt_off_rounded),
                  label: const Text('Filtreleri sifirla'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (visibleReadings.isEmpty)
            _EmptyState(
              title: 'Okuma kaydi yok',
              subtitle:
                  _readingsFilters.query.isEmpty &&
                      _readingsFilters.level == null &&
                      _readingsFilters.isPublished == null &&
                      _readingsFilters.hasQuestions == null &&
                      _readingsFilters.hasCover == null
                  ? 'Yeni parca ekleyip publish akisini bu panelden yonet.'
                  : 'Secili filtrelerle eslesen kayit bulunamadi.',
              actionLabel:
                  _readingsFilters.query.isEmpty &&
                      _readingsFilters.level == null &&
                      _readingsFilters.isPublished == null &&
                      _readingsFilters.hasQuestions == null &&
                      _readingsFilters.hasCover == null
                  ? 'Parca Ekle'
                  : null,
              onAction:
                  _readingsFilters.query.isEmpty &&
                      _readingsFilters.level == null &&
                      _readingsFilters.isPublished == null &&
                      _readingsFilters.hasQuestions == null &&
                      _readingsFilters.hasCover == null
                  ? () => _openReadingEditor(context, packs: packs)
                  : null,
            )
          else ...[
            for (final reading in visibleReadings) ...[
              _ReadingRow(
                reading: reading,
                packLabel: _packLabelForReading(reading, packs),
                onEdit: () => _openReadingEditor(
                  context,
                  packs: packs,
                  existing: reading,
                ),
                onDelete: () => _deleteReading(context, reading),
                onAutoAssign: _isPreviewMode
                    ? null
                    : () => _autoAssignReadingFocusWords(
                        context,
                        reading,
                        packs: packs,
                      ),
                onGenerateQuestions: _isPreviewMode
                    ? null
                    : () => _generateQuestionsForReading(
                        context,
                        reading,
                        packs: packs,
                      ),
                onTogglePublished: (value) =>
                    _togglePublishedForReading(context, reading, value),
              ),
              const Divider(height: 1),
            ],
            const SizedBox(height: 16),
            _PagedListFooter(
              hasPrevious: readingsPage.hasPreviousPage,
              hasNext: readingsPage.hasNextPage,
              onPrevious: () {
                setState(() {
                  _readingsFilters = _readingsFilters.copyWith(
                    offset: math.max(
                      0,
                      _readingsFilters.offset - readingsPage.limit,
                    ),
                  );
                });
              },
              onNext: () {
                setState(() {
                  _readingsFilters = _readingsFilters.copyWith(
                    offset: _readingsFilters.offset + readingsPage.limit,
                  );
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGrammarLayout(
    BuildContext context,
    List<AdminGrammarRecord> modules,
  ) {
    final canReorder =
        _grammarFilters.query.isEmpty && _grammarFilters.isPublished == null;
    final visibleModules = modules
        .where((item) {
          final haystack = '${item.title} ${item.fileName} ${item.pageCount}'
              .toLowerCase();
          final matchesQuery =
              _grammarFilters.query.isEmpty ||
              haystack.contains(_grammarFilters.query);
          final matchesStatus =
              _grammarFilters.isPublished == null ||
              item.isPublished == _grammarFilters.isPublished;
          return matchesQuery && matchesStatus;
        })
        .toList(growable: false);

    return AdminPanelCard(
      title: 'Gramer Modulleri',
      trailing: FilledButton.icon(
        onPressed: () => _openGrammarEditor(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Yeni Modul'),
      ),
      child: Column(
        children: [
          TextField(
            controller: _grammarQueryController,
            decoration: const InputDecoration(
              hintText: 'Modul adi veya dosya adi ara',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (value) {
              setState(() {
                _grammarFilters = _grammarFilters.copyWith(
                  query: value.trim().toLowerCase(),
                );
              });
            },
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<bool?>(
                    initialValue: _grammarFilters.isPublished,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Durum'),
                    items: const [
                      DropdownMenuItem<bool?>(
                        value: null,
                        child: Text('Tum durumlar'),
                      ),
                      DropdownMenuItem<bool?>(
                        value: true,
                        child: Text('Yayinda'),
                      ),
                      DropdownMenuItem<bool?>(
                        value: false,
                        child: Text('Taslak'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _grammarFilters = _grammarFilters.copyWith(
                          isPublished: value,
                          clearPublished: value == null,
                        );
                      });
                    },
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _resetGrammarFilters(),
                  icon: const Icon(Icons.filter_alt_off_rounded),
                  label: const Text('Filtreleri sifirla'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (visibleModules.isEmpty)
            _EmptyState(
              title: 'Gramer modulu yok',
              subtitle:
                  _grammarFilters.query.isEmpty &&
                      _grammarFilters.isPublished == null
                  ? 'Yeni modul ekleyip sirayi bu panelden yonet.'
                  : 'Arama sonucu bulunamadi.',
              actionLabel:
                  _grammarFilters.query.isEmpty &&
                      _grammarFilters.isPublished == null
                  ? 'Modul Ekle'
                  : null,
              onAction:
                  _grammarFilters.query.isEmpty &&
                      _grammarFilters.isPublished == null
                  ? () => _openGrammarEditor(context)
                  : null,
            )
          else
            for (var index = 0; index < visibleModules.length; index++) ...[
              _GrammarRow(
                module: visibleModules[index],
                canMoveUp: canReorder && index > 0,
                canMoveDown: canReorder && index < visibleModules.length - 1,
                onMoveUp: () =>
                    _reorderGrammar(context, modules, index, index - 1),
                onMoveDown: () =>
                    _reorderGrammar(context, modules, index, index + 1),
                onEdit: () => _openGrammarEditor(
                  context,
                  existing: visibleModules[index],
                ),
                onDelete: () => _deleteGrammar(context, visibleModules[index]),
                onTogglePublished: (value) => _togglePublishedForGrammar(
                  context,
                  visibleModules[index],
                  value,
                ),
              ),
              const Divider(height: 1),
            ],
        ],
      ),
    );
  }

  Future<void> _openPackEditor(
    BuildContext context, {
    AdminPackRecord? existing,
  }) async {
    final draft = await showDialog<_PackEditorDraft>(
      context: context,
      builder: (context) => _PackEditorDialog(existing: existing),
    );
    if (draft == null) {
      return;
    }

    final repository = ref.read(adminContentRepositoryProvider);
    final result = await repository.upsertPack(
      packId: existing?.id,
      name: draft.name,
      isPublished: draft.isPublished,
    );
    if (!mounted) {
      return;
    }

    if (result case AppFailure<void>()) {
      _showSnackBar(result.message, isError: true);
      return;
    }

    if (_isPreviewMode) {
      final record =
          (existing ??
                  AdminPackRecord(
                    id: _clientId('pack'),
                    name: draft.name,
                    wordCount: 0,
                    isPublished: draft.isPublished,
                    updatedAtLabel: 'az once',
                  ))
              .copyWith(
                name: draft.name,
                isPublished: draft.isPublished,
                updatedAtLabel: 'az once',
              );
      ref.read(adminPackChangesProvider.notifier).upsert(record);
      _wordsFilters = _wordsFilters.copyWith(
        packId: _wordsFilters.packId ?? record.id,
      );
    } else {
      if (existing != null) {
        ref
            .read(adminPackChangesProvider.notifier)
            .upsert(
              existing.copyWith(
                name: draft.name,
                isPublished: draft.isPublished,
                updatedAtLabel: 'az once',
              ),
            );
      }
      ref.invalidate(adminPacksProvider);
      ref.invalidate(adminWordEntriesProvider);
      ref.invalidate(adminWordPageProvider);
      ref.invalidate(adminReadingsProvider);
      ref.invalidate(adminReadingPageProvider);
      ref.invalidate(adminDashboardSnapshotProvider);
      ref.invalidate(adminAuditFeedProvider);
    }

    _pushAudit(
      existing == null ? 'admin.pack.created' : 'admin.pack.updated',
      draft.name,
    );
    _showSnackBar(
      existing == null ? 'Paket olusturuldu.' : 'Paket guncellendi.',
    );
  }

  Future<void> _deletePack(BuildContext context, AdminPackRecord pack) async {
    final shouldDelete = await _confirmAction(
      context,
      title: 'Paketi sil',
      description:
          '${pack.name} silinirse buna bagli kelimeler ve okumalar da etkilenir. Bu islem geri alinmaz.',
      confirmLabel: 'Paketi Sil',
      isDestructive: true,
    );
    if (!shouldDelete) {
      return;
    }

    final result = await ref
        .read(adminContentRepositoryProvider)
        .deletePack(packId: pack.id);
    if (!mounted) {
      return;
    }

    if (result case AppFailure<void>()) {
      _showSnackBar(result.message, isError: true);
      return;
    }

    if (_isPreviewMode) {
      final words = await ref.read(adminWordEntriesProvider.future);
      ref.read(adminPackChangesProvider.notifier).remove(pack.id);
      final wordNotifier = ref.read(adminWordChangesProvider.notifier);
      for (final item in words.where((item) => item.packId == pack.id)) {
        wordNotifier.remove(item.id);
      }
      if (_wordsFilters.packId == pack.id) {
        setState(() {
          _wordsFilters = _wordsFilters.copyWith(clearPackId: true);
        });
      }
    } else {
      ref.read(adminPackChangesProvider.notifier).remove(pack.id);
      ref.invalidate(adminPacksProvider);
      ref.invalidate(adminWordEntriesProvider);
      ref.invalidate(adminWordPageProvider);
      ref.invalidate(adminReadingsProvider);
      ref.invalidate(adminReadingPageProvider);
      ref.invalidate(adminDashboardSnapshotProvider);
      ref.invalidate(adminAuditFeedProvider);
    }

    _pushAudit('admin.pack.deleted', pack.name);
    _showSnackBar('Paket silindi.');
  }

  Future<void> _togglePublishedForPack(
    BuildContext context,
    AdminPackRecord pack,
    bool nextValue,
  ) async {
    final shouldProceed = await _confirmAction(
      context,
      title: nextValue ? 'Paketi yayinla' : 'Paketi taslaga al',
      description:
          'Paket durumu student web tarafini ve mobil sync akislarini etkiler.',
      confirmLabel: nextValue ? 'Yayinla' : 'Taslak Yap',
    );
    if (!shouldProceed) {
      return;
    }

    final result = await ref
        .read(adminContentRepositoryProvider)
        .setContentPublished(
          entityType: 'pack',
          entityId: pack.id,
          isPublished: nextValue,
        );
    if (!mounted) {
      return;
    }

    if (result case AppFailure<void>()) {
      _showSnackBar(result.message, isError: true);
      return;
    }

    if (_isPreviewMode) {
      ref
          .read(adminPackChangesProvider.notifier)
          .upsert(
            pack.copyWith(isPublished: nextValue, updatedAtLabel: 'az once'),
          );
    } else {
      ref
          .read(adminPackChangesProvider.notifier)
          .upsert(
            pack.copyWith(isPublished: nextValue, updatedAtLabel: 'az once'),
          );
      ref.invalidate(adminPacksProvider);
      ref.invalidate(adminDashboardSnapshotProvider);
      ref.invalidate(adminAuditFeedProvider);
    }

    _pushAudit(
      nextValue ? 'content.published' : 'content.unpublished',
      'pack / ${pack.name}',
    );
    _showSnackBar(nextValue ? 'Paket yayinda.' : 'Paket taslaga alindi.');
  }

  Future<void> _openWordEditor(
    BuildContext context, {
    required List<AdminPackRecord> packs,
    AdminWordRecord? existing,
    String? selectedPackId,
  }) async {
    final detail = existing == null
        ? AdminWordDetail(packId: selectedPackId)
        : await _loadWordDetail(existing);
    if (detail == null || !context.mounted) {
      return;
    }

    final draft = await showDialog<AdminWordDetail>(
      context: context,
      builder: (context) =>
          _WordEditorDialog(packs: packs, initialDetail: detail),
    );
    if (draft == null) {
      return;
    }

    final result = await ref
        .read(adminContentRepositoryProvider)
        .upsertWordDetail(draft);
    if (!mounted) {
      return;
    }

    if (result case AppFailure<AdminWordDetail>()) {
      _showSnackBar(result.message, isError: true);
      return;
    }

    final savedDetail = (result as AppSuccess<AdminWordDetail>).value;
    if (_isPreviewMode) {
      final record =
          (existing ??
                  AdminWordRecord(
                    id: savedDetail.metadata.id ?? _clientId('word'),
                    packId: savedDetail.packId ?? '',
                    enWord: savedDetail.enWord,
                    trMeaning: savedDetail.trMeaning,
                    pos: savedDetail.pos,
                    exampleEn: savedDetail.exampleEn,
                    exampleTr: savedDetail.exampleTr,
                    level: savedDetail.level,
                    notes: savedDetail.notes,
                    isPublished: savedDetail.isPublished,
                    updatedAtLabel: 'az once',
                  ))
              .copyWith(
                packId: savedDetail.packId ?? '',
                enWord: savedDetail.enWord,
                trMeaning: savedDetail.trMeaning,
                pos: savedDetail.pos,
                exampleEn: savedDetail.exampleEn,
                exampleTr: savedDetail.exampleTr,
                level: savedDetail.level,
                notes: savedDetail.notes,
                isPublished: savedDetail.isPublished,
                updatedAtLabel: 'az once',
              );
      ref.read(adminWordChangesProvider.notifier).upsert(record);
      setState(() {
        _wordsFilters = _wordsFilters.copyWith(
          packId: savedDetail.packId,
          offset: 0,
          clearPackId: savedDetail.packId == null,
        );
      });
    } else {
      if (existing != null) {
        ref
            .read(adminWordChangesProvider.notifier)
            .upsert(
              existing.copyWith(
                packId: savedDetail.packId ?? existing.packId,
                enWord: savedDetail.enWord,
                trMeaning: savedDetail.trMeaning,
                pos: savedDetail.pos,
                exampleEn: savedDetail.exampleEn,
                exampleTr: savedDetail.exampleTr,
                level: savedDetail.level,
                notes: savedDetail.notes,
                isPublished: savedDetail.isPublished,
                updatedAtLabel: 'az once',
              ),
            );
      }
      ref.invalidate(adminWordEntriesProvider);
      ref.invalidate(adminWordPageProvider);
      ref.invalidate(adminPacksProvider);
      ref.invalidate(adminDashboardSnapshotProvider);
      ref.invalidate(adminAuditFeedProvider);
    }

    _pushAudit(
      existing == null ? 'admin.word.created' : 'admin.word.updated',
      savedDetail.enWord,
    );
    _showSnackBar(existing == null ? 'Kelime eklendi.' : 'Kelime guncellendi.');
  }

  Future<void> _deleteWord(BuildContext context, AdminWordRecord word) async {
    final shouldDelete = await _confirmAction(
      context,
      title: 'Kelimeyi sil',
      description:
          '${word.enWord} kaydi bu paketten kaldirilacak. Ilerleme baglantilari da etkilenebilir.',
      confirmLabel: 'Kelimeyi Sil',
      isDestructive: true,
    );
    if (!shouldDelete) {
      return;
    }

    final result = await ref
        .read(adminContentRepositoryProvider)
        .deleteWord(wordId: word.id);
    if (!mounted) {
      return;
    }

    if (result case AppFailure<void>()) {
      _showSnackBar(result.message, isError: true);
      return;
    }

    if (_isPreviewMode) {
      ref.read(adminWordChangesProvider.notifier).remove(word.id);
    } else {
      ref.read(adminWordChangesProvider.notifier).remove(word.id);
      ref.invalidate(adminWordEntriesProvider);
      ref.invalidate(adminWordPageProvider);
      ref.invalidate(adminPacksProvider);
      ref.invalidate(adminDashboardSnapshotProvider);
      ref.invalidate(adminAuditFeedProvider);
    }

    _pushAudit('admin.word.deleted', word.enWord);
    _showSnackBar('Kelime silindi.');
  }

  Future<void> _togglePublishedForWord(
    BuildContext context,
    AdminWordRecord word,
    bool nextValue,
  ) async {
    final shouldProceed = await _confirmAction(
      context,
      title: nextValue ? 'Kelimeyi yayinla' : 'Kelimeyi taslaga al',
      description:
          'Kelime gorunurlugu student web tarafini hizli, mobil tarafini sync sonrasi etkiler.',
      confirmLabel: nextValue ? 'Yayinla' : 'Taslak Yap',
    );
    if (!shouldProceed) {
      return;
    }

    final result = await ref
        .read(adminContentRepositoryProvider)
        .setContentPublished(
          entityType: 'word',
          entityId: word.id,
          isPublished: nextValue,
        );
    if (!mounted) {
      return;
    }

    if (result case AppFailure<void>()) {
      _showSnackBar(result.message, isError: true);
      return;
    }

    if (_isPreviewMode) {
      ref
          .read(adminWordChangesProvider.notifier)
          .upsert(
            word.copyWith(isPublished: nextValue, updatedAtLabel: 'az once'),
          );
    } else {
      ref
          .read(adminWordChangesProvider.notifier)
          .upsert(
            word.copyWith(isPublished: nextValue, updatedAtLabel: 'az once'),
          );
      ref.invalidate(adminWordEntriesProvider);
      ref.invalidate(adminWordPageProvider);
      ref.invalidate(adminDashboardSnapshotProvider);
      ref.invalidate(adminAuditFeedProvider);
    }

    _pushAudit(
      nextValue ? 'content.published' : 'content.unpublished',
      'word / ${word.enWord}',
    );
    _showSnackBar(nextValue ? 'Kelime yayinda.' : 'Kelime taslaga alindi.');
  }

  Future<void> _openCsvImportDialog(
    BuildContext context,
    AdminPackRecord pack,
  ) async {
    final rows = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (context) => _WordImportDialog(pack: pack),
    );
    if (rows == null || rows.isEmpty) {
      return;
    }

    final result = await ref
        .read(adminContentRepositoryProvider)
        .importWords(packId: pack.id, rows: rows);
    if (!mounted) {
      return;
    }

    if (result case AppFailure<void>()) {
      _showSnackBar(result.message, isError: true);
      return;
    }

    if (_isPreviewMode) {
      final notifier = ref.read(adminWordChangesProvider.notifier);
      for (final row in rows) {
        notifier.upsert(
          AdminWordRecord(
            id: _clientId('word'),
            packId: pack.id,
            enWord: row['en_word']?.toString() ?? '',
            trMeaning: row['tr_meaning']?.toString() ?? '',
            pos: row['pos']?.toString() ?? 'other',
            exampleEn: row['example_en']?.toString() ?? '',
            exampleTr: row['example_tr']?.toString(),
            level: row['level']?.toString(),
            notes: row['notes']?.toString(),
            isPublished: true,
            updatedAtLabel: 'az once',
          ),
        );
      }
    } else {
      ref.invalidate(adminWordEntriesProvider);
      ref.invalidate(adminWordPageProvider);
      ref.invalidate(adminPacksProvider);
      ref.invalidate(adminDashboardSnapshotProvider);
      ref.invalidate(adminAuditFeedProvider);
    }

    _pushAudit('admin.word.imported', '${pack.name} / ${rows.length} satir');
    _showSnackBar('${rows.length} kelime import edildi.');
  }

  Future<void> _openReadingImportDialog(
    BuildContext context, {
    required List<AdminPackRecord> packs,
  }) async {
    final items = await showDialog<List<AdminReadingDetail>>(
      context: context,
      builder: (context) => _ReadingImportDialog(packs: packs),
    );
    if (items == null || items.isEmpty) {
      return;
    }

    final result = await ref
        .read(adminContentRepositoryProvider)
        .importReadings(items: items);
    if (!mounted) {
      return;
    }

    if (result case AppFailure<void>()) {
      _showSnackBar(result.message, isError: true);
      return;
    }

    if (_isPreviewMode) {
      final notifier = ref.read(adminReadingChangesProvider.notifier);
      for (final item in items) {
        notifier.upsert(
          adminReadingRecordFromDetail(
            detail: item,
            packs: packs,
            fallbackId: _clientId('reading'),
          ),
        );
      }
    } else {
      ref.invalidate(adminReadingsProvider);
      ref.invalidate(adminReadingPageProvider);
      ref.invalidate(adminPacksProvider);
      ref.invalidate(adminDashboardSnapshotProvider);
      ref.invalidate(adminAuditFeedProvider);
    }

    _pushAudit(
      'admin.reading.imported',
      '${items.length} okuma parcasi CSV ile eklendi',
    );
    _showSnackBar('${items.length} okuma parcasi import edildi.');
  }

  Future<void> _openReadingEditor(
    BuildContext context, {
    required List<AdminPackRecord> packs,
    AdminReadingRecord? existing,
  }) async {
    final detail = existing == null
        ? const AdminReadingDetail()
        : await _loadReadingDetail(existing);
    if (detail == null || !context.mounted) {
      return;
    }

    final draft = await showDialog<AdminReadingDetail>(
      context: context,
      builder: (context) =>
          _ReadingEditorDialog(
            packs: packs,
            initialDetail: detail,
            coverUrlBuilder: (cover) =>
                _coverUrlForAsset(ref.read(adminAppConfigProvider).supabaseUrl, cover),
            aiCoverPoolStatus: ref.watch(adminAiCoverPoolStatusProvider).valueOrNull,
            onGenerateCover: _generateCoverForReadingDetail,
            onUploadCover: _uploadCoverForReadingDetail,
            onRemoveCover: _removeCoverForReadingDetail,
            onMessage: _showSnackBar,
          ),
    );
    if (draft == null) {
      return;
    }

    final result = await ref
        .read(adminContentRepositoryProvider)
        .upsertReadingDetail(draft);
    if (!mounted) {
      return;
    }

    if (result case AppFailure<AdminReadingDetail>()) {
      _showSnackBar(result.message, isError: true);
      return;
    }

    final savedDetail = (result as AppSuccess<AdminReadingDetail>).value;
    if (_isPreviewMode) {
      final record = _readingRecordFromDetail(
        detail: savedDetail,
        packs: packs,
        existing: existing,
      );
      ref.read(adminReadingChangesProvider.notifier).upsert(record);
    } else {
      if (existing != null) {
        ref
            .read(adminReadingChangesProvider.notifier)
            .upsert(
              _readingRecordFromDetail(
                detail: savedDetail,
                packs: packs,
                existing: existing,
              ),
            );
      }
      ref.invalidate(adminReadingsProvider);
      ref.invalidate(adminReadingPageProvider);
      ref.invalidate(adminDashboardSnapshotProvider);
      ref.invalidate(adminAuditFeedProvider);
    }

    _pushAudit(
      existing == null ? 'admin.reading.created' : 'admin.reading.updated',
      savedDetail.title,
    );
    _showSnackBar(
      existing == null ? 'Okuma olusturuldu.' : 'Okuma guncellendi.',
    );
  }

  Future<void> _deleteReading(
    BuildContext context,
    AdminReadingRecord reading,
  ) async {
    final shouldDelete = await _confirmAction(
      context,
      title: 'Okumayi sil',
      description:
          '${reading.title} kaydi yayindan ve admin listesinden kalkacak.',
      confirmLabel: 'Okumayi Sil',
      isDestructive: true,
    );
    if (!shouldDelete) {
      return;
    }

    final result = await ref
        .read(adminContentRepositoryProvider)
        .deleteReading(readingId: reading.id);
    if (!mounted) {
      return;
    }

    if (result case AppFailure<void>()) {
      _showSnackBar(result.message, isError: true);
      return;
    }

    if (_isPreviewMode) {
      ref.read(adminReadingChangesProvider.notifier).remove(reading.id);
    } else {
      ref.read(adminReadingChangesProvider.notifier).remove(reading.id);
      ref.invalidate(adminReadingsProvider);
      ref.invalidate(adminReadingPageProvider);
      ref.invalidate(adminDashboardSnapshotProvider);
      ref.invalidate(adminAuditFeedProvider);
    }

    _pushAudit('admin.reading.deleted', reading.title);
    _showSnackBar('Okuma silindi.');
  }

  Future<void> _togglePublishedForReading(
    BuildContext context,
    AdminReadingRecord reading,
    bool nextValue,
  ) async {
    final shouldProceed = await _confirmAction(
      context,
      title: nextValue ? 'Okumayi yayinla' : 'Okumayi taslaga al',
      description:
          'Bu degisiklik web tarafinda daha hizli, mobil tarafta sync sonrasi gorunur.',
      confirmLabel: nextValue ? 'Yayinla' : 'Taslak Yap',
    );
    if (!shouldProceed) {
      return;
    }

    final result = await ref
        .read(adminContentRepositoryProvider)
        .setContentPublished(
          entityType: 'reading',
          entityId: reading.id,
          isPublished: nextValue,
        );
    if (!mounted) {
      return;
    }

    if (result case AppFailure<void>()) {
      _showSnackBar(result.message, isError: true);
      return;
    }

    if (_isPreviewMode) {
      ref
          .read(adminReadingChangesProvider.notifier)
          .upsert(
            reading.copyWith(isPublished: nextValue, updatedAtLabel: 'az once'),
          );
    } else {
      ref
          .read(adminReadingChangesProvider.notifier)
          .upsert(
            reading.copyWith(isPublished: nextValue, updatedAtLabel: 'az once'),
          );
      ref.invalidate(adminReadingsProvider);
      ref.invalidate(adminReadingPageProvider);
      ref.invalidate(adminDashboardSnapshotProvider);
      ref.invalidate(adminAuditFeedProvider);
    }

    _pushAudit(
      nextValue ? 'content.published' : 'content.unpublished',
      'reading / ${reading.title}',
    );
    _showSnackBar(nextValue ? 'Okuma yayinda.' : 'Okuma taslaga alindi.');
  }

  Future<void> _autoAssignReadingFocusWords(
    BuildContext context,
    AdminReadingRecord reading, {
    required List<AdminPackRecord> packs,
  }) async {
    final shouldProceed = await _confirmAction(
      context,
      title: 'Odak kelimeleri otomatik ata',
      description:
          'V2 mantigi mevcut odak kelimeleri silip yerine en fazla 10 yeni eslesme atayacak.',
      confirmLabel: 'Otomatik Ata',
    );
    if (!shouldProceed) {
      return;
    }

    final result = await ref
        .read(adminContentRepositoryProvider)
        .autoAssignReadingFocusWords(readingId: reading.id);
    if (!mounted) {
      return;
    }

    if (result case AppFailure<AdminReadingDetail>()) {
      _showSnackBar(result.message, isError: true);
      return;
    }

    final detail = (result as AppSuccess<AdminReadingDetail>).value;
    final updatedRecord = _readingRecordFromDetail(
      detail: detail,
      packs: packs,
      existing: reading,
    );
    ref.read(adminReadingChangesProvider.notifier).upsert(updatedRecord);
    if (!_isPreviewMode) {
      ref.invalidate(adminReadingsProvider);
      ref.invalidate(adminReadingPageProvider);
      ref.invalidate(adminAuditFeedProvider);
    }

    _pushAudit(
      'admin.reading.focus_words.auto_assigned_v2',
      '${reading.title} / ${detail.linkedWords.length} kelime',
    );
    _showSnackBar(
      detail.linkedWords.isEmpty
          ? 'Uygun odak kelime bulunamadi.'
          : '${detail.linkedWords.length} odak kelime atandi.',
    );
  }

  Future<void> _autoAssignFocusWordsForAllReadings(BuildContext context) async {
    final shouldProceed = await _confirmAction(
      context,
      title: 'Tum okumalar icin odak kelimeleri otomatik ata',
      description:
          'Sadece odak kelimesi olmayan pasajlar islenecek, mevcut manuel linkler korunacak ve pasaj basina en fazla 10 kart atanacak.',
      confirmLabel: 'Tumune Ata',
    );
    if (!shouldProceed) {
      return;
    }

    setState(() {
      _isBulkAssigningFocusWords = true;
    });

    final result = await ref
        .read(adminContentRepositoryProvider)
        .autoAssignFocusWordsForAllReadings(
          limit: 10,
          onlyMissing: true,
          includeUnpublished: true,
        );
    if (!mounted) {
      return;
    }

    setState(() {
      _isBulkAssigningFocusWords = false;
    });

    if (result case AppFailure<AdminBulkReadingFocusWordAssignmentResult>()) {
      _showSnackBar(result.message, isError: true);
      return;
    }

    final summary =
        (result as AppSuccess<AdminBulkReadingFocusWordAssignmentResult>).value;
    ref.read(adminReadingChangesProvider.notifier).clear();
    ref.invalidate(adminReadingsProvider);
    ref.invalidate(adminReadingPageProvider);
    ref.invalidate(adminAuditFeedProvider);

    _pushAudit(
      'admin.reading.focus_words.auto_assigned_v2.bulk',
      '${summary.assignedCount} pasaj guncellendi',
    );
    _showSnackBar(
      '${summary.assignedCount} pasajda odak kelime atandi, ${summary.noMatchCount} pasajda eslesme bulunamadi.',
    );
    await _showBulkFocusWordSummary(this.context, summary);
  }

  Future<void> _generateQuestionsForReading(
    BuildContext context,
    AdminReadingRecord reading, {
    required List<AdminPackRecord> packs,
  }) async {
    final config = await _openQuestionGenerationDialog(
      context,
      replaceExisting: reading.questionCount > 0,
    );
    if (config == null) {
      return;
    }

    final detail = await _loadReadingDetail(reading);
    if (detail == null || !mounted) {
      return;
    }

    final aiRepository = ref.read(adminAiReadingRepositoryProvider);
    final questionResult = await aiRepository.generateReadingQuestions(
      AdminAiGenerateReadingQuestionsRequest(
        readingId: reading.id,
        provider: config.provider,
        model: config.model,
        questionCount: config.questionCount,
      ),
    );
    if (!mounted) {
      return;
    }

    if (questionResult case AppFailure<AdminAiGeneratedReadingQuestions>()) {
      _showSnackBar(questionResult.message, isError: true);
      return;
    }

    final generated =
        (questionResult as AppSuccess<AdminAiGeneratedReadingQuestions>).value;
    final saveResult = await ref
        .read(adminContentRepositoryProvider)
        .upsertReadingDetail(
          detail.copyWith(
            questions: generated.questions,
            aiGenerated: detail.aiGenerated,
            aiGenerationMeta: detail.aiGenerationMeta,
          ),
        );
    if (!mounted) {
      return;
    }

    if (saveResult case AppFailure<AdminReadingDetail>()) {
      _showSnackBar(saveResult.message, isError: true);
      return;
    }

    final savedDetail = (saveResult as AppSuccess<AdminReadingDetail>).value;
    final updatedRecord = _readingRecordFromDetail(
      detail: savedDetail,
      packs: packs,
      existing: reading,
    );
    ref.read(adminReadingChangesProvider.notifier).upsert(updatedRecord);
    if (!_isPreviewMode) {
      ref.invalidate(adminReadingsProvider);
      ref.invalidate(adminReadingPageProvider);
      ref.invalidate(adminAuditFeedProvider);
    }

    _pushAudit(
      'admin.reading.questions.generated',
      '${reading.title} / ${savedDetail.questions.length} soru',
    );
    _showSnackBar('${savedDetail.questions.length} soru kaydedildi.');
  }

  Future<void> _startReadingAiBackfill(
    BuildContext context, {
    required String jobType,
  }) async {
    final activeRun = switch (jobType) {
      'question_backfill' => _activeQuestionRun,
      _ => _activeCoverRun,
    };
    if (activeRun != null && activeRun.isActive) {
      await _showReadingAiRunDialog(
        context,
        jobType: jobType,
        initialRun: activeRun,
      );
      return;
    }

    final filteredReadings = await _loadFilteredReadingsForBackfill();
    if (!mounted || !context.mounted) {
      return;
    }

    final targetReadings = _sortReadingsForBackfill(
      filteredReadings
        .where(
          (item) => jobType == 'question_backfill'
              ? item.questionCount == 0
              : !item.hasCover,
        )
        .toList(growable: false),
      jobType: jobType,
    );
    if (targetReadings.isEmpty) {
      _showSnackBar(
        jobType == 'question_backfill'
            ? 'Secili filtrede mini testi eksik kayit yok.'
            : 'Secili filtrede kapagi eksik kayit yok.',
      );
      return;
    }

    await _showReadingAiRunDialog(
      context,
      jobType: jobType,
      targetReadings: targetReadings,
      filterSnapshot: _buildReadingAiFilterSnapshot(
        jobType: jobType,
        targetCount: targetReadings.length,
      ),
    );
  }

  Future<void> _restoreActiveReadingAiRuns() async {
    if (!mounted ||
        _isPreviewMode ||
        widget.destination != AdminDestination.readings) {
      return;
    }

    final runResult = await ref
        .read(adminAiReadingRepositoryProvider)
        .listActiveReadingAiRuns();
    if (!mounted) {
      return;
    }

    if (runResult case AppFailure<List<AdminAiReadingRun>>()) {
      return;
    }

    final runs = (runResult as AppSuccess<List<AdminAiReadingRun>>).value;
    setState(() {
      _activeQuestionRun = _firstActiveReadingAiRunForJobType(
        runs,
        'question_backfill',
      );
      _activeCoverRun = _firstActiveReadingAiRunForJobType(
        runs,
        'cover_backfill',
      );
    });
  }

  Future<void> _showReadingAiRunDialog(
    BuildContext context, {
    required String jobType,
    AdminAiReadingRun? initialRun,
    List<AdminReadingRecord> targetReadings = const <AdminReadingRecord>[],
    Map<String, dynamic>? filterSnapshot,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _ReadingAiRunDialog(
        jobType: jobType,
        targetReadings: targetReadings,
        initialRun: initialRun,
        filterSnapshot:
            filterSnapshot ??
            initialRun?.filterSnapshot ??
            const <String, dynamic>{},
        repository: ref.read(adminAiReadingRepositoryProvider),
        onRunChanged: (run) => _setActiveReadingAiRun(jobType, run),
        onRunSettled: _handleReadingAiRunSettled,
        onMessage: _showSnackBar,
      ),
    );
  }

  void _setActiveReadingAiRun(String jobType, AdminAiReadingRun? run) {
    if (!mounted) {
      return;
    }
    setState(() {
      final normalized = run != null && run.isActive ? run : null;
      if (jobType == 'question_backfill') {
        _activeQuestionRun = normalized;
      } else {
        _activeCoverRun = normalized;
      }
    });
  }

  void _handleReadingAiRunSettled(AdminAiReadingRun run) {
    ref.read(adminReadingChangesProvider.notifier).clear();
    ref.invalidate(adminReadingsProvider);
    ref.invalidate(adminReadingPageProvider);
    ref.invalidate(adminAuditFeedProvider);

    final message = switch (run.status) {
      'cancelled' => run.jobType == 'question_backfill'
          ? 'Mini test backfill durduruldu. ${run.processedCount} kayit islendi.'
          : 'Kapak backfill durduruldu. ${run.processedCount} kayit islendi.',
      'failed' => run.jobType == 'question_backfill'
          ? 'Mini test backfill basarisiz oldu: ${run.failedCount} hata.'
          : 'Kapak backfill basarisiz oldu: ${run.failedCount} hata.',
      _ => run.jobType == 'question_backfill'
          ? 'Mini test backfill tamamlandi: ${run.succeededCount} basarili, ${run.failedCount} hata.'
          : 'Kapak backfill tamamlandi: ${run.succeededCount} basarili, ${run.failedCount} hata.',
    };
    _showSnackBar(
      message,
      isError: run.status == 'failed' || (run.failedCount > 0 && run.succeededCount == 0),
    );
  }

  Map<String, dynamic> _buildReadingAiFilterSnapshot({
    required String jobType,
    required int targetCount,
  }) {
    return <String, dynamic>{
      'job_type': jobType,
      'query': _readingsFilters.query,
      'level': _readingsFilters.level,
      'is_published': _readingsFilters.isPublished,
      'has_questions': _readingsFilters.hasQuestions,
      'has_cover': _readingsFilters.hasCover,
      'target_count': targetCount,
    };
  }

  Future<List<AdminReadingRecord>> _loadFilteredReadingsForBackfill() async {
    final allReadings = await ref.read(adminReadingsProvider.future);
    return allReadings.where((item) {
      final matchesLevel =
          _readingsFilters.level == null || item.level == _readingsFilters.level;
      final matchesPublished =
          _readingsFilters.isPublished == null ||
          item.isPublished == _readingsFilters.isPublished;
      final matchesQuestions = _readingsFilters.hasQuestions == null
          ? true
          : _readingsFilters.hasQuestions!
          ? item.questionCount > 0
          : item.questionCount == 0;
      final matchesCover = _readingsFilters.hasCover == null
          ? true
          : item.hasCover == _readingsFilters.hasCover;
      final haystack =
          '${item.title} ${item.category ?? ''} ${item.level ?? ''} ${item.tagsRaw ?? ''}'
              .toLowerCase();
      final matchesQuery = _readingsFilters.query.isEmpty ||
          haystack.contains(_readingsFilters.query.toLowerCase());
      return matchesLevel &&
          matchesPublished &&
          matchesQuestions &&
          matchesCover &&
          matchesQuery;
    }).toList(growable: false);
  }

  List<AdminReadingRecord> _sortReadingsForBackfill(
    List<AdminReadingRecord> readings, {
    required String jobType,
  }) {
    if (jobType != 'cover_backfill') {
      return readings;
    }
    final sorted = List<AdminReadingRecord>.from(readings);
    sorted.sort((left, right) {
      final titleCompare = left.title.toLowerCase().compareTo(
        right.title.toLowerCase(),
      );
      if (titleCompare != 0) {
        return titleCompare;
      }
      return left.id.compareTo(right.id);
    });
    return sorted;
  }

  Future<void> _openGrammarEditor(
    BuildContext context, {
    AdminGrammarRecord? existing,
  }) async {
    final detail = existing == null
        ? const AdminGrammarModuleDetail()
        : await _loadGrammarDetail(existing);
    if (detail == null || !context.mounted) {
      return;
    }

    final draft = await showDialog<AdminGrammarModuleDetail>(
      context: context,
      builder: (context) => _GrammarEditorDialog(initialDetail: detail),
    );
    if (draft == null) {
      return;
    }

    final result = await ref
        .read(adminContentRepositoryProvider)
        .upsertGrammarModuleDetail(draft);
    if (!mounted) {
      return;
    }

    if (result case AppFailure<AdminGrammarModuleDetail>()) {
      _showSnackBar(result.message, isError: true);
      return;
    }

    final savedDetail = (result as AppSuccess<AdminGrammarModuleDetail>).value;
    if (_isPreviewMode) {
      final currentModules = await ref.read(adminGrammarModulesProvider.future);
      final nextId = currentModules.fold<int>(
        0,
        (maxId, item) => math.max(maxId, item.id),
      );
      final record =
          (existing ??
                  AdminGrammarRecord(
                    id:
                        int.tryParse(savedDetail.metadata.id ?? '') ??
                        (nextId + 1),
                    sortOrder: savedDetail.sortOrder,
                    title: savedDetail.title,
                    fileName: savedDetail.fileName,
                    pageCount: savedDetail.pages.length,
                    icon: savedDetail.icon,
                    color: savedDetail.color,
                    isPublished: savedDetail.isPublished,
                    updatedAtLabel: 'az once',
                  ))
              .copyWith(
                title: savedDetail.title,
                fileName: savedDetail.fileName,
                pageCount: savedDetail.pages.length,
                icon: savedDetail.icon,
                color: savedDetail.color,
                isPublished: savedDetail.isPublished,
                updatedAtLabel: 'az once',
              );
      ref.read(adminGrammarChangesProvider.notifier).upsert(record);
    } else {
      if (existing != null) {
        ref
            .read(adminGrammarChangesProvider.notifier)
            .upsert(
              existing.copyWith(
                sortOrder: savedDetail.sortOrder,
                title: savedDetail.title,
                fileName: savedDetail.fileName,
                pageCount: savedDetail.pages.length,
                icon: savedDetail.icon,
                color: savedDetail.color,
                isPublished: savedDetail.isPublished,
                updatedAtLabel: 'az once',
              ),
            );
      }
      ref.invalidate(adminGrammarModulesProvider);
      ref.invalidate(adminDashboardSnapshotProvider);
      ref.invalidate(adminAuditFeedProvider);
    }

    _pushAudit(
      existing == null ? 'admin.grammar.created' : 'admin.grammar.updated',
      savedDetail.title,
    );
    _showSnackBar(
      existing == null
          ? 'Gramer modulu olusturuldu.'
          : 'Gramer modulu guncellendi.',
    );
  }

  Future<void> _deleteGrammar(
    BuildContext context,
    AdminGrammarRecord module,
  ) async {
    final shouldDelete = await _confirmAction(
      context,
      title: 'Modulu sil',
      description:
          '${module.title} modulu kaldirilacak. Bagli sayfalar ve testler de etkilenir.',
      confirmLabel: 'Modulu Sil',
      isDestructive: true,
    );
    if (!shouldDelete) {
      return;
    }

    final result = await ref
        .read(adminContentRepositoryProvider)
        .deleteGrammarModule(moduleId: module.id);
    if (!mounted) {
      return;
    }

    if (result case AppFailure<void>()) {
      _showSnackBar(result.message, isError: true);
      return;
    }

    if (_isPreviewMode) {
      ref
          .read(adminGrammarChangesProvider.notifier)
          .remove(module.id.toString());
    } else {
      ref
          .read(adminGrammarChangesProvider.notifier)
          .remove(module.id.toString());
      ref.invalidate(adminGrammarModulesProvider);
      ref.invalidate(adminDashboardSnapshotProvider);
      ref.invalidate(adminAuditFeedProvider);
    }

    _pushAudit('admin.grammar.deleted', module.title);
    _showSnackBar('Gramer modulu silindi.');
  }

  Future<void> _togglePublishedForGrammar(
    BuildContext context,
    AdminGrammarRecord module,
    bool nextValue,
  ) async {
    final shouldProceed = await _confirmAction(
      context,
      title: nextValue ? 'Modulu yayinla' : 'Modulu taslaga al',
      description:
          'Gramer modul gorunurlugu student yuzeylerinde veri seviyesinde degisir.',
      confirmLabel: nextValue ? 'Yayinla' : 'Taslak Yap',
    );
    if (!shouldProceed) {
      return;
    }

    final result = await ref
        .read(adminContentRepositoryProvider)
        .setContentPublished(
          entityType: 'grammar',
          entityId: module.id.toString(),
          isPublished: nextValue,
        );
    if (!mounted) {
      return;
    }

    if (result case AppFailure<void>()) {
      _showSnackBar(result.message, isError: true);
      return;
    }

    if (_isPreviewMode) {
      ref
          .read(adminGrammarChangesProvider.notifier)
          .upsert(
            module.copyWith(isPublished: nextValue, updatedAtLabel: 'az once'),
          );
    } else {
      ref
          .read(adminGrammarChangesProvider.notifier)
          .upsert(
            module.copyWith(isPublished: nextValue, updatedAtLabel: 'az once'),
          );
      ref.invalidate(adminGrammarModulesProvider);
      ref.invalidate(adminDashboardSnapshotProvider);
      ref.invalidate(adminAuditFeedProvider);
    }

    _pushAudit(
      nextValue ? 'content.published' : 'content.unpublished',
      'grammar / ${module.title}',
    );
    _showSnackBar(nextValue ? 'Modul yayinda.' : 'Modul taslaga alindi.');
  }

  Future<void> _reorderGrammar(
    BuildContext context,
    List<AdminGrammarRecord> modules,
    int currentIndex,
    int targetIndex,
  ) async {
    if (targetIndex < 0 || targetIndex >= modules.length) {
      return;
    }

    final reordered = modules.toList(growable: true);
    final item = reordered.removeAt(currentIndex);
    reordered.insert(targetIndex, item);

    final normalized = <AdminGrammarRecord>[
      for (var index = 0; index < reordered.length; index++)
        reordered[index].copyWith(
          sortOrder: index + 1,
          updatedAtLabel: 'az once',
        ),
    ];

    if (_isPreviewMode) {
      final notifier = ref.read(adminGrammarChangesProvider.notifier);
      for (final module in normalized) {
        notifier.upsert(module);
      }
      _pushAudit('admin.grammar.reordered', '${item.title} sirasi guncellendi');
      _showSnackBar('Gramer sirasi guncellendi.');
      return;
    }

    final result = await ref
        .read(adminContentRepositoryProvider)
        .reorderGrammarModules(
          moduleIdsInOrder: normalized
              .map((item) => item.id)
              .toList(growable: false),
        );
    if (!mounted) {
      return;
    }

    if (result case AppFailure<void>()) {
      _showSnackBar(result.message, isError: true);
      return;
    }

    ref.read(adminGrammarChangesProvider.notifier).clear();
    ref.invalidate(adminGrammarModulesProvider);
    ref.invalidate(adminDashboardSnapshotProvider);
    ref.invalidate(adminAuditFeedProvider);
    _pushAudit('admin.grammar.reordered', '${item.title} sirasi guncellendi');
    _showSnackBar('Gramer sirasi guncellendi.');
  }

  Future<AdminWordDetail?> _loadWordDetail(AdminWordRecord existing) async {
    if (_isPreviewMode) {
      return AdminWordDetail(
        metadata: AdminContentMetadata(id: existing.id),
        packId: existing.packId,
        enWord: existing.enWord,
        trMeaning: existing.trMeaning,
        pos: existing.pos,
        exampleEn: existing.exampleEn,
        exampleTr: existing.exampleTr,
        level: existing.level,
        notes: existing.notes,
        isPublished: existing.isPublished,
      );
    }

    final result = await ref
        .read(adminContentRepositoryProvider)
        .fetchWordDetail(wordId: existing.id);
    if (result case AppSuccess<AdminWordDetail>()) {
      return result.value;
    }
    _showSnackBar(
      (result as AppFailure<AdminWordDetail>).message,
      isError: true,
    );
    return null;
  }

  Future<AdminReadingDetail?> _loadReadingDetail(
    AdminReadingRecord existing,
  ) async {
    if (_isPreviewMode) {
      return AdminReadingDetail(
        metadata: AdminContentMetadata(id: existing.id),
        packId: existing.packId,
        title: existing.title,
        level: existing.level,
        category: existing.category,
        tagsRaw: existing.tagsRaw,
        isPro: existing.isPro,
        isPublished: existing.isPublished,
      );
    }

    final result = await ref
        .read(adminContentRepositoryProvider)
        .fetchReadingDetail(readingId: existing.id);
    if (result case AppSuccess<AdminReadingDetail>()) {
      return result.value;
    }
    _showSnackBar(
      (result as AppFailure<AdminReadingDetail>).message,
      isError: true,
    );
    return null;
  }

  AdminReadingRecord _readingRecordFromDetail({
    required AdminReadingDetail detail,
    required List<AdminPackRecord> packs,
    AdminReadingRecord? existing,
  }) {
    return adminReadingRecordFromDetail(
      detail: detail,
      packs: packs,
      existing: existing,
      fallbackId: _clientId('reading'),
    );
  }

  Future<AppResult<AdminReadingDetail>> _generateCoverForReadingDetail(
    AdminReadingDetail detail,
    String selectedModel,
  ) async {
    final readingId = detail.metadata.id?.trim();
    if (readingId == null || readingId.isEmpty) {
      return const AppFailure<AdminReadingDetail>(
        'Cover uretimi icin reading once kaydedilmeli.',
      );
    }
    final result = await ref
        .read(adminAiReadingRepositoryProvider)
        .generateReadingCover(
          AdminAiGenerateReadingCoverRequest(
            readingId: readingId,
            provider: adminAiCoverProviderForModel(selectedModel),
            model: selectedModel,
          ),
        );
    ref.invalidate(adminAiCoverPoolStatusProvider);
    return result;
  }

  Future<AppResult<AdminReadingDetail>> _uploadCoverForReadingDetail({
    required AdminReadingDetail detail,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String? altText,
  }) async {
    final readingId = detail.metadata.id?.trim();
    if (readingId == null || readingId.isEmpty) {
      return const AppFailure<AdminReadingDetail>(
        'Cover yuklemek icin reading once kaydedilmeli.',
      );
    }
    return ref.read(adminContentRepositoryProvider).uploadReadingCover(
      readingId: readingId,
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
      altText: altText,
    );
  }

  Future<AppResult<AdminReadingDetail>> _removeCoverForReadingDetail(
    AdminReadingDetail detail,
  ) async {
    final readingId = detail.metadata.id?.trim();
    if (readingId == null || readingId.isEmpty) {
      return const AppFailure<AdminReadingDetail>(
        'Cover silmek icin reading once kaydedilmeli.',
      );
    }
    return ref
        .read(adminContentRepositoryProvider)
        .removeReadingCover(readingId: readingId);
  }

  Future<AdminGrammarModuleDetail?> _loadGrammarDetail(
    AdminGrammarRecord existing,
  ) async {
    if (_isPreviewMode) {
      return AdminGrammarModuleDetail(
        metadata: AdminContentMetadata(id: existing.id.toString()),
        sortOrder: existing.sortOrder,
        title: existing.title,
        fileName: existing.fileName,
        icon: existing.icon,
        color: existing.color,
        isPublished: existing.isPublished,
      );
    }

    final result = await ref
        .read(adminContentRepositoryProvider)
        .fetchGrammarModuleDetail(moduleId: existing.id);
    if (result case AppSuccess<AdminGrammarModuleDetail>()) {
      return result.value;
    }
    _showSnackBar(
      (result as AppFailure<AdminGrammarModuleDetail>).message,
      isError: true,
    );
    return null;
  }

  void _resetWordFilters() {
    _wordsQueryController.clear();
    setState(() {
      _wordsFilters = _wordsFilters.copyWith(
        query: '',
        offset: 0,
        clearPublished: true,
      );
    });
  }

  void _resetReadingFilters() {
    _readingsQueryController.clear();
    setState(() {
      _readingsFilters = _readingsFilters.copyWith(
        query: '',
        offset: 0,
        clearLevel: true,
        clearPublished: true,
        clearHasQuestions: true,
        clearHasCover: true,
      );
    });
  }

  void _resetGrammarFilters() {
    _grammarQueryController.clear();
    setState(() {
      _grammarFilters = _grammarFilters.copyWith(
        query: '',
        clearPublished: true,
      );
    });
  }

  Future<void> _showBulkFocusWordSummary(
    BuildContext context,
    AdminBulkReadingFocusWordAssignmentResult summary,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Toplu odak kelime atama sonucu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Islenen pasaj: ${summary.processedCount}'),
            Text('Atama yapilan pasaj: ${summary.assignedCount}'),
            Text('Atlanan mevcut kayit: ${summary.skippedExistingCount}'),
            Text('Eslesme bulunamayan: ${summary.noMatchCount}'),
            Text('Hata alan: ${summary.errorCount}'),
            if (summary.sampleFailures.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Ornek hatalar:'),
              const SizedBox(height: 6),
              for (final item in summary.sampleFailures)
                Text(item, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  Future<_QuestionGenerationConfig?> _openQuestionGenerationDialog(
    BuildContext context, {
    required bool replaceExisting,
  }) async {
    var provider = adminAiProviderGemini;
    String? model = adminAiGeminiDefaultModel;
    final questionCountController = TextEditingController(text: '3');

    final result = await showDialog<_QuestionGenerationConfig>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final modelOptions = adminAiModelsForProvider(provider);
            model ??= adminAiDefaultModelForProvider(provider);
            return AlertDialog(
              title: Text(
                replaceExisting ? 'Mini Testleri Yeniden Uret' : 'Mini Test Uret',
              ),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (replaceExisting) ...[
                      const Text(
                        'Bu islem mevcut sorulari yeni AI sonucuyla degistirecek.',
                      ),
                      const SizedBox(height: 12),
                    ],
                    DropdownButtonFormField<String>(
                      initialValue: provider,
                      decoration: const InputDecoration(labelText: 'Provider'),
                      items: const [
                        DropdownMenuItem(
                          value: adminAiProviderGemini,
                          child: Text('Gemini'),
                        ),
                        DropdownMenuItem(
                          value: adminAiProviderOpenRouter,
                          child: Text('OpenRouter'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setModalState(() {
                          provider = value;
                          model = adminAiDefaultModelForProvider(value);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: model,
                      decoration: const InputDecoration(labelText: 'Model'),
                      items: [
                        for (final item in modelOptions)
                          DropdownMenuItem(
                            value: item,
                            child: Text(adminAiModelLabel(item)),
                          ),
                      ],
                      onChanged: modelOptions.length <= 1
                          ? null
                          : (value) {
                              setModalState(() {
                                model = value;
                              });
                            },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: questionCountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Question Count',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Vazgec'),
                ),
                FilledButton(
                  onPressed: () {
                    final questionCount =
                        int.tryParse(questionCountController.text.trim()) ?? 0;
                    if (questionCount < 1) {
                      return;
                    }
                    Navigator.of(dialogContext).pop(
                      _QuestionGenerationConfig(
                        provider: provider,
                        model: model,
                        questionCount: questionCount,
                      ),
                    );
                  },
                  child: const Text('Baslat'),
                ),
              ],
            );
          },
        );
      },
    );

    questionCountController.dispose();
    return result;
  }

  Future<bool> _confirmAction(
    BuildContext context, {
    required String title,
    required String description,
    required String confirmLabel,
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgec'),
          ),
          FilledButton(
            style: isDestructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  )
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _ensureSelectedPack(List<AdminPackRecord> packs) {
    if (packs.isEmpty) {
      return;
    }
    final hasSelected = packs.any((item) => item.id == _wordsFilters.packId);
    if (_wordsFilters.packId == null || !hasSelected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _wordsFilters = _wordsFilters.copyWith(packId: packs.first.id);
        });
      });
    }
  }

  void _pushAudit(String title, String subtitle) {
    ref
        .read(adminAuditOverridesProvider.notifier)
        .push(
          AdminAuditRecord(
            id: '$title-${DateTime.now().microsecondsSinceEpoch}',
            title: title,
            subtitle: subtitle,
            timestampLabel: 'az once',
          ),
        );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        content: Text(message),
      ),
    );
  }

  String _packLabelForReading(
    AdminReadingRecord reading,
    List<AdminPackRecord> packs,
  ) {
    if (reading.packName != null && reading.packName!.trim().isNotEmpty) {
      return reading.packName!;
    }
    if (reading.packId == null || reading.packId!.isEmpty) {
      return '-';
    }
    for (final pack in packs) {
      if (pack.id == reading.packId) {
        return pack.name;
      }
    }
    return reading.packId!;
  }

  String _clientId(String prefix) {
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}';
  }

  String _titleFor(AdminDestination destination) => switch (destination) {
    AdminDestination.aiAssistant => 'AI Asistan',
    AdminDestination.readings => 'Okuma CMS',
    AdminDestination.words => 'Kelime CMS',
    AdminDestination.grammar => 'Gramer CMS',
    _ => 'Icerik CMS',
  };

  String _subtitleFor(AdminDestination destination) => switch (destination) {
    AdminDestination.aiAssistant =>
      'AI ile reading taslagi uret, linked wordleri coz ve yayina al.',
    AdminDestination.readings =>
      'Parca olustur, guncelle ve yayin akislarini dogrudan panelden yonet.',
    AdminDestination.words =>
      'Paket bazli kelime operasyonlari, import ve publish kontrolu tek ekranda.',
    AdminDestination.grammar =>
      'Modul CRUD, siralama ve yayin durumu ayni operasyon katmaninda.',
    _ => 'Icerik operasyonlari.',
  };
}

class _PackTile extends StatelessWidget {
  const _PackTile({
    required this.pack,
    required this.isSelected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePublished,
  });

  final AdminPackRecord pack;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onTogglePublished;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? tokens.accentSoft.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? tokens.accent : tokens.surfaceBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    pack.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Switch(value: pack.isPublished, onChanged: onTogglePublished),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MetricChip(label: '${pack.wordCount} kelime'),
                _MetricChip(label: pack.isPublished ? 'yayinda' : 'taslak'),
                _MetricChip(label: 'guncel ${pack.updatedAtLabel}'),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Duzenle'),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Sil'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WordRow extends StatelessWidget {
  const _WordRow({
    required this.word,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePublished,
  });

  final AdminWordRecord word;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onTogglePublished;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  word.enWord,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  word.trMeaning,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: tokens.secondaryText),
                ),
                if (word.notes != null && word.notes!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    word.notes!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  'Olusturma: ${word.createdAtLabel ?? '-'} | Guncelleyen: ${word.updatedByLabel ?? '-'}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: tokens.secondaryText),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricChip(label: word.pos),
                if (word.level != null && word.level!.isNotEmpty)
                  _MetricChip(label: word.level!),
                _MetricChip(label: 'guncel ${word.updatedAtLabel}'),
                _MetricChip(label: word.isPublished ? 'yayinda' : 'taslak'),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              word.exampleEn,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(value: word.isPublished, onChanged: onTogglePublished),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReadingRow extends StatelessWidget {
  const _ReadingRow({
    required this.reading,
    required this.packLabel,
    required this.onEdit,
    required this.onDelete,
    required this.onAutoAssign,
    required this.onGenerateQuestions,
    required this.onTogglePublished,
  });

  final AdminReadingRecord reading;
  final String packLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onAutoAssign;
  final VoidCallback? onGenerateQuestions;
  final ValueChanged<bool> onTogglePublished;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reading.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Paket: $packLabel',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: tokens.secondaryText),
                ),
                const SizedBox(height: 6),
                Text(
                  'Olusturma: ${reading.createdAtLabel ?? '-'} | Guncelleyen: ${reading.updatedByLabel ?? '-'}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: tokens.secondaryText),
                ),
                const SizedBox(height: 6),
                Text(
                  reading.linkedWordCount == 0
                      ? 'Odak kelimeler: atanmamis'
                      : 'Odak kelimeler (${reading.linkedWordCount}): ${reading.linkedWordsPreview.join(', ')}${reading.linkedWordCount > reading.linkedWordsPreview.length ? ' ...' : ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: tokens.secondaryText),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricChip(label: reading.level ?? '-'),
                _MetricChip(label: reading.category ?? '-'),
                _MetricChip(label: reading.isPro ? 'pro' : 'free'),
                _MetricChip(label: 'odak ${reading.linkedWordCount}'),
                _MetricChip(label: 'mini test ${reading.questionCount}'),
                _MetricChip(label: reading.hasCover ? 'kapak var' : 'kapak yok'),
                _MetricChip(label: 'guncel ${reading.updatedAtLabel}'),
                _MetricChip(label: reading.isPublished ? 'yayinda' : 'taslak'),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              reading.tagsRaw?.isNotEmpty == true ? reading.tagsRaw! : '-',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(value: reading.isPublished, onChanged: onTogglePublished),
              IconButton(
                onPressed: onGenerateQuestions,
                tooltip: 'Mini test uret',
                icon: const Icon(Icons.quiz_outlined),
              ),
              IconButton(
                onPressed: onAutoAssign,
                tooltip: 'Odak kelimeleri otomatik ata',
                icon: const Icon(Icons.auto_awesome_rounded),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GrammarRow extends StatelessWidget {
  const _GrammarRow({
    required this.module,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePublished,
  });

  final AdminGrammarRecord module;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onTogglePublished;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              '#${module.sortOrder}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  module.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(module.fileName),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricChip(label: '${module.pageCount} sayfa'),
                _MetricChip(label: module.updatedAtLabel),
                _MetricChip(label: module.color),
              ],
            ),
          ),
          SizedBox(width: 64, child: Text(module.icon)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: canMoveUp ? onMoveUp : null,
                icon: const Icon(Icons.keyboard_arrow_up_rounded),
              ),
              IconButton(
                onPressed: canMoveDown ? onMoveDown : null,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
              ),
              Switch(value: module.isPublished, onChanged: onTogglePublished),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: tokens.secondaryText,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ReadingAiRunProgressCard extends StatelessWidget {
  const _ReadingAiRunProgressCard({
    this.questionRun,
    this.coverRun,
    this.onOpenQuestionRun,
    this.onOpenCoverRun,
  });

  final AdminAiReadingRun? questionRun;
  final AdminAiReadingRun? coverRun;
  final VoidCallback? onOpenQuestionRun;
  final VoidCallback? onOpenCoverRun;

  @override
  Widget build(BuildContext context) {
    return AdminPanelCard(
      title: 'AI Backfill Progress',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (questionRun != null)
            _RunSummaryTile(
              title: 'Mini Test',
              run: questionRun!,
              onOpen: onOpenQuestionRun,
            ),
          if (questionRun != null && coverRun != null) const SizedBox(height: 12),
          if (coverRun != null)
            _RunSummaryTile(
              title: 'Cover',
              run: coverRun!,
              onOpen: onOpenCoverRun,
            ),
        ],
      ),
    );
  }
}

class _RunSummaryTile extends StatelessWidget {
  const _RunSummaryTile({
    required this.title,
    required this.run,
    this.onOpen,
  });

  final String title;
  final AdminAiReadingRun run;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('$title / ${run.status}')),
            if (onOpen != null)
              FilledButton.tonal(
                onPressed: onOpen,
                child: const Text('Ac'),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Toplam ${run.totalCount}, islenen ${run.processedCount}, basarili ${run.succeededCount}, hata ${run.failedCount}, atlandi ${run.skippedCount}',
        ),
        if (run.pauseReason != null && run.pauseReason!.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(_runPauseReasonLabel(run)),
        ],
        if (run.failureSamples.isNotEmpty) ...[
          const SizedBox(height: 6),
          for (final item in run.failureSamples.take(3))
            Text(item, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ],
    );
  }
}

class _QuestionGenerationConfig {
  const _QuestionGenerationConfig({
    required this.provider,
    required this.model,
    required this.questionCount,
  });

  final String provider;
  final String? model;
  final int questionCount;
}

typedef _AdminMessageCallback = void Function(String message, {bool isError});

class _ReadingAiRunDialog extends StatefulWidget {
  const _ReadingAiRunDialog({
    required this.jobType,
    required this.targetReadings,
    required this.filterSnapshot,
    required this.repository,
    required this.onRunChanged,
    required this.onRunSettled,
    required this.onMessage,
    this.initialRun,
  });

  final String jobType;
  final List<AdminReadingRecord> targetReadings;
  final Map<String, dynamic> filterSnapshot;
  final AdminAiReadingRepository repository;
  final ValueChanged<AdminAiReadingRun?> onRunChanged;
  final ValueChanged<AdminAiReadingRun> onRunSettled;
  final _AdminMessageCallback onMessage;
  final AdminAiReadingRun? initialRun;

  @override
  State<_ReadingAiRunDialog> createState() => _ReadingAiRunDialogState();
}

class _ReadingAiRunDialogState extends State<_ReadingAiRunDialog> {
  AdminAiReadingRun? _run;
  late final TextEditingController _questionCountController;
  String _questionProvider = adminAiProviderGemini;
  String? _questionModel = adminAiGeminiDefaultModel;
  String _coverModel = adminAiCoverAutoModel;
  AdminAiCoverPoolStatus? _coverPoolStatus;
  String? _errorText;
  bool _isActing = false;
  bool _isPumping = false;
  bool _settledNotified = false;

  bool get _isQuestionJob => widget.jobType == 'question_backfill';
  bool get _canStart => widget.targetReadings.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _run = widget.initialRun;
    _questionCountController = TextEditingController(
      text: (_run?.questionCount ?? 3).toString(),
    );
    if (_run != null) {
      _questionProvider = _run!.provider == adminAiProviderOpenRouter
          ? adminAiProviderOpenRouter
          : adminAiProviderGemini;
      _questionModel =
          _run!.model.isEmpty ? adminAiGeminiDefaultModel : _run!.model;
      _coverModel =
          _run!.model.isEmpty ? adminAiCoverAutoModel : _run!.model;
      _settledNotified = !_run!.isActive;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isQuestionJob) {
        unawaited(_refreshCoverPoolStatus());
      }
    });
  }

  @override
  void dispose() {
    _questionCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final run = _run;
    final title = _isQuestionJob ? 'Mini Test Uret' : 'Cover Backfill';
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 620,
        child: run == null ? _buildConfigBody(context) : _buildProgressBody(context, run),
      ),
      actions: _buildActions(context, run),
    );
  }

  Widget _buildConfigBody(BuildContext context) {
    final availableCoverModels = _availableCoverModels;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hedef kayit: ${widget.targetReadings.length}'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in _filterSummaryLines(widget.filterSnapshot))
              _MetricChip(label: item),
          ],
        ),
        const SizedBox(height: 16),
        if (_isQuestionJob) ...[
          DropdownButtonFormField<String>(
            initialValue: _questionProvider,
            decoration: const InputDecoration(labelText: 'Provider'),
            items: const [
              DropdownMenuItem(
                value: adminAiProviderGemini,
                child: Text('Gemini'),
              ),
              DropdownMenuItem(
                value: adminAiProviderOpenRouter,
                child: Text('OpenRouter'),
              ),
            ],
            onChanged: _isActing
                ? null
                : (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _questionProvider = value;
                      _questionModel = adminAiDefaultModelForProvider(value);
                    });
                  },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _questionModel,
            decoration: const InputDecoration(labelText: 'Model'),
            items: [
              for (final item in adminAiModelsForProvider(_questionProvider))
                DropdownMenuItem(
                  value: item,
                  child: Text(adminAiModelLabel(item)),
                ),
            ],
            onChanged: adminAiModelsForProvider(_questionProvider).length <= 1 ||
                    _isActing
                ? null
                : (value) {
                    setState(() {
                      _questionModel = value;
                    });
                  },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _questionCountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Question Count'),
            enabled: !_isActing,
          ),
        ] else ...[
          DropdownButtonFormField<String>(
            initialValue: availableCoverModels.contains(_coverModel)
                ? _coverModel
                : adminAiCoverAutoModel,
            decoration: const InputDecoration(labelText: 'Model'),
            items: [
              for (final item in availableCoverModels)
                DropdownMenuItem(
                  value: item,
                  child: Text(adminAiModelLabel(item)),
                ),
            ],
            onChanged: _isActing
                ? null
                : (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _coverModel = value;
                    });
                  },
          ),
          const SizedBox(height: 12),
          _buildCoverUsageSummary(context),
        ],
        if (_errorText != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorText!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _buildProgressBody(BuildContext context, AdminAiReadingRun run) {
    final canEditCoverModel = !_isQuestionJob && (run.status == 'paused' || run.status == 'queued');
    final availableCoverModels = _availableCoverModels;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${_jobLabel(run.jobType)} / ${run.status}'),
        if (run.isActive && !run.isPaused && !_isPumping) ...[
          const SizedBox(height: 12),
          Text(
            "Bu run aktif durumda. Isleme devam etmek icin Devam Et'e basin.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: run.totalCount <= 0
              ? null
              : run.processedCount / run.totalCount,
        ),
        const SizedBox(height: 12),
        Text(
          'Toplam ${run.totalCount}, islenen ${run.processedCount}, basarili ${run.succeededCount}, hata ${run.failedCount}, atlandi ${run.skippedCount}',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in _filterSummaryLines(run.filterSnapshot))
              _MetricChip(label: item),
            _MetricChip(label: 'Model ${adminAiModelLabel(run.model)}'),
            if (run.skippedCount > 0)
              _MetricChip(label: 'Atlandi ${run.skippedCount}'),
            if (run.consecutiveFailureCount > 0)
              _MetricChip(label: 'Art arda hata ${run.consecutiveFailureCount}'),
          ],
        ),
        if (!_isQuestionJob) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: availableCoverModels.contains(_coverModel)
                ? _coverModel
                : adminAiCoverAutoModel,
            decoration: const InputDecoration(labelText: 'Model'),
            items: [
              for (final item in availableCoverModels)
                DropdownMenuItem(
                  value: item,
                  child: Text(adminAiModelLabel(item)),
                ),
            ],
            onChanged: canEditCoverModel
                ? (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _coverModel = value;
                    });
                  }
                : null,
          ),
          const SizedBox(height: 12),
          _buildCoverUsageSummary(context),
        ],
        if (run.pauseReason != null && run.pauseReason!.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(_runPauseReasonLabel(run)),
        ],
        if (run.lastErrorMessage != null && run.lastErrorMessage!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            run.lastErrorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (run.failureSamples.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Son 5 hata',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer.withValues(
                alpha: 0.35,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.error.withValues(
                  alpha: 0.35,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in run.failureSamples.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Text('• '),
                        ),
                        Expanded(
                          child: Text(
                            item,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (_errorText != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorText!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildActions(BuildContext context, AdminAiReadingRun? run) {
    if (run == null) {
      return [
        TextButton(
          onPressed: _isActing ? null : () => Navigator.of(context).pop(),
          child: const Text('Vazgec'),
        ),
        FilledButton(
          onPressed: _isActing || !_canStart ? null : _handleStart,
          child: _isActing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Baslat'),
        ),
      ];
    }

    final canPause = !_isActing && (run.status == 'running' || run.status == 'queued');
    final canContinue = !_isActing && !_isPumping && run.isActive;
    final canCancel = !_isActing && run.isActive;
    return [
      TextButton(
        onPressed: _isActing ? null : () => Navigator.of(context).pop(),
        child: const Text('Kapat'),
      ),
      if (canPause)
        FilledButton.tonal(
          onPressed: _handlePause,
          child: const Text('Duraklat'),
        ),
      if (run.isActive)
        FilledButton.tonal(
          onPressed: canContinue ? _handleContinue : null,
          child: const Text('Devam Et'),
        ),
      if (canCancel)
        FilledButton(
          onPressed: _handleCancel,
          child: const Text('Durdur'),
        ),
    ];
  }

  Future<void> _handleStart() async {
    setState(() {
      _isActing = true;
      _errorText = null;
    });

    final questionCount =
        int.tryParse(_questionCountController.text.trim()) ?? 0;
    if (_isQuestionJob && questionCount < 1) {
      setState(() {
        _isActing = false;
        _errorText = 'Question count en az 1 olmalidir.';
      });
      return;
    }

    final model = _isQuestionJob ? _questionModel : _coverModel;
    final provider = _isQuestionJob
        ? _questionProvider
        : adminAiCoverProviderForModel(_coverModel);
    final result = await widget.repository.createReadingAiRun(
      AdminAiReadingRunRequest(
        jobType: widget.jobType,
        readingIds: widget.targetReadings
            .map((item) => item.id)
            .toList(growable: false),
        provider: provider,
        model: model,
        questionCount: questionCount > 0 ? questionCount : 3,
        filterSnapshot: widget.filterSnapshot,
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isActing = false;
    });

    if (result case AppSuccess<AdminAiReadingRun>(value: final run)) {
      _applyRun(run);
      if (!_isQuestionJob) {
        await _refreshCoverPoolStatus();
      }
      if (run.isActive && !run.isPaused) {
        await _pumpRun();
      }
      return;
    }

    final message = (result as AppFailure<AdminAiReadingRun>).message;
    setState(() {
      _errorText = message;
    });
    widget.onMessage(message, isError: true);
  }

  Future<void> _handlePause() async {
    await _runControlAction(action: 'pause');
  }

  Future<void> _handleResume() async {
    await _runControlAction(
      action: 'resume',
      provider: _isQuestionJob ? _questionProvider : adminAiCoverProviderForModel(_coverModel),
      model: _isQuestionJob ? _questionModel : _coverModel,
      questionCount: _isQuestionJob
          ? int.tryParse(_questionCountController.text.trim())
          : null,
    );
  }

  Future<void> _handleContinue() async {
    final run = _run;
    if (run == null) {
      return;
    }
    if (run.isPaused) {
      await _handleResume();
      return;
    }
    setState(() {
      _errorText = null;
    });
    await _pumpRun();
  }

  Future<void> _handleCancel() async {
    await _runControlAction(action: 'cancel');
  }

  Future<void> _runControlAction({
    required String action,
    String? provider,
    String? model,
    int? questionCount,
  }) async {
    final run = _run;
    if (run == null) {
      return;
    }

    setState(() {
      _isActing = true;
      _errorText = null;
    });
    final result = await widget.repository.controlReadingAiRun(
      runId: run.id,
      action: action,
      provider: provider,
      model: model,
      questionCount: questionCount,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _isActing = false;
    });

    if (result case AppSuccess<AdminAiReadingRun>(value: final nextRun)) {
      _applyRun(nextRun);
      if (!_isQuestionJob) {
        await _refreshCoverPoolStatus();
      }
      if (action == 'resume' && nextRun.isActive && !nextRun.isPaused) {
        await _pumpRun();
      }
      return;
    }

    final message = (result as AppFailure<AdminAiReadingRun>).message;
    setState(() {
      _errorText = message;
    });
    widget.onMessage(message, isError: true);
  }

  Future<void> _pumpRun() async {
    if (_isPumping) {
      return;
    }
    if (mounted) {
      setState(() {
        _isPumping = true;
      });
    } else {
      _isPumping = true;
    }
    try {
      while (mounted) {
        final run = _run;
        if (run == null || !run.isActive || run.isPaused) {
          break;
        }

        final result = await widget.repository.processReadingAiRun(
          runId: run.id,
          batchSize: 1,
        );
        if (!mounted) {
          return;
        }

        if (result case AppSuccess<AdminAiReadingRun>(value: final nextRun)) {
          _applyRun(nextRun);
          if (!_isQuestionJob) {
            await _refreshCoverPoolStatus();
          }
          if (!nextRun.isActive || nextRun.isPaused) {
            break;
          }
        } else {
          final message = (result as AppFailure<AdminAiReadingRun>).message;
          setState(() {
            _errorText = message;
          });
          widget.onMessage(message, isError: true);
          break;
        }

        final latestRun = _run;
        if (latestRun == null || !latestRun.isActive || latestRun.isPaused) {
          break;
        }

        await Future<void>.delayed(const Duration(seconds: 10));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPumping = false;
        });
      } else {
        _isPumping = false;
      }
    }
  }

  void _applyRun(AdminAiReadingRun run) {
    setState(() {
      _run = run;
      if (run.isActive) {
        _settledNotified = false;
      }
      _questionProvider = run.provider == adminAiProviderOpenRouter
          ? adminAiProviderOpenRouter
          : adminAiProviderGemini;
      if (run.model.trim().isNotEmpty) {
        if (_isQuestionJob) {
          _questionModel = run.model;
        } else {
          _coverModel = run.model;
        }
      }
      _errorText = null;
    });

    widget.onRunChanged(run.isActive ? run : null);
    if (!run.isActive && !_settledNotified) {
      _settledNotified = true;
      widget.onRunSettled(run);
    }
  }

  Future<void> _refreshCoverPoolStatus() async {
    final result = await widget.repository.fetchAiCoverPoolStatus();
    if (!mounted) {
      return;
    }
    if (result case AppSuccess<AdminAiCoverPoolStatus>(value: final status)) {
      setState(() {
        _coverPoolStatus = status;
      });
    }
  }

  List<String> get _availableCoverModels {
    final enabledModels = _coverPoolStatus?.enabledModels ?? const <AdminAiCoverModelUsageStatus>[];
    if (enabledModels.isEmpty) {
      return adminAiCoverModels;
    }
    return <String>[
      adminAiCoverAutoModel,
      ...enabledModels.map((item) => item.model),
    ];
  }

  Widget _buildCoverUsageSummary(BuildContext context) {
    final theme = Theme.of(context);
    final status = _coverPoolStatus;
    if (status == null) {
      return Text(
        'Kullanim durumu yukleniyor...',
        style: theme.textTheme.bodySmall,
      );
    }
    if (_coverModel == adminAiCoverAutoModel) {
      final imageRouter = status.statusesForProvider(adminAiProviderImageRouter);
      final huggingFace = status.statusesForProvider(adminAiProviderHuggingFace);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Otomatik havuz', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          if (imageRouter.isNotEmpty)
            Text(
              'ImageRouter: ${imageRouter.map((item) => '${adminAiModelLabel(item.model)} ${item.attemptCount}/${item.dailyCap}').join(' • ')}',
              style: theme.textTheme.bodySmall,
            ),
          if (huggingFace.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Hugging Face: ${huggingFace.map((item) => '${adminAiModelLabel(item.model)} ${item.attemptCount}/${item.dailyCap}').join(' • ')}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      );
    }
    final selectedStatus = status.statusForSelection(_coverModel);
    if (selectedStatus == null) {
      return Text(
        'Secili model icin kullanim bilgisi yok.',
        style: theme.textTheme.bodySmall,
      );
    }
    final lifetimeText = selectedStatus.lifetimeCap == null
        ? ''
        : ' • toplam ${selectedStatus.lifetimeCap}';
    return Text(
      'Bugun ${selectedStatus.attemptCount}/${selectedStatus.dailyCap} • basarili ${selectedStatus.successCount} • hata ${selectedStatus.failedCount} • rate limit ${selectedStatus.rateLimitedCount}$lifetimeText',
      style: theme.textTheme.bodySmall,
    );
  }
}

List<String> _filterSummaryLines(Map<String, dynamic> filterSnapshot) {
  final lines = <String>[];
  final query = filterSnapshot['query']?.toString().trim() ?? '';
  if (query.isNotEmpty) {
    lines.add('Ara: $query');
  }
  final level = filterSnapshot['level']?.toString().trim() ?? '';
  if (level.isNotEmpty) {
    lines.add('Seviye: $level');
  }
  final published = filterSnapshot['is_published'];
  if (published is bool) {
    lines.add(published ? 'Durum: Yayinda' : 'Durum: Taslak');
  }
  final targetCount = (filterSnapshot['target_count'] as num?)?.toInt();
  if (targetCount != null) {
    lines.add('Hedef: $targetCount');
  }
  final hasQuestions = filterSnapshot['has_questions'];
  if (hasQuestions is bool) {
    lines.add(hasQuestions ? 'Mini Test: Var' : 'Mini Test: Yok');
  }
  final hasCover = filterSnapshot['has_cover'];
  if (hasCover is bool) {
    lines.add(hasCover ? 'Gorsel: Var' : 'Gorsel: Yok');
  }
  if (lines.isEmpty) {
    lines.add('Tum kayitlar');
  }
  return lines;
}

AdminAiReadingRun? _firstActiveReadingAiRunForJobType(
  List<AdminAiReadingRun> runs,
  String jobType,
) {
  for (final run in runs) {
    if (run.jobType == jobType) {
      return run;
    }
  }
  return null;
}

String _jobLabel(String jobType) {
  return jobType == 'question_backfill' ? 'Mini Test' : 'Cover';
}

String _runPauseReasonLabel(AdminAiReadingRun run) {
  return switch (run.pauseReason) {
    'auto_failure_threshold' =>
      'Run otomatik duraklatildi: 5 art arda hata algilandi.',
    'auto_failure_rate_threshold' =>
      'Run otomatik duraklatildi: toplam hata orani cok yuksek.',
    'provider_auth_skipped_to_fallback' =>
      'Run devam ediyor: bir provider yetki hatasi nedeniyle atlandi ve fallback havuzuna gecildi.',
    'all_cover_providers_unavailable' =>
      'Run duraklatildi: uygun cover provider kalmadi.',
    'invalid_source_reading_skipped' =>
      'Bazi okumalar cover olusturma icin eksik detay nedeniyle atlandi.',
    'provider_migration_required' =>
      'Run duraklatildi: yeni cover saglayici havuzu secilip devam ettirilmeli.',
    'user_paused' => 'Run manuel olarak duraklatildi.',
    'user_cancelled' => 'Run manuel olarak durduruldu.',
    _ => 'Run duraklatildi.',
  };
}

class _PagedListFooter extends StatelessWidget {
  const _PagedListFooter({
    required this.hasPrevious,
    required this.hasNext,
    required this.onPrevious,
    required this.onNext,
  });

  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Spacer(),
        FilledButton.tonal(
          onPressed: hasPrevious ? onPrevious : null,
          child: const Text('Onceki'),
        ),
        const SizedBox(width: 8),
        FilledButton.tonal(
          onPressed: hasNext ? onNext : null,
          child: const Text('Sonraki'),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _PackEditorDialog extends StatefulWidget {
  const _PackEditorDialog({this.existing});

  final AdminPackRecord? existing;

  @override
  State<_PackEditorDialog> createState() => _PackEditorDialogState();
}

class _PackEditorDialogState extends State<_PackEditorDialog> {
  late final TextEditingController _nameController;
  late bool _isPublished;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _isPublished = widget.existing?.isPublished ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Yeni Paket' : 'Paketi Duzenle'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Paket adi'),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isPublished,
              onChanged: (value) {
                setState(() {
                  _isPublished = value;
                });
              },
              title: const Text('Yayinda'),
              subtitle: const Text('Paket student tarafinda gorunur olsun.'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgec'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) {
              return;
            }
            Navigator.of(
              context,
            ).pop(_PackEditorDraft(name: name, isPublished: _isPublished));
          },
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}

class _WordEditorDialog extends StatefulWidget {
  const _WordEditorDialog({required this.packs, required this.initialDetail});

  final List<AdminPackRecord> packs;
  final AdminWordDetail initialDetail;

  @override
  State<_WordEditorDialog> createState() => _WordEditorDialogState();
}

class _WordEditorDialogState extends State<_WordEditorDialog> {
  late final TextEditingController _enWordController;
  late final TextEditingController _trMeaningController;
  late final TextEditingController _posController;
  late final TextEditingController _posRawController;
  late final TextEditingController _exampleEnController;
  late final TextEditingController _exampleTrController;
  late final TextEditingController _synonymsController;
  late final TextEditingController _antonymsController;
  late final TextEditingController _levelController;
  late final TextEditingController _tagsController;
  late final TextEditingController _notesController;
  late final TextEditingController _publishAtController;
  late final TextEditingController _unpublishAtController;
  late bool _isPro;
  late bool _isPublished;
  String? _validationMessage;
  String? _packId;

  @override
  void initState() {
    super.initState();
    final detail = widget.initialDetail;
    _packId =
        detail.packId ?? (widget.packs.isEmpty ? null : widget.packs.first.id);
    _enWordController = TextEditingController(text: detail.enWord);
    _trMeaningController = TextEditingController(text: detail.trMeaning);
    _posController = TextEditingController(text: detail.pos);
    _posRawController = TextEditingController(text: detail.posRaw ?? '');
    _exampleEnController = TextEditingController(text: detail.exampleEn);
    _exampleTrController = TextEditingController(text: detail.exampleTr ?? '');
    _synonymsController = TextEditingController(text: detail.synonymsRaw ?? '');
    _antonymsController = TextEditingController(text: detail.antonymsRaw ?? '');
    _levelController = TextEditingController(text: detail.level ?? '');
    _tagsController = TextEditingController(text: detail.tagsRaw ?? '');
    _notesController = TextEditingController(text: detail.notes ?? '');
    _publishAtController = TextEditingController(
      text: _formatDateTimeInput(detail.publishAt),
    );
    _unpublishAtController = TextEditingController(
      text: _formatDateTimeInput(detail.unpublishAt),
    );
    _isPro = detail.isPro;
    _isPublished = detail.isPublished;
  }

  @override
  void dispose() {
    _enWordController.dispose();
    _trMeaningController.dispose();
    _posController.dispose();
    _posRawController.dispose();
    _exampleEnController.dispose();
    _exampleTrController.dispose();
    _synonymsController.dispose();
    _antonymsController.dispose();
    _levelController.dispose();
    _tagsController.dispose();
    _notesController.dispose();
    _publishAtController.dispose();
    _unpublishAtController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metadata = widget.initialDetail.metadata;
    return AlertDialog(
      title: Text(metadata.id == null ? 'Yeni Kelime' : 'Kelimeyi Duzenle'),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_validationMessage != null) ...[
                Text(
                  _validationMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],
              DropdownButtonFormField<String>(
                initialValue: _packId,
                decoration: const InputDecoration(labelText: 'Paket'),
                items: [
                  for (final pack in widget.packs)
                    DropdownMenuItem<String>(
                      value: pack.id,
                      child: Text(pack.name),
                    ),
                ],
                onChanged: (value) {
                  setState(() {
                    _packId = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _enWordController,
                      decoration: const InputDecoration(
                        labelText: 'English word',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _trMeaningController,
                      decoration: const InputDecoration(
                        labelText: 'Turkish meaning',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _posController,
                      decoration: const InputDecoration(labelText: 'POS'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _levelController,
                      decoration: const InputDecoration(labelText: 'Seviye'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _posRawController,
                      decoration: const InputDecoration(labelText: 'POS Raw'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _tagsController,
                      decoration: const InputDecoration(labelText: 'Tagler'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _exampleEnController,
                decoration: const InputDecoration(labelText: 'Example EN'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _exampleTrController,
                decoration: const InputDecoration(labelText: 'Example TR'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _synonymsController,
                      decoration: const InputDecoration(
                        labelText: 'Synonyms Raw',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _antonymsController,
                      decoration: const InputDecoration(
                        labelText: 'Antonyms Raw',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notlar'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isPro,
                onChanged: (value) {
                  setState(() {
                    _isPro = value;
                  });
                },
                title: const Text('Pro icerik'),
                subtitle: const Text('Kelime premium plan gerektirsin.'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isPublished,
                onChanged: (value) {
                  setState(() {
                    _isPublished = value;
                  });
                },
                title: const Text('Yayinda'),
                subtitle: const Text('Kelime student tarafinda gorunsun.'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _publishAtController,
                      decoration: const InputDecoration(
                        labelText: 'Publish At',
                        helperText: 'YYYY-MM-DD HH:MM',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _unpublishAtController,
                      decoration: const InputDecoration(
                        labelText: 'Unpublish At',
                        helperText: 'YYYY-MM-DD HH:MM',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _MetadataSummary(metadata: metadata),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgec'),
        ),
        FilledButton(
          onPressed: () {
            final publishAt = _parseDateTimeInput(_publishAtController.text);
            final unpublishAt = _parseDateTimeInput(
              _unpublishAtController.text,
            );
            if (_packId == null ||
                _enWordController.text.trim().isEmpty ||
                _trMeaningController.text.trim().isEmpty ||
                _posController.text.trim().isEmpty ||
                _exampleEnController.text.trim().isEmpty) {
              setState(() {
                _validationMessage =
                    'Paket, EN kelime, TR anlam, POS ve example EN zorunlu.';
              });
              return;
            }
            if ((_publishAtController.text.trim().isNotEmpty &&
                    publishAt == null) ||
                (_unpublishAtController.text.trim().isNotEmpty &&
                    unpublishAt == null)) {
              setState(() {
                _validationMessage =
                    'Publish/Unpublish alanlari gecersiz tarih formatinda.';
              });
              return;
            }
            Navigator.of(context).pop(
              widget.initialDetail.copyWith(
                packId: _packId!,
                enWord: _enWordController.text.trim(),
                trMeaning: _trMeaningController.text.trim(),
                pos: _posController.text.trim(),
                posRaw: _emptyAsNull(_posRawController.text),
                exampleEn: _exampleEnController.text.trim(),
                exampleTr: _emptyAsNull(_exampleTrController.text),
                synonymsRaw: _emptyAsNull(_synonymsController.text),
                antonymsRaw: _emptyAsNull(_antonymsController.text),
                level: _emptyAsNull(_levelController.text),
                tagsRaw: _emptyAsNull(_tagsController.text),
                notes: _emptyAsNull(_notesController.text),
                isPro: _isPro,
                isPublished: _isPublished,
                publishAt: publishAt,
                unpublishAt: unpublishAt,
                clearPosRaw: _posRawController.text.trim().isEmpty,
                clearExampleTr: _exampleTrController.text.trim().isEmpty,
                clearSynonymsRaw: _synonymsController.text.trim().isEmpty,
                clearAntonymsRaw: _antonymsController.text.trim().isEmpty,
                clearLevel: _levelController.text.trim().isEmpty,
                clearTagsRaw: _tagsController.text.trim().isEmpty,
                clearNotes: _notesController.text.trim().isEmpty,
                clearPublishAt: _publishAtController.text.trim().isEmpty,
                clearUnpublishAt: _unpublishAtController.text.trim().isEmpty,
              ),
            );
          },
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}

class _ReadingEditorDialog extends StatefulWidget {
  const _ReadingEditorDialog({
    required this.packs,
    required this.initialDetail,
    required this.coverUrlBuilder,
    required this.aiCoverPoolStatus,
    required this.onGenerateCover,
    required this.onUploadCover,
    required this.onRemoveCover,
    required this.onMessage,
  });

  final List<AdminPackRecord> packs;
  final AdminReadingDetail initialDetail;
  final String? Function(AdminReadingCoverAsset cover) coverUrlBuilder;
  final AdminAiCoverPoolStatus? aiCoverPoolStatus;
  final Future<AppResult<AdminReadingDetail>> Function(
    AdminReadingDetail detail,
    String selectedModel,
  )
  onGenerateCover;
  final Future<AppResult<AdminReadingDetail>> Function({
    required AdminReadingDetail detail,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String? altText,
  })
  onUploadCover;
  final Future<AppResult<AdminReadingDetail>> Function(AdminReadingDetail detail)
  onRemoveCover;
  final void Function(String message, {bool isError}) onMessage;

  @override
  State<_ReadingEditorDialog> createState() => _ReadingEditorDialogState();
}

class _ReadingEditorDialogState extends State<_ReadingEditorDialog> {
  late final TextEditingController _publishAtController;
  late final TextEditingController _unpublishAtController;
  late final TextEditingController _linkedWordsJsonController;
  late AdminReadingDetail _detail;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _detail = widget.initialDetail;
    _publishAtController = TextEditingController(
      text: _formatDateTimeInput(_detail.publishAt),
    );
    _unpublishAtController = TextEditingController(
      text: _formatDateTimeInput(_detail.unpublishAt),
    );
    _linkedWordsJsonController = TextEditingController(
      text: _prettyJson(
        _detail.linkedWords.map((item) => item.toJson()).toList(growable: false),
      ),
    );
  }

  @override
  void dispose() {
    _publishAtController.dispose();
    _unpublishAtController.dispose();
    _linkedWordsJsonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metadata = _detail.metadata;
    final hasPersistedId = metadata.id?.trim().isNotEmpty ?? false;
    return AlertDialog(
      title: Text(metadata.id == null ? 'Yeni Okuma' : 'Okumayi Duzenle'),
      content: SizedBox(
        width: 960,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_validationMessage != null) ...[
                Text(
                  _validationMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],
              DropdownButtonFormField<String?>(
                initialValue: _detail.packId,
                decoration: const InputDecoration(labelText: 'Paket'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Paketsiz'),
                  ),
                  for (final pack in widget.packs)
                    DropdownMenuItem<String?>(
                      value: pack.id,
                      child: Text(pack.name),
                    ),
                ],
                onChanged: (value) {
                  _updateDetail(
                    _detail.copyWith(
                      packId: value,
                      clearPackId: value == null,
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _detail.isPro,
                onChanged: (value) =>
                    _updateDetail(_detail.copyWith(isPro: value)),
                title: const Text('Pro icerik'),
                subtitle: const Text(
                  'Free kullanici karti gorur, detay icin Pro gerekir.',
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _detail.isPublished,
                onChanged: (value) =>
                    _updateDetail(_detail.copyWith(isPublished: value)),
                title: const Text('Yayinda'),
                subtitle: const Text('Parca student listesinde gorunsun.'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _publishAtController,
                      decoration: const InputDecoration(
                        labelText: 'Publish At',
                        helperText: 'YYYY-MM-DD HH:MM',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _unpublishAtController,
                      decoration: const InputDecoration(
                        labelText: 'Unpublish At',
                        helperText: 'YYYY-MM-DD HH:MM',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AiDraftEditor(
                detail: _detail,
                onChanged: _updateDetail,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _linkedWordsJsonController,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Linked Words JSON',
                  helperText: 'Her kayit: word_id, en_word, tr_meaning.',
                ),
              ),
              const SizedBox(height: 16),
              AiQuestionsPanel(
                detail: _detail,
                onChanged: _updateDetail,
              ),
              const SizedBox(height: 16),
              ReadingCoverPanel(
                detail: _detail,
                coverUrl: widget.coverUrlBuilder(_detail.cover),
                selectedModel: adminAiCoverAutoModel,
                poolStatus: widget.aiCoverPoolStatus,
                enabled: hasPersistedId,
                disabledMessage: hasPersistedId
                    ? null
                    : 'Cover islemleri icin reading once kaydedilmeli.',
                onChanged: _updateDetail,
                onGenerate: (selectedModel) =>
                    widget.onGenerateCover(_detail, selectedModel),
                onUpload: ({
                  required bytes,
                  required fileName,
                  required mimeType,
                  String? altText,
                }) => widget.onUploadCover(
                  detail: _detail,
                  bytes: bytes,
                  fileName: fileName,
                  mimeType: mimeType,
                  altText: altText,
                ),
                onRemove: () => widget.onRemoveCover(_detail),
                onMessage: widget.onMessage,
              ),
              const SizedBox(height: 16),
              _MetadataSummary(metadata: metadata),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgec'),
        ),
        FilledButton(
          onPressed: () {
            final publishAt = _parseDateTimeInput(_publishAtController.text);
            final unpublishAt = _parseDateTimeInput(
              _unpublishAtController.text,
            );
            if (_detail.title.trim().isEmpty) {
              setState(() {
                _validationMessage = 'Baslik zorunlu.';
              });
              return;
            }
            if ((_publishAtController.text.trim().isNotEmpty &&
                    publishAt == null) ||
                (_unpublishAtController.text.trim().isNotEmpty &&
                    unpublishAt == null)) {
              setState(() {
                _validationMessage =
                    'Publish/Unpublish alanlari gecersiz tarih formatinda.';
              });
              return;
            }
            final linkedWordsJson = _decodeJsonArray(
              _linkedWordsJsonController.text,
            );
            if (linkedWordsJson == null) {
              setState(() {
                _validationMessage = 'Linked Words JSON gecersiz.';
              });
              return;
            }
            Navigator.of(context).pop(
              _detail.copyWith(
                publishAt: publishAt,
                unpublishAt: unpublishAt,
                linkedWords: linkedWordsJson
                    .map(AdminReadingWordLinkInput.fromJson)
                    .toList(growable: false),
                clearPublishAt: _publishAtController.text.trim().isEmpty,
                clearUnpublishAt: _unpublishAtController.text.trim().isEmpty,
              ),
            );
          },
          child: const Text('Kaydet'),
        ),
      ],
    );
  }

  void _updateDetail(AdminReadingDetail detail) {
    setState(() {
      _detail = detail;
      _validationMessage = null;
    });
  }
}

class _GrammarEditorDialog extends StatefulWidget {
  const _GrammarEditorDialog({required this.initialDetail});

  final AdminGrammarModuleDetail initialDetail;

  @override
  State<_GrammarEditorDialog> createState() => _GrammarEditorDialogState();
}

class _GrammarEditorDialogState extends State<_GrammarEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _fileNameController;
  late final TextEditingController _sortOrderController;
  late final TextEditingController _iconController;
  late final TextEditingController _colorController;
  late final TextEditingController _publishAtController;
  late final TextEditingController _unpublishAtController;
  late final TextEditingController _pagesJsonController;
  late bool _isPublished;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    final detail = widget.initialDetail;
    _titleController = TextEditingController(text: detail.title);
    _fileNameController = TextEditingController(text: detail.fileName);
    _sortOrderController = TextEditingController(
      text: detail.sortOrder.toString(),
    );
    _iconController = TextEditingController(text: detail.icon);
    _colorController = TextEditingController(text: detail.color);
    _publishAtController = TextEditingController(
      text: _formatDateTimeInput(detail.publishAt),
    );
    _unpublishAtController = TextEditingController(
      text: _formatDateTimeInput(detail.unpublishAt),
    );
    _pagesJsonController = TextEditingController(
      text: _prettyJson(
        detail.pages.map((item) => item.toJson()).toList(growable: false),
      ),
    );
    _isPublished = detail.isPublished;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _fileNameController.dispose();
    _sortOrderController.dispose();
    _iconController.dispose();
    _colorController.dispose();
    _publishAtController.dispose();
    _unpublishAtController.dispose();
    _pagesJsonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metadata = widget.initialDetail.metadata;
    return AlertDialog(
      title: Text(metadata.id == null ? 'Yeni Modul' : 'Modulu Duzenle'),
      content: SizedBox(
        width: 820,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_validationMessage != null) ...[
                Text(
                  _validationMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Modul basligi'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _fileNameController,
                      decoration: const InputDecoration(labelText: 'Dosya adi'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _sortOrderController,
                      decoration: const InputDecoration(labelText: 'Sira'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _iconController,
                      decoration: const InputDecoration(labelText: 'Icon'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _colorController,
                      decoration: const InputDecoration(labelText: 'Renk'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isPublished,
                onChanged: (value) {
                  setState(() {
                    _isPublished = value;
                  });
                },
                title: const Text('Yayinda'),
                subtitle: const Text('Modul student uygulamasinda gorunsun.'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _publishAtController,
                      decoration: const InputDecoration(
                        labelText: 'Publish At',
                        helperText: 'YYYY-MM-DD HH:MM',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _unpublishAtController,
                      decoration: const InputDecoration(
                        labelText: 'Unpublish At',
                        helperText: 'YYYY-MM-DD HH:MM',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pagesJsonController,
                maxLines: 16,
                decoration: const InputDecoration(
                  labelText: 'Pages JSON',
                  helperText:
                      'Her page: page_number, title, html_content, examples[], tests[].',
                ),
              ),
              const SizedBox(height: 16),
              _MetadataSummary(metadata: metadata),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgec'),
        ),
        FilledButton(
          onPressed: () {
            final title = _titleController.text.trim();
            final fileName = _fileNameController.text.trim();
            final sortOrder =
                int.tryParse(_sortOrderController.text.trim()) ?? 1;
            final publishAt = _parseDateTimeInput(_publishAtController.text);
            final unpublishAt = _parseDateTimeInput(
              _unpublishAtController.text,
            );
            if (title.isEmpty || fileName.isEmpty) {
              setState(() {
                _validationMessage = 'Modul basligi ve dosya adi zorunlu.';
              });
              return;
            }
            if ((_publishAtController.text.trim().isNotEmpty &&
                    publishAt == null) ||
                (_unpublishAtController.text.trim().isNotEmpty &&
                    unpublishAt == null)) {
              setState(() {
                _validationMessage =
                    'Publish/Unpublish alanlari gecersiz tarih formatinda.';
              });
              return;
            }
            final pagesJson = _decodeJsonArray(_pagesJsonController.text);
            if (pagesJson == null) {
              setState(() {
                _validationMessage = 'Pages JSON gecersiz.';
              });
              return;
            }
            Navigator.of(context).pop(
              widget.initialDetail.copyWith(
                sortOrder: sortOrder,
                title: title,
                fileName: fileName,
                icon: _iconController.text.trim().isEmpty
                    ? 'book'
                    : _iconController.text.trim(),
                color: _colorController.text.trim().isEmpty
                    ? '#4776E6'
                    : _colorController.text.trim(),
                isPublished: _isPublished,
                publishAt: publishAt,
                unpublishAt: unpublishAt,
                pages: pagesJson
                    .map(AdminGrammarPageInput.fromJson)
                    .toList(growable: false),
                clearPublishAt: _publishAtController.text.trim().isEmpty,
                clearUnpublishAt: _unpublishAtController.text.trim().isEmpty,
              ),
            );
          },
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}

class _WordImportDialog extends StatefulWidget {
  const _WordImportDialog({required this.pack});

  final AdminPackRecord pack;

  @override
  State<_WordImportDialog> createState() => _WordImportDialogState();
}

class _WordImportDialogState extends State<_WordImportDialog> {
  late final TextEditingController _csvController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _csvController = TextEditingController(
      text:
          'en_word,tr_meaning,pos,example_en,example_tr,level,notes\nbenchmark,olcut,n.,Benchmark numbers guide the team.,Olcut rakamlari ekibi yonlendirir.,B2,import sample',
    );
  }

  @override
  void dispose() {
    _csvController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.pack.name} icin CSV Yukle'),
      content: SizedBox(
        width: 760,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Baslik satiri desteklenir. Beklenen kolonlar: en_word,tr_meaning,pos,example_en,example_tr,level,notes',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _csvController,
              maxLines: 12,
              decoration: InputDecoration(
                hintText: 'CSV verisini buraya yapistir',
                errorText: _errorText,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgec'),
        ),
        FilledButton(
          onPressed: () {
            final parsedRows = _parseCsvRows(_csvController.text);
            if (parsedRows.isEmpty) {
              setState(() {
                _errorText = 'Gecerli en az bir satir gerekli.';
              });
              return;
            }
            Navigator.of(context).pop(parsedRows);
          },
          child: const Text('Import Et'),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _parseCsvRows(String rawValue) {
    return _parseWordCsvRows(rawValue);
  }
}

class _ReadingImportDialog extends StatefulWidget {
  const _ReadingImportDialog({required this.packs});

  final List<AdminPackRecord> packs;

  @override
  State<_ReadingImportDialog> createState() => _ReadingImportDialogState();
}

class _ReadingImportDialogState extends State<_ReadingImportDialog> {
  late final TextEditingController _csvController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _csvController = TextEditingController(
      text:
          '''import_key,pack_name,title,level,category,tags_raw,is_pro,is_published,sentence_idx,sentence_en,sentence_tr,translations_json,linked_words_json
science-1,Starter Pack,Why Sleep Matters,B1,science,"sleep, health",false,true,1,"Sleep helps the brain recover.","Uyku beynin toparlanmasina yardim eder.","[{""provider"":""manual"",""target_lang"":""tr"",""translated_text"":""Uyku beynin toparlanmasina yardim eder.""}]","[{""word_id"":"""",""en_word"":""recover"",""tr_meaning"":""toparlanmak""}]"
science-1,Starter Pack,Why Sleep Matters,B1,science,"sleep, health",false,true,2,"It also improves memory and focus.","Ayrica hafiza ve odagi gelistirir.","[]","[]"''',
    );
  }

  @override
  void dispose() {
    _csvController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Okuma CSV Yukle'),
      content: SizedBox(
        width: 860,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Beklenen kolonlar: import_key, pack_id veya pack_name, title, level, category, tags_raw, is_pro, is_published, sentence_idx, sentence_en, sentence_tr, translations_json, linked_words_json',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _csvController,
              maxLines: 16,
              decoration: InputDecoration(
                hintText: 'CSV verisini buraya yapistir',
                errorText: _errorText,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgec'),
        ),
        FilledButton(
          onPressed: () {
            final parsedItems = _parseReadingCsvRows(
              _csvController.text,
              widget.packs,
            );
            if (parsedItems == null || parsedItems.isEmpty) {
              setState(() {
                _errorText =
                    'Gecerli en az bir okuma kaydi gerekli. Header, sentence_idx ve sentence_en alanlarini kontrol edin.';
              });
              return;
            }
            Navigator.of(context).pop(parsedItems);
          },
          child: const Text('Import Et'),
        ),
      ],
    );
  }
}

List<Map<String, dynamic>> _parseWordCsvRows(String rawValue) {
  final table = _parseCsvTable(rawValue);
  if (table.isEmpty) {
    return const <Map<String, dynamic>>[];
  }

  final normalizedFirstRow = table.first
      .map(_normalizeCsvHeader)
      .toList(growable: false);
  final hasHeader =
      normalizedFirstRow.contains('en_word') &&
      normalizedFirstRow.contains('tr_meaning');

  final headers = hasHeader
      ? normalizedFirstRow
      : <String>[
          'en_word',
          'tr_meaning',
          'pos',
          'example_en',
          'example_tr',
          'level',
          'notes',
        ];
  final startIndex = hasHeader ? 1 : 0;

  final rows = <Map<String, dynamic>>[];
  for (var rowIndex = startIndex; rowIndex < table.length; rowIndex++) {
    final row = table[rowIndex];
    if (row.every((item) => item.trim().isEmpty)) {
      continue;
    }

    final record = _csvRowToRecord(headers, row);
    final enWord = record['en_word']?.trim() ?? '';
    final trMeaning = record['tr_meaning']?.trim() ?? '';
    final exampleEn = record['example_en']?.trim() ?? '';
    if (enWord.isEmpty || trMeaning.isEmpty || exampleEn.isEmpty) {
      continue;
    }

    rows.add(<String, dynamic>{
      'en_word': enWord,
      'tr_meaning': trMeaning,
      'pos': (record['pos']?.trim().isNotEmpty ?? false)
          ? record['pos']!.trim()
          : 'other',
      'example_en': exampleEn,
      'example_tr': _emptyAsNull(record['example_tr'] ?? ''),
      'level': _emptyAsNull(record['level'] ?? ''),
      'notes': _emptyAsNull(record['notes'] ?? ''),
    });
  }

  return rows;
}

List<AdminReadingDetail>? _parseReadingCsvRows(
  String rawValue,
  List<AdminPackRecord> packs,
) {
  final table = _parseCsvTable(rawValue);
  if (table.isEmpty) {
    return const <AdminReadingDetail>[];
  }

  final headers = table.first.map(_normalizeCsvHeader).toList(growable: false);
  if (!headers.contains('title') ||
      !headers.contains('sentence_idx') ||
      !headers.contains('sentence_en')) {
    return null;
  }

  final packById = <String, String>{for (final pack in packs) pack.id: pack.id};
  final packByName = <String, String>{
    for (final pack in packs) pack.name.trim().toLowerCase(): pack.id,
  };

  final grouped = <String, _ReadingImportBuilder>{};
  for (var rowIndex = 1; rowIndex < table.length; rowIndex++) {
    final record = _csvRowToRecord(headers, table[rowIndex]);
    if (record.values.every((value) => value.trim().isEmpty)) {
      continue;
    }

    final title = record['title']?.trim() ?? '';
    final idx = int.tryParse(record['sentence_idx']?.trim() ?? '');
    final sentenceEn = record['sentence_en']?.trim() ?? '';
    if (title.isEmpty || idx == null || sentenceEn.isEmpty) {
      return null;
    }

    final packIdValue = _emptyAsNull(record['pack_id'] ?? '');
    final packNameValue = _emptyAsNull(record['pack_name'] ?? '');
    final resolvedPackId = packIdValue != null
        ? packById[packIdValue]
        : packNameValue == null
        ? null
        : packByName[packNameValue.toLowerCase()];
    if (packIdValue != null && resolvedPackId == null) {
      return null;
    }
    if (packNameValue != null && resolvedPackId == null) {
      return null;
    }

    final importKey =
        _emptyAsNull(record['import_key'] ?? '') ??
        '${resolvedPackId ?? '-'}|$title|${record['level'] ?? ''}|${record['category'] ?? ''}';
    final builder = grouped.putIfAbsent(
      importKey,
      () => _ReadingImportBuilder(
        packId: resolvedPackId,
        title: title,
        level: _emptyAsNull(record['level'] ?? ''),
        category: _emptyAsNull(record['category'] ?? ''),
        tagsRaw: _emptyAsNull(record['tags_raw'] ?? ''),
        isPro: _parseCsvBool(record['is_pro'], fallback: false),
        isPublished: _parseCsvBool(record['is_published'], fallback: true),
      ),
    );

    final translationsJson = _decodeJsonArray(
      record['translations_json'] ?? '',
    );
    final linkedWordsJson = _decodeJsonArray(record['linked_words_json'] ?? '');
    if (translationsJson == null || linkedWordsJson == null) {
      return null;
    }

    builder.addSentence(
      AdminReadingSentenceInput(
        idx: idx,
        sentenceEn: sentenceEn,
        sentenceTr: _emptyAsNull(record['sentence_tr'] ?? ''),
        translations: translationsJson
            .map(AdminReadingSentenceTranslationInput.fromJson)
            .toList(growable: false),
      ),
    );
    builder.addLinkedWords(
      linkedWordsJson
          .map(AdminReadingWordLinkInput.fromJson)
          .where(
            (item) =>
                item.enWord.trim().isNotEmpty || item.wordId.trim().isNotEmpty,
          )
          .toList(growable: false),
    );
  }

  return grouped.values
      .map((builder) => builder.build())
      .toList(growable: false);
}

class _ReadingImportBuilder {
  _ReadingImportBuilder({
    required this.packId,
    required this.title,
    required this.level,
    required this.category,
    required this.tagsRaw,
    required this.isPro,
    required this.isPublished,
  });

  final String? packId;
  final String title;
  final String? level;
  final String? category;
  final String? tagsRaw;
  final bool isPro;
  final bool isPublished;
  final Map<int, AdminReadingSentenceInput> _sentencesByIndex =
      <int, AdminReadingSentenceInput>{};
  final Map<String, AdminReadingWordLinkInput> _linkedWordsByKey =
      <String, AdminReadingWordLinkInput>{};

  void addSentence(AdminReadingSentenceInput item) {
    _sentencesByIndex[item.idx] = item;
  }

  void addLinkedWords(List<AdminReadingWordLinkInput> items) {
    for (final item in items) {
      final key = item.wordId.trim().isNotEmpty
          ? item.wordId.trim()
          : item.enWord.trim().toLowerCase();
      _linkedWordsByKey[key] = item;
    }
  }

  AdminReadingDetail build() {
    final sortedSentences = _sentencesByIndex.values.toList(growable: false)
      ..sort((left, right) => left.idx.compareTo(right.idx));
    final linkedWords = _linkedWordsByKey.values.toList(growable: false)
      ..sort((left, right) => left.enWord.compareTo(right.enWord));

    return AdminReadingDetail(
      packId: packId,
      title: title,
      level: level,
      category: category,
      tagsRaw: tagsRaw,
      isPro: isPro,
      isPublished: isPublished,
      sentences: sortedSentences,
      linkedWords: linkedWords,
    );
  }
}

class _PackEditorDraft {
  const _PackEditorDraft({required this.name, required this.isPublished});

  final String name;
  final bool isPublished;
}

class _MetadataSummary extends StatelessWidget {
  const _MetadataSummary({required this.metadata});

  final AdminContentMetadata metadata;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Metadata', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text('id: ${metadata.id ?? '-'}'),
        Text('created: ${_formatMetadataDate(metadata.createdAt)}'),
        Text('updated: ${_formatMetadataDate(metadata.updatedAt)}'),
        Text('created by: ${metadata.createdByEmail ?? '-'}'),
        Text('updated by: ${metadata.updatedByEmail ?? '-'}'),
      ],
    );
  }
}

String _formatMetadataDate(DateTime? value) {
  if (value == null) {
    return '-';
  }
  return _formatDateTimeInput(value);
}

String _prettyJson(Object value) {
  return const JsonEncoder.withIndent('  ').convert(value);
}

List<List<String>> _parseCsvTable(String rawValue) {
  final rows = <List<String>>[];
  final row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;

  void pushField() {
    row.add(field.toString().trim());
    field.clear();
  }

  void pushRow() {
    pushField();
    final isMeaningful = row.any((item) => item.isNotEmpty);
    if (isMeaningful) {
      rows.add(List<String>.from(row));
    }
    row.clear();
  }

  for (var index = 0; index < rawValue.length; index++) {
    final char = rawValue[index];
    if (char == '"') {
      final nextChar = index + 1 < rawValue.length ? rawValue[index + 1] : null;
      if (inQuotes && nextChar == '"') {
        field.write('"');
        index++;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }

    if (!inQuotes && char == ',') {
      pushField();
      continue;
    }

    if (!inQuotes && (char == '\n' || char == '\r')) {
      if (char == '\r' &&
          index + 1 < rawValue.length &&
          rawValue[index + 1] == '\n') {
        index++;
      }
      pushRow();
      continue;
    }

    field.write(char);
  }

  if (field.isNotEmpty || row.isNotEmpty) {
    pushRow();
  }

  if (rows.isNotEmpty && rows.first.isNotEmpty) {
    rows.first[0] = rows.first[0].replaceFirst('\uFEFF', '');
  }
  return rows;
}

Map<String, String> _csvRowToRecord(List<String> headers, List<String> row) {
  final record = <String, String>{};
  for (var index = 0; index < headers.length; index++) {
    record[headers[index]] = index < row.length ? row[index].trim() : '';
  }
  return record;
}

String _normalizeCsvHeader(String rawValue) {
  return rawValue
      .trim()
      .toLowerCase()
      .replaceAll(' ', '_')
      .replaceAll('-', '_');
}

bool _parseCsvBool(String? rawValue, {required bool fallback}) {
  final normalized = rawValue?.trim().toLowerCase();
  return switch (normalized) {
    '1' || 'true' || 'yes' || 'y' => true,
    '0' || 'false' || 'no' || 'n' => false,
    _ => fallback,
  };
}

List<Map<String, dynamic>>? _decodeJsonArray(String rawValue) {
  final trimmed = rawValue.trim();
  if (trimmed.isEmpty) {
    return const <Map<String, dynamic>>[];
  }

  final decoded = jsonDecode(trimmed);
  if (decoded is! List) {
    return null;
  }
  return decoded
      .whereType<Map>()
      .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
      .toList(growable: false);
}

String? _coverUrlForAsset(String supabaseUrl, AdminReadingCoverAsset cover) {
  final bucket = cover.bucketName?.trim();
  final storagePath = cover.storagePath?.trim();
  if (bucket == null ||
      bucket.isEmpty ||
      storagePath == null ||
      storagePath.isEmpty) {
    return null;
  }

  final normalizedBaseUrl = supabaseUrl.trim();
  if (normalizedBaseUrl.isEmpty) {
    return null;
  }

  final normalizedBase = normalizedBaseUrl.endsWith('/')
      ? normalizedBaseUrl.substring(0, normalizedBaseUrl.length - 1)
      : normalizedBaseUrl;
  final encodedPath = storagePath
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .map(Uri.encodeComponent)
      .join('/');
  return '$normalizedBase/storage/v1/object/public/$bucket/$encodedPath';
}

String _formatDateTimeInput(DateTime? value) {
  if (value == null) {
    return '';
  }
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}

DateTime? _parseDateTimeInput(String rawValue) {
  final trimmed = rawValue.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final normalized = trimmed.contains('T')
      ? trimmed
      : trimmed.replaceFirst(' ', 'T');
  return DateTime.tryParse(normalized);
}

String? _emptyAsNull(String rawValue) {
  final trimmed = rawValue.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}
