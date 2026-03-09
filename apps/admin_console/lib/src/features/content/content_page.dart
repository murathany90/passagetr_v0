import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';

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
      body: AdminPanelCard(
        title: 'Icerik Listesi',
        trailing: SizedBox(
          width: 280,
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Baslik veya kimlik ara',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (value) {
              setState(() {
                _query = value.trim().toLowerCase();
              });
            },
          ),
        ),
        child: _ContentTable(destination: widget.destination, query: _query),
      ),
    );
  }

  String _titleFor(AdminDestination destination) => switch (destination) {
    AdminDestination.readings => 'Okuma CMS',
    AdminDestination.words => 'Kelime CMS',
    AdminDestination.grammar => 'Gramer CMS',
    _ => 'Icerik CMS',
  };

  String _subtitleFor(AdminDestination destination) => switch (destination) {
    AdminDestination.readings =>
      'Parcalar, seviyeler ve yayin durumlarini yonet.',
    AdminDestination.words => 'Kelime havuzu ve pack iliskilerini denetle.',
    AdminDestination.grammar => 'Modul, sayfa ve quiz yuzeylerini organize et.',
    _ => 'Icerik operasyonlari.',
  };
}

class _ContentTable extends ConsumerWidget {
  const _ContentTable({required this.destination, required this.query});

  final AdminDestination destination;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (destination) {
      AdminDestination.readings =>
        ref
            .watch(adminReadingsProvider)
            .when(
              data: (items) => _ContentRows<AdminReadingRecord>(
                rows: items,
                query: query,
                titleFor: (item) => item.title,
                subtitleFor: (item) =>
                    '${item.category ?? '-'} | ${item.level ?? '-'}',
                entityIdFor: (item) => item.id,
                entityType: 'reading',
                isPublishedFor: (item) => item.isPublished,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Text(error.toString()),
            ),
      AdminDestination.words =>
        ref
            .watch(adminWordEntriesProvider)
            .when(
              data: (items) => _ContentRows<AdminWordRecord>(
                rows: items,
                query: query,
                titleFor: (item) => item.enWord,
                subtitleFor: (item) => '${item.trMeaning} | ${item.packId}',
                entityIdFor: (item) => item.id,
                entityType: 'word',
                isPublishedFor: (item) => item.isPublished,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Text(error.toString()),
            ),
      AdminDestination.grammar =>
        ref
            .watch(adminGrammarModulesProvider)
            .when(
              data: (items) => _ContentRows<AdminGrammarRecord>(
                rows: items,
                query: query,
                titleFor: (item) => item.title,
                subtitleFor: (item) => '${item.pageCount} sayfa',
                entityIdFor: (item) => '${item.id}',
                entityType: 'grammar',
                isPublishedFor: (item) => item.isPublished,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Text(error.toString()),
            ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _ContentRows<T> extends ConsumerWidget {
  const _ContentRows({
    required this.rows,
    required this.query,
    required this.titleFor,
    required this.subtitleFor,
    required this.entityIdFor,
    required this.entityType,
    required this.isPublishedFor,
  });

  final List<T> rows;
  final String query;
  final String Function(T item) titleFor;
  final String Function(T item) subtitleFor;
  final String Function(T item) entityIdFor;
  final String entityType;
  final bool Function(T item) isPublishedFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final publishOverrides = ref.watch(adminPublishOverridesProvider);
    final filtered = rows
        .where((item) {
          final haystack =
              '${titleFor(item)} ${subtitleFor(item)} ${entityIdFor(item)}'
                  .toLowerCase();
          return query.isEmpty || haystack.contains(query);
        })
        .toList(growable: false);

    return Column(
      children: [
        for (final item in filtered.take(20)) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleFor(item),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(subtitleFor(item)),
                    ],
                  ),
                ),
                Expanded(
                  child: Text(
                    entityIdFor(item),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Switch(
                        value: _resolvedPublishState(
                          publishOverrides: publishOverrides,
                          item: item,
                        ),
                        onChanged: (value) async {
                          final messenger = ScaffoldMessenger.of(context);
                          final entityId = entityIdFor(item);
                          ref
                              .read(adminPublishOverridesProvider.notifier)
                              .setPublished(
                                entityType: entityType,
                                entityId: entityId,
                                isPublished: value,
                              );

                          final result = await ref
                              .read(adminContentRepositoryProvider)
                              .setContentPublished(
                                entityType: entityType,
                                entityId: entityId,
                                isPublished: value,
                              );

                          if (result is AppFailure<void>) {
                            ref
                                .read(adminPublishOverridesProvider.notifier)
                                .setPublished(
                                  entityType: entityType,
                                  entityId: entityId,
                                  isPublished: isPublishedFor(item),
                                );
                            messenger.showSnackBar(
                              SnackBar(content: Text(result.message)),
                            );
                            return;
                          }

                          ref
                              .read(adminAuditOverridesProvider.notifier)
                              .push(
                                AdminAuditRecord(
                                  id: 'publish-$entityId-${DateTime.now().millisecondsSinceEpoch}',
                                  title: value
                                      ? 'content.published'
                                      : 'content.unpublished',
                                  subtitle: '$entityType / $entityId',
                                  timestampLabel: 'az once',
                                ),
                              );
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _resolvedPublishState(
                              publishOverrides: publishOverrides,
                              item: item,
                            )
                            ? 'Yayinda'
                            : 'Taslak',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
      ],
    );
  }

  bool _resolvedPublishState({
    required Map<String, bool> publishOverrides,
    required T item,
  }) {
    return publishOverrides['$entityType::${entityIdFor(item)}'] ??
        isPublishedFor(item);
  }
}
