import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';
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
    switch (widget.destination) {
      case AdminDestination.words:
        final packs = ref.watch(adminPacksProvider);
        final words = ref.watch(adminWordEntriesProvider);
        return packs.when(
          data: (packItems) => words.when(
            data: (wordItems) {
              _ensureSelectedPack(packItems);
              return _buildWordsLayout(context, packItems, wordItems);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Text(error.toString()),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Text(error.toString()),
        );
      case AdminDestination.readings:
        final packs = ref.watch(adminPacksProvider);
        final readings = ref.watch(adminReadingsProvider);
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
    List<AdminWordRecord> words,
  ) {
    AdminPackRecord? selectedPack;
    for (final item in packs) {
      if (item.id == _selectedPackId) {
        selectedPack = item;
        break;
      }
    }
    final activePack = selectedPack;
    final visibleWords = words
        .where((item) => selectedPack == null || item.packId == selectedPack.id)
        .where((item) {
          if (_query.isEmpty) {
            return true;
          }
          final haystack =
              '${item.enWord} ${item.trMeaning} ${item.pos} ${item.level ?? ''}'
                  .toLowerCase();
          return haystack.contains(_query);
        })
        .toList(growable: false);

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
                      });
                    },
                    onEdit: () => _openPackEditor(context, existing: pack),
                    onDelete: () => _deletePack(context, pack, words),
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
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Kelime, anlam veya etiket ara',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _query = value.trim().toLowerCase();
                        });
                      },
                    ),
                  ),
                  if (activePack != null) ...[
                    const SizedBox(width: 12),
                    _MetricChip(
                      label:
                          '${visibleWords.length} / ${activePack.wordCount} kelime',
                    ),
                    const SizedBox(width: 12),
                    _MetricChip(label: 'guncel ${activePack.updatedAtLabel}'),
                  ],
                ],
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
              else
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
    List<AdminReadingRecord> readings,
  ) {
    final levels =
        readings
            .map((item) => item.level)
            .whereType<String>()
            .toSet()
            .toList(growable: false)
          ..sort();
    final visibleReadings = readings
        .where((item) {
          final matchesLevel =
              _readingLevelFilter == null || item.level == _readingLevelFilter;
          final haystack =
              '${item.title} ${item.category ?? ''} ${item.level ?? ''} ${item.tagsRaw ?? ''}'
                  .toLowerCase();
          final matchesQuery = _query.isEmpty || haystack.contains(_query);
          return matchesLevel && matchesQuery;
        })
        .toList(growable: false);

    return AdminPanelCard(
      title: 'Okuma Operasyonlari',
      trailing: FilledButton.icon(
        onPressed: () => _openReadingEditor(context, packs: packs),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Yeni Parca Ekle'),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Baslik, kategori veya tag ara',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _query = value.trim().toLowerCase();
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String?>(
                  initialValue: _readingLevelFilter,
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
                    });
                  },
                ),
              ),
            ],
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
          else
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
      ref.read(adminPackChangesProvider.notifier).clear();
      ref.invalidate(adminPacksProvider);
      ref.invalidate(adminWordEntriesProvider);
      ref.invalidate(adminReadingsProvider);
    }

    _pushAudit(
      existing == null ? 'admin.pack.created' : 'admin.pack.updated',
      draft.name,
    );
    _showSnackBar(
      existing == null ? 'Paket olusturuldu.' : 'Paket guncellendi.',
    );
  }

  Future<void> _deletePack(
    BuildContext context,
    AdminPackRecord pack,
    List<AdminWordRecord> words,
  ) async {
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
      ref.read(adminPackChangesProvider.notifier).clear();
      ref.read(adminWordChangesProvider.notifier).clear();
      ref.invalidate(adminPacksProvider);
      ref.invalidate(adminWordEntriesProvider);
      ref.invalidate(adminReadingsProvider);
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
      ref.read(adminPackChangesProvider.notifier).clear();
      ref.invalidate(adminPacksProvider);
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
    final draft = await showDialog<_WordEditorDraft>(
      context: context,
      builder: (context) => _WordEditorDialog(
        packs: packs,
        existing: existing,
        selectedPackId: selectedPackId,
      ),
    );
    if (draft == null) {
      return;
    }

    final result = await ref
        .read(adminContentRepositoryProvider)
        .upsertWord(
          wordId: existing?.id,
          packId: draft.packId,
          enWord: draft.enWord,
          trMeaning: draft.trMeaning,
          pos: draft.pos,
          exampleEn: draft.exampleEn,
          exampleTr: draft.exampleTr,
          level: draft.level,
          notes: draft.notes,
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
                  AdminWordRecord(
                    id: _clientId('word'),
                    packId: draft.packId,
                    enWord: draft.enWord,
                    trMeaning: draft.trMeaning,
                    pos: draft.pos,
                    exampleEn: draft.exampleEn,
                    exampleTr: draft.exampleTr,
                    level: draft.level,
                    notes: draft.notes,
                    isPublished: draft.isPublished,
                    updatedAtLabel: 'az once',
                  ))
              .copyWith(
                packId: draft.packId,
                enWord: draft.enWord,
                trMeaning: draft.trMeaning,
                pos: draft.pos,
                exampleEn: draft.exampleEn,
                exampleTr: draft.exampleTr,
                level: draft.level,
                notes: draft.notes,
                isPublished: draft.isPublished,
                updatedAtLabel: 'az once',
              );
      ref.read(adminWordChangesProvider.notifier).upsert(record);
      setState(() {
        _selectedPackId = draft.packId;
      });
    } else {
      ref.read(adminWordChangesProvider.notifier).clear();
      ref.invalidate(adminWordEntriesProvider);
      ref.invalidate(adminPacksProvider);
    }

    _pushAudit(
      existing == null ? 'admin.word.created' : 'admin.word.updated',
      draft.enWord,
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
      ref.read(adminWordChangesProvider.notifier).clear();
      ref.invalidate(adminWordEntriesProvider);
      ref.invalidate(adminPacksProvider);
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
      ref.read(adminWordChangesProvider.notifier).clear();
      ref.invalidate(adminWordEntriesProvider);
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
      ref.read(adminWordChangesProvider.notifier).clear();
      ref.invalidate(adminWordEntriesProvider);
      ref.invalidate(adminPacksProvider);
    }

    _pushAudit('admin.word.imported', '${pack.name} / ${rows.length} satir');
    _showSnackBar('${rows.length} kelime import edildi.');
  }

  Future<void> _openReadingEditor(
    BuildContext context, {
    required List<AdminPackRecord> packs,
    AdminReadingRecord? existing,
  }) async {
    final draft = await showDialog<_ReadingEditorDraft>(
      context: context,
      builder: (context) =>
          _ReadingEditorDialog(packs: packs, existing: existing),
    );
    if (draft == null) {
      return;
    }

    final result = await ref
        .read(adminContentRepositoryProvider)
        .upsertReading(
          readingId: existing?.id,
          packId: draft.packId,
          packName: draft.packName,
          title: draft.title,
          level: draft.level,
          category: draft.category,
          tagsRaw: draft.tagsRaw,
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
                  AdminReadingRecord(
                    id: _clientId('reading'),
                    packId: draft.packId,
                    packName: draft.packName,
                    title: draft.title,
                    level: draft.level,
                    category: draft.category,
                    tagsRaw: draft.tagsRaw,
                    isPublished: draft.isPublished,
                    updatedAtLabel: 'az once',
                  ))
              .copyWith(
                packId: draft.packId,
                packName: draft.packName,
                title: draft.title,
                level: draft.level,
                category: draft.category,
                tagsRaw: draft.tagsRaw,
                isPublished: draft.isPublished,
                updatedAtLabel: 'az once',
              );
      ref.read(adminReadingChangesProvider.notifier).upsert(record);
    } else {
      ref.read(adminReadingChangesProvider.notifier).clear();
      ref.invalidate(adminReadingsProvider);
    }

    _pushAudit(
      existing == null ? 'admin.reading.created' : 'admin.reading.updated',
      draft.title,
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
      ref.read(adminReadingChangesProvider.notifier).clear();
      ref.invalidate(adminReadingsProvider);
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
      ref.read(adminReadingChangesProvider.notifier).clear();
      ref.invalidate(adminReadingsProvider);
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
    final draft = await showDialog<_GrammarEditorDraft>(
      context: context,
      builder: (context) => _GrammarEditorDialog(existing: existing),
    );
    if (draft == null) {
      return;
    }

    final result = await ref
        .read(adminContentRepositoryProvider)
        .upsertGrammarModule(
          moduleId: existing?.id,
          sortOrder: existing?.sortOrder,
          title: draft.title,
          fileName: draft.fileName,
          pageCount: draft.pageCount,
          icon: draft.icon,
          color: draft.color,
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
      final currentModules = await ref.read(adminGrammarModulesProvider.future);
      final nextId = currentModules.fold<int>(
        0,
        (maxId, item) => math.max(maxId, item.id),
      );
      final record =
          (existing ??
                  AdminGrammarRecord(
                    id: nextId + 1,
                    sortOrder: currentModules.length + 1,
                    title: draft.title,
                    fileName: draft.fileName,
                    pageCount: draft.pageCount,
                    icon: draft.icon,
                    color: draft.color,
                    isPublished: draft.isPublished,
                    updatedAtLabel: 'az once',
                  ))
              .copyWith(
                title: draft.title,
                fileName: draft.fileName,
                pageCount: draft.pageCount,
                icon: draft.icon,
                color: draft.color,
                isPublished: draft.isPublished,
                updatedAtLabel: 'az once',
              );
      ref.read(adminGrammarChangesProvider.notifier).upsert(record);
    } else {
      ref.read(adminGrammarChangesProvider.notifier).clear();
      ref.invalidate(adminGrammarModulesProvider);
    }

    _pushAudit(
      existing == null ? 'admin.grammar.created' : 'admin.grammar.updated',
      draft.title,
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
      ref.read(adminGrammarChangesProvider.notifier).clear();
      ref.invalidate(adminGrammarModulesProvider);
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
      ref.read(adminGrammarChangesProvider.notifier).clear();
      ref.invalidate(adminGrammarModulesProvider);
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
    _pushAudit('admin.grammar.reordered', '${item.title} sirasi guncellendi');
    _showSnackBar('Gramer sirasi guncellendi.');
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
                _MetricChip(label: word.updatedAtLabel),
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
                _MetricChip(label: reading.updatedAtLabel),
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
  const _WordEditorDialog({
    required this.packs,
    this.existing,
    this.selectedPackId,
  });

  final List<AdminPackRecord> packs;
  final AdminWordRecord? existing;
  final String? selectedPackId;

  @override
  State<_WordEditorDialog> createState() => _WordEditorDialogState();
}

class _WordEditorDialogState extends State<_WordEditorDialog> {
  late final TextEditingController _enWordController;
  late final TextEditingController _trMeaningController;
  late final TextEditingController _posController;
  late final TextEditingController _exampleEnController;
  late final TextEditingController _exampleTrController;
  late final TextEditingController _levelController;
  late final TextEditingController _notesController;
  late bool _isPublished;
  String? _packId;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _packId =
        existing?.packId ??
        widget.selectedPackId ??
        (widget.packs.isEmpty ? null : widget.packs.first.id);
    _enWordController = TextEditingController(text: existing?.enWord ?? '');
    _trMeaningController = TextEditingController(
      text: existing?.trMeaning ?? '',
    );
    _posController = TextEditingController(text: existing?.pos ?? 'n.');
    _exampleEnController = TextEditingController(
      text: existing?.exampleEn ?? '',
    );
    _exampleTrController = TextEditingController(
      text: existing?.exampleTr ?? '',
    );
    _levelController = TextEditingController(text: existing?.level ?? '');
    _notesController = TextEditingController(text: existing?.notes ?? '');
    _isPublished = existing?.isPublished ?? true;
  }

  @override
  void dispose() {
    _enWordController.dispose();
    _trMeaningController.dispose();
    _posController.dispose();
    _exampleEnController.dispose();
    _exampleTrController.dispose();
    _levelController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Yeni Kelime' : 'Kelimeyi Duzenle'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notlar'),
                maxLines: 3,
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
                subtitle: const Text('Kelime student tarafinda gorunsun.'),
              ),
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
            if (_packId == null ||
                _enWordController.text.trim().isEmpty ||
                _trMeaningController.text.trim().isEmpty ||
                _posController.text.trim().isEmpty ||
                _exampleEnController.text.trim().isEmpty) {
              return;
            }
            Navigator.of(context).pop(
              _WordEditorDraft(
                packId: _packId!,
                enWord: _enWordController.text.trim(),
                trMeaning: _trMeaningController.text.trim(),
                pos: _posController.text.trim(),
                exampleEn: _exampleEnController.text.trim(),
                exampleTr: _emptyAsNull(_exampleTrController.text),
                level: _emptyAsNull(_levelController.text),
                notes: _emptyAsNull(_notesController.text),
                isPublished: _isPublished,
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
  const _ReadingEditorDialog({required this.packs, this.existing});

  final List<AdminPackRecord> packs;
  final AdminReadingRecord? existing;

  @override
  State<_ReadingEditorDialog> createState() => _ReadingEditorDialogState();
}

class _ReadingEditorDialogState extends State<_ReadingEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _levelController;
  late final TextEditingController _categoryController;
  late final TextEditingController _tagsController;
  late bool _isPublished;
  String? _packId;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _levelController = TextEditingController(text: existing?.level ?? '');
    _categoryController = TextEditingController(text: existing?.category ?? '');
    _tagsController = TextEditingController(text: existing?.tagsRaw ?? '');
    _isPublished = existing?.isPublished ?? true;
    _packId = existing?.packId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _levelController.dispose();
    _categoryController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Yeni Okuma' : 'Okumayi Duzenle'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                value: _isPublished,
                onChanged: (value) {
                  setState(() {
                    _isPublished = value;
                  });
                },
                title: const Text('Yayinda'),
                subtitle: const Text('Parca student listesinde gorunsun.'),
              ),
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
            if (title.isEmpty) {
              return;
            }
            AdminPackRecord? pack;
            for (final item in widget.packs) {
              if (item.id == _packId) {
                pack = item;
                break;
              }
            }
            Navigator.of(context).pop(
              _ReadingEditorDraft(
                packId: _packId,
                packName: pack?.name,
                title: title,
                level: _emptyAsNull(_levelController.text),
                category: _emptyAsNull(_categoryController.text),
                tagsRaw: _emptyAsNull(_tagsController.text),
                isPublished: _isPublished,
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
  const _GrammarEditorDialog({this.existing});

  final AdminGrammarRecord? existing;

  @override
  State<_GrammarEditorDialog> createState() => _GrammarEditorDialogState();
}

class _GrammarEditorDialogState extends State<_GrammarEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _fileNameController;
  late final TextEditingController _pageCountController;
  late final TextEditingController _iconController;
  late final TextEditingController _colorController;
  late bool _isPublished;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _fileNameController = TextEditingController(text: existing?.fileName ?? '');
    _pageCountController = TextEditingController(
      text: existing?.pageCount.toString() ?? '0',
    );
    _iconController = TextEditingController(text: existing?.icon ?? '📘');
    _colorController = TextEditingController(
      text: existing?.color ?? '#4776E6',
    );
    _isPublished = existing?.isPublished ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _fileNameController.dispose();
    _pageCountController.dispose();
    _iconController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Yeni Modul' : 'Modulu Duzenle'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                      controller: _pageCountController,
                      decoration: const InputDecoration(
                        labelText: 'Toplam sayfa',
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
            final pageCount =
                int.tryParse(_pageCountController.text.trim()) ?? 0;
            if (title.isEmpty || fileName.isEmpty) {
              return;
            }
            Navigator.of(context).pop(
              _GrammarEditorDraft(
                title: title,
                fileName: fileName,
                pageCount: pageCount,
                icon: _iconController.text.trim().isEmpty
                    ? '📘'
                    : _iconController.text.trim(),
                color: _colorController.text.trim().isEmpty
                    ? '#4776E6'
                    : _colorController.text.trim(),
                isPublished: _isPublished,
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
    final lines = rawValue
        .split('\n')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    final rows = <Map<String, dynamic>>[];
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      if (index == 0 && line.toLowerCase().startsWith('en_word,')) {
        continue;
      }
      final parts = line.split(',');
      if (parts.length < 4) {
        continue;
      }
      rows.add(<String, dynamic>{
        'en_word': parts[0].trim(),
        'tr_meaning': parts[1].trim(),
        'pos': parts[2].trim().isEmpty ? 'other' : parts[2].trim(),
        'example_en': parts[3].trim(),
        'example_tr': parts.length > 4 ? _emptyAsNull(parts[4]) : null,
        'level': parts.length > 5 ? _emptyAsNull(parts[5]) : null,
        'notes': parts.length > 6
            ? _emptyAsNull(parts.sublist(6).join(','))
            : null,
      });
    }
    return rows;
  }
}

class _PackEditorDraft {
  const _PackEditorDraft({required this.name, required this.isPublished});

  final String name;
  final bool isPublished;
}

class _WordEditorDraft {
  const _WordEditorDraft({
    required this.packId,
    required this.enWord,
    required this.trMeaning,
    required this.pos,
    required this.exampleEn,
    required this.exampleTr,
    required this.level,
    required this.notes,
    required this.isPublished,
  });

  final String packId;
  final String enWord;
  final String trMeaning;
  final String pos;
  final String exampleEn;
  final String? exampleTr;
  final String? level;
  final String? notes;
  final bool isPublished;
}

class _ReadingEditorDraft {
  const _ReadingEditorDraft({
    required this.packId,
    required this.packName,
    required this.title,
    required this.level,
    required this.category,
    required this.tagsRaw,
    required this.isPublished,
  });

  final String? packId;
  final String? packName;
  final String title;
  final String? level;
  final String? category;
  final String? tagsRaw;
  final bool isPublished;
}

class _GrammarEditorDraft {
  const _GrammarEditorDraft({
    required this.title,
    required this.fileName,
    required this.pageCount,
    required this.icon,
    required this.color,
    required this.isPublished,
  });

  final String title;
  final String fileName;
  final int pageCount;
  final String icon;
  final String color;
  final bool isPublished;
}

String? _emptyAsNull(String rawValue) {
  final trimmed = rawValue.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}
