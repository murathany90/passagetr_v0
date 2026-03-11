import 'dart:convert';
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

class AdminContentPage extends ConsumerStatefulWidget {
  const AdminContentPage({super.key, required this.destination});

  final AdminDestination destination;

  @override
  ConsumerState<AdminContentPage> createState() => _AdminContentPageState();
}

class _AdminContentPageState extends ConsumerState<AdminContentPage> {
  String _query = '';
  String? _selectedPackId;
  String? _readingLevelFilter;
  bool? _wordPublishedFilter;
  bool? _readingPublishedFilter;
  int _wordOffset = 0;
  int _readingOffset = 0;

  bool get _isPreviewMode => !ref.read(adminAppConfigProvider).supabaseEnabled;

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
                  packId: _selectedPackId,
                  query: _query,
                  offset: _wordOffset,
                  limit: pageSize,
                  isPublished: _wordPublishedFilter,
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
              query: _query,
              offset: _readingOffset,
              limit: pageSize,
              level: _readingLevelFilter,
              isPublished: _readingPublishedFilter,
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
      if (item.id == _selectedPackId) {
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
                        _selectedPackId = pack.id;
                        _wordOffset = 0;
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
                decoration: const InputDecoration(
                  hintText: 'Kelime, anlam veya etiket ara',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (value) {
                  setState(() {
                    _query = value.trim().toLowerCase();
                    _wordOffset = 0;
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
                        initialValue: _wordPublishedFilter,
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
                            _wordPublishedFilter = value;
                            _wordOffset = 0;
                          });
                        },
                      ),
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
                  subtitle: _query.isEmpty
                      ? 'Bu pakette henuz kelime yok. Yeni kelime ekle veya CSV import et.'
                      : 'Arama filtresi sonuc vermedi.',
                  actionLabel: _query.isEmpty ? 'Yeni Kelime' : null,
                  onAction: _query.isEmpty
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
                      _wordOffset = math.max(0, _wordOffset - wordsPage.limit);
                    });
                  },
                  onNext: () {
                    setState(() {
                      _wordOffset += wordsPage.limit;
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
          TextField(
            decoration: const InputDecoration(
              hintText: 'Baslik, kategori veya tag ara',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (value) {
              setState(() {
                _query = value.trim().toLowerCase();
                _readingOffset = 0;
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
                    initialValue: _readingLevelFilter,
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
                        _readingLevelFilter = value;
                        _readingOffset = 0;
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<bool?>(
                    initialValue: _readingPublishedFilter,
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
                        _readingPublishedFilter = value;
                        _readingOffset = 0;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (visibleReadings.isEmpty)
            _EmptyState(
              title: 'Okuma kaydi yok',
              subtitle: _query.isEmpty && _readingLevelFilter == null
                  ? 'Yeni parca ekleyip publish akisini bu panelden yonet.'
                  : 'Secili filtrelerle eslesen kayit bulunamadi.',
              actionLabel: _query.isEmpty && _readingLevelFilter == null
                  ? 'Parca Ekle'
                  : null,
              onAction: _query.isEmpty && _readingLevelFilter == null
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
                  _readingOffset = math.max(
                    0,
                    _readingOffset - readingsPage.limit,
                  );
                });
              },
              onNext: () {
                setState(() {
                  _readingOffset += readingsPage.limit;
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
    final visibleModules = modules
        .where((item) {
          final haystack = '${item.title} ${item.fileName} ${item.pageCount}'
              .toLowerCase();
          return _query.isEmpty || haystack.contains(_query);
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
            decoration: const InputDecoration(
              hintText: 'Modul adi veya dosya adi ara',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (value) {
              setState(() {
                _query = value.trim().toLowerCase();
              });
            },
          ),
          const SizedBox(height: 20),
          if (visibleModules.isEmpty)
            _EmptyState(
              title: 'Gramer modulu yok',
              subtitle: _query.isEmpty
                  ? 'Yeni modul ekleyip sirayi bu panelden yonet.'
                  : 'Arama sonucu bulunamadi.',
              actionLabel: _query.isEmpty ? 'Modul Ekle' : null,
              onAction: _query.isEmpty
                  ? () => _openGrammarEditor(context)
                  : null,
            )
          else
            for (var index = 0; index < visibleModules.length; index++) ...[
              _GrammarRow(
                module: visibleModules[index],
                canMoveUp: index > 0,
                canMoveDown: index < visibleModules.length - 1,
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
      _selectedPackId ??= record.id;
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
      if (_selectedPackId == pack.id) {
        setState(() {
          _selectedPackId = null;
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
      builder: (context) => _WordEditorDialog(
        packs: packs,
        initialDetail: detail,
      ),
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
        _selectedPackId = savedDetail.packId;
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
          AdminReadingRecord(
            id: _clientId('reading'),
            packId: item.packId,
            packName: _packNameFromId(item.packId, packs),
            title: item.title,
            level: item.level,
            category: item.category,
            tagsRaw: item.tagsRaw,
            isPro: item.isPro,
            isPublished: item.isPublished,
            updatedAtLabel: 'az once',
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
          _ReadingEditorDialog(packs: packs, initialDetail: detail),
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
      final record =
          (existing ??
                  AdminReadingRecord(
                    id: savedDetail.metadata.id ?? _clientId('reading'),
                    packId: savedDetail.packId,
                    packName: _packNameFromId(savedDetail.packId, packs),
                    title: savedDetail.title,
                    level: savedDetail.level,
                    category: savedDetail.category,
                    tagsRaw: savedDetail.tagsRaw,
                    isPro: savedDetail.isPro,
                    isPublished: savedDetail.isPublished,
                    updatedAtLabel: 'az once',
                  ))
              .copyWith(
                packId: savedDetail.packId,
                packName: _packNameFromId(savedDetail.packId, packs),
                title: savedDetail.title,
                level: savedDetail.level,
                category: savedDetail.category,
                tagsRaw: savedDetail.tagsRaw,
                isPro: savedDetail.isPro,
                isPublished: savedDetail.isPublished,
                updatedAtLabel: 'az once',
              );
      ref.read(adminReadingChangesProvider.notifier).upsert(record);
    } else {
      if (existing != null) {
        ref
            .read(adminReadingChangesProvider.notifier)
            .upsert(
              existing.copyWith(
                packId: savedDetail.packId,
                packName: _packNameFromId(savedDetail.packId, packs),
                title: savedDetail.title,
                level: savedDetail.level,
                category: savedDetail.category,
                tagsRaw: savedDetail.tagsRaw,
                isPro: savedDetail.isPro,
                isPublished: savedDetail.isPublished,
                updatedAtLabel: 'az once',
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
      ref.read(adminGrammarChangesProvider.notifier).remove(module.id.toString());
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

  String? _packNameFromId(String? packId, List<AdminPackRecord> packs) {
    if (packId == null) {
      return null;
    }
    for (final pack in packs) {
      if (pack.id == packId) {
        return pack.name;
      }
    }
    return null;
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
    final hasSelected = packs.any((item) => item.id == _selectedPackId);
    if (_selectedPackId == null || !hasSelected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _selectedPackId = packs.first.id;
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
    AdminDestination.readings => 'Okuma CMS',
    AdminDestination.words => 'Kelime CMS',
    AdminDestination.grammar => 'Gramer CMS',
    _ => 'Icerik CMS',
  };

  String _subtitleFor(AdminDestination destination) => switch (destination) {
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
    required this.onTogglePublished,
  });

  final AdminReadingRecord reading;
  final String packLabel;
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
        detail.packId ??
        (widget.packs.isEmpty ? null : widget.packs.first.id);
    _enWordController = TextEditingController(text: detail.enWord);
    _trMeaningController = TextEditingController(
      text: detail.trMeaning,
    );
    _posController = TextEditingController(text: detail.pos);
    _posRawController = TextEditingController(text: detail.posRaw ?? '');
    _exampleEnController = TextEditingController(
      text: detail.exampleEn,
    );
    _exampleTrController = TextEditingController(
      text: detail.exampleTr ?? '',
    );
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
      title: Text(
        metadata.id == null ? 'Yeni Kelime' : 'Kelimeyi Duzenle',
      ),
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
            final unpublishAt = _parseDateTimeInput(_unpublishAtController.text);
            if (_packId == null ||
                _enWordController.text.trim().isEmpty ||
                _trMeaningController.text.trim().isEmpty ||
                _posController.text.trim().isEmpty ||
                _exampleEnController.text.trim().isEmpty) {
              setState(() {
                _validationMessage = 'Paket, EN kelime, TR anlam, POS ve example EN zorunlu.';
              });
              return;
            }
            if ((_publishAtController.text.trim().isNotEmpty && publishAt == null) ||
                (_unpublishAtController.text.trim().isNotEmpty && unpublishAt == null)) {
              setState(() {
                _validationMessage = 'Publish/Unpublish alanlari gecersiz tarih formatinda.';
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
  });

  final List<AdminPackRecord> packs;
  final AdminReadingDetail initialDetail;

  @override
  State<_ReadingEditorDialog> createState() => _ReadingEditorDialogState();
}

class _ReadingEditorDialogState extends State<_ReadingEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _levelController;
  late final TextEditingController _categoryController;
  late final TextEditingController _tagsController;
  late final TextEditingController _publishAtController;
  late final TextEditingController _unpublishAtController;
  late final TextEditingController _sentencesJsonController;
  late final TextEditingController _linkedWordsJsonController;
  late bool _isPro;
  late bool _isPublished;
  String? _validationMessage;
  String? _packId;

  @override
  void initState() {
    super.initState();
    final detail = widget.initialDetail;
    _titleController = TextEditingController(text: detail.title);
    _levelController = TextEditingController(text: detail.level ?? '');
    _categoryController = TextEditingController(text: detail.category ?? '');
    _tagsController = TextEditingController(text: detail.tagsRaw ?? '');
    _publishAtController = TextEditingController(
      text: _formatDateTimeInput(detail.publishAt),
    );
    _unpublishAtController = TextEditingController(
      text: _formatDateTimeInput(detail.unpublishAt),
    );
    _sentencesJsonController = TextEditingController(
      text: _prettyJson(
        detail.sentences.map((item) => item.toJson()).toList(growable: false),
      ),
    );
    _linkedWordsJsonController = TextEditingController(
      text: _prettyJson(
        detail.linkedWords.map((item) => item.toJson()).toList(growable: false),
      ),
    );
    _isPro = detail.isPro;
    _isPublished = detail.isPublished;
    _packId = detail.packId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _levelController.dispose();
    _categoryController.dispose();
    _tagsController.dispose();
    _publishAtController.dispose();
    _unpublishAtController.dispose();
    _sentencesJsonController.dispose();
    _linkedWordsJsonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metadata = widget.initialDetail.metadata;
    return AlertDialog(
      title: Text(metadata.id == null ? 'Yeni Okuma' : 'Okumayi Duzenle'),
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
              DropdownButtonFormField<String?>(
                initialValue: _packId,
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
                  setState(() {
                    _packId = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Baslik'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _levelController,
                      decoration: const InputDecoration(labelText: 'Seviye'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _categoryController,
                      decoration: const InputDecoration(labelText: 'Kategori'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tagler',
                  helperText: 'Virgulle ayir: science, exams, b1',
                ),
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
                subtitle: const Text(
                  'Free kullanici karti gorur, detay icin Pro gerekir.',
                ),
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
              TextField(
                controller: _sentencesJsonController,
                maxLines: 12,
                decoration: const InputDecoration(
                  labelText: 'Sentences JSON',
                  helperText:
                      'Her kayit: idx, sentence_en, sentence_tr, translations[].',
                ),
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
            final publishAt = _parseDateTimeInput(_publishAtController.text);
            final unpublishAt = _parseDateTimeInput(_unpublishAtController.text);
            if (title.isEmpty) {
              setState(() {
                _validationMessage = 'Baslik zorunlu.';
              });
              return;
            }
            if ((_publishAtController.text.trim().isNotEmpty && publishAt == null) ||
                (_unpublishAtController.text.trim().isNotEmpty && unpublishAt == null)) {
              setState(() {
                _validationMessage = 'Publish/Unpublish alanlari gecersiz tarih formatinda.';
              });
              return;
            }
            final sentencesJson = _decodeJsonArray(_sentencesJsonController.text);
            final linkedWordsJson = _decodeJsonArray(_linkedWordsJsonController.text);
            if (sentencesJson == null || linkedWordsJson == null) {
              setState(() {
                _validationMessage = 'Sentences JSON veya Linked Words JSON gecersiz.';
              });
              return;
            }
            Navigator.of(context).pop(
              widget.initialDetail.copyWith(
                packId: _packId,
                title: title,
                level: _emptyAsNull(_levelController.text),
                category: _emptyAsNull(_categoryController.text),
                tagsRaw: _emptyAsNull(_tagsController.text),
                isPro: _isPro,
                isPublished: _isPublished,
                publishAt: publishAt,
                unpublishAt: unpublishAt,
                sentences: sentencesJson
                    .map(AdminReadingSentenceInput.fromJson)
                    .toList(growable: false),
                linkedWords: linkedWordsJson
                    .map(AdminReadingWordLinkInput.fromJson)
                    .toList(growable: false),
                clearLevel: _levelController.text.trim().isEmpty,
                clearCategory: _categoryController.text.trim().isEmpty,
                clearTagsRaw: _tagsController.text.trim().isEmpty,
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
                      decoration: const InputDecoration(
                        labelText: 'Sira',
                      ),
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
            final sortOrder = int.tryParse(_sortOrderController.text.trim()) ?? 1;
            final publishAt = _parseDateTimeInput(_publishAtController.text);
            final unpublishAt = _parseDateTimeInput(_unpublishAtController.text);
            if (title.isEmpty || fileName.isEmpty) {
              setState(() {
                _validationMessage = 'Modul basligi ve dosya adi zorunlu.';
              });
              return;
            }
            if ((_publishAtController.text.trim().isNotEmpty && publishAt == null) ||
                (_unpublishAtController.text.trim().isNotEmpty && unpublishAt == null)) {
              setState(() {
                _validationMessage = 'Publish/Unpublish alanlari gecersiz tarih formatinda.';
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
      text: '''import_key,pack_name,title,level,category,tags_raw,is_pro,is_published,sentence_idx,sentence_en,sentence_tr,translations_json,linked_words_json
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
  final hasHeader = normalizedFirstRow.contains('en_word') &&
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

  final packById = <String, String>{
    for (final pack in packs) pack.id: pack.id,
  };
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

    final importKey = _emptyAsNull(record['import_key'] ?? '') ??
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

    final translationsJson = _decodeJsonArray(record['translations_json'] ?? '');
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
        Text(
          'Metadata',
          style: Theme.of(context).textTheme.titleMedium,
        ),
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
      .map(
        (item) => item.map((key, value) => MapEntry(key.toString(), value)),
      )
      .toList(growable: false);
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
  final normalized = trimmed.contains('T') ? trimmed : trimmed.replaceFirst(' ', 'T');
  return DateTime.tryParse(normalized);
}

String? _emptyAsNull(String rawValue) {
  final trimmed = rawValue.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

