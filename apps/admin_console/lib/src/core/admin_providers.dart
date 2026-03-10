import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_data/shared_data.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_access_controller.dart';
import 'admin_cms_controller.dart';
import 'admin_console_models.dart';

final adminAppConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment(
    appName: 'PASSAGETR Admin Console',
    platformMode: kIsWeb ? PlatformMode.web : PlatformMode.mobile,
    adminPreviewEnabled: true,
  );
});

final adminAccessProvider =
    StateNotifierProvider<AdminAccessController, AccessContext>(
      (ref) => AdminAccessController(
        authRepository: ref.watch(adminAuthRepositoryProvider),
        initialAccessContext: AccessContext.preview(
          role: AppRole.admin,
          plan: EntitlementPlan.free,
          isAnonymous: false,
        ),
      ),
    );

final adminAuthRepositoryProvider = Provider<FoundationAuthRepository>((ref) {
  final repository = FoundationAuthRepository(
    config: ref.watch(adminAppConfigProvider),
    fallbackAccessContext: AccessContext.preview(
      role: AppRole.admin,
      plan: EntitlementPlan.free,
      isAnonymous: false,
    ),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final adminContentRepositoryProvider = Provider<AdminContentRepository>(
  (ref) => FoundationAdminContentRepository(
    config: ref.watch(adminAppConfigProvider),
  ),
);

final adminUserAccessServiceProvider = Provider<AdminUserAccessService>(
  (ref) => AdminUserAccessService(config: ref.watch(adminAppConfigProvider)),
);

final _previewPackRepositoryProvider = Provider<PackRepository>(
  (ref) => FoundationPackRepository(config: ref.watch(adminAppConfigProvider)),
);

final _previewWordRepositoryProvider = Provider<WordRepository>(
  (ref) => FoundationWordRepository(config: ref.watch(adminAppConfigProvider)),
);

final _previewReadingRepositoryProvider = Provider<ReadingRepository>(
  (ref) =>
      FoundationReadingRepository(config: ref.watch(adminAppConfigProvider)),
);

final _previewGrammarRepositoryProvider = Provider<GrammarRepository>(
  (ref) =>
      FoundationGrammarRepository(config: ref.watch(adminAppConfigProvider)),
);

final adminPackChangesProvider =
    StateNotifierProvider<
      AdminCollectionController<AdminPackRecord>,
      AdminCollectionState<AdminPackRecord>
    >(
      (ref) =>
          AdminCollectionController<AdminPackRecord>(idOf: (item) => item.id),
    );

final adminWordChangesProvider =
    StateNotifierProvider<
      AdminCollectionController<AdminWordRecord>,
      AdminCollectionState<AdminWordRecord>
    >(
      (ref) =>
          AdminCollectionController<AdminWordRecord>(idOf: (item) => item.id),
    );

final adminReadingChangesProvider =
    StateNotifierProvider<
      AdminCollectionController<AdminReadingRecord>,
      AdminCollectionState<AdminReadingRecord>
    >(
      (ref) => AdminCollectionController<AdminReadingRecord>(
        idOf: (item) => item.id,
      ),
    );

final adminGrammarChangesProvider =
    StateNotifierProvider<
      AdminCollectionController<AdminGrammarRecord>,
      AdminCollectionState<AdminGrammarRecord>
    >(
      (ref) => AdminCollectionController<AdminGrammarRecord>(
        idOf: (item) => item.id.toString(),
      ),
    );

final _adminPacksBaseProvider = FutureProvider<List<AdminPackRecord>>((ref) {
  return _loadAdminPacks(
    ref.watch(adminAppConfigProvider),
    previewRepository: ref.watch(_previewPackRepositoryProvider),
  );
});

final _adminWordEntriesBaseProvider = FutureProvider<List<AdminWordRecord>>((
  ref,
) {
  return _loadAdminWords(
    ref.watch(adminAppConfigProvider),
    previewRepository: ref.watch(_previewWordRepositoryProvider),
  );
});

final _adminReadingsBaseProvider = FutureProvider<List<AdminReadingRecord>>((
  ref,
) {
  return _loadAdminReadings(
    ref.watch(adminAppConfigProvider),
    previewRepository: ref.watch(_previewReadingRepositoryProvider),
  );
});

final _adminGrammarModulesBaseProvider =
    FutureProvider<List<AdminGrammarRecord>>((ref) {
      return _loadAdminGrammarModules(
        ref.watch(adminAppConfigProvider),
        previewRepository: ref.watch(_previewGrammarRepositoryProvider),
      );
    });

final adminWordEntriesProvider = FutureProvider<List<AdminWordRecord>>((
  ref,
) async {
  final changes = ref.watch(adminWordChangesProvider);
  final items = await ref.watch(_adminWordEntriesBaseProvider.future);
  final merged = _mergeCollection(items, changes, idOf: (item) => item.id)
    ..sort((left, right) => left.enWord.compareTo(right.enWord));
  return merged;
});

final adminPacksProvider = FutureProvider<List<AdminPackRecord>>((ref) async {
  final changes = ref.watch(adminPackChangesProvider);
  final baseItems = await ref.watch(_adminPacksBaseProvider.future);
  final words = await ref.watch(adminWordEntriesProvider.future);
  final wordCounts = <String, int>{};
  for (final item in words) {
    wordCounts.update(item.packId, (value) => value + 1, ifAbsent: () => 1);
  }

  final merged =
      _mergeCollection(baseItems, changes, idOf: (item) => item.id)
          .map((item) {
            return item.copyWith(wordCount: wordCounts[item.id] ?? 0);
          })
          .toList(growable: false)
        ..sort((left, right) => left.name.compareTo(right.name));

  return merged;
});

final adminReadingsProvider = FutureProvider<List<AdminReadingRecord>>((
  ref,
) async {
  final changes = ref.watch(adminReadingChangesProvider);
  final items = await ref.watch(_adminReadingsBaseProvider.future);
  final merged = _mergeCollection(items, changes, idOf: (item) => item.id)
    ..sort((left, right) => left.title.compareTo(right.title));
  return merged;
});

final adminGrammarModulesProvider = FutureProvider<List<AdminGrammarRecord>>((
  ref,
) async {
  final changes = ref.watch(adminGrammarChangesProvider);
  final items = await ref.watch(_adminGrammarModulesBaseProvider.future);
  final merged =
      _mergeCollection(items, changes, idOf: (item) => item.id.toString())
        ..sort((left, right) {
          final byOrder = left.sortOrder.compareTo(right.sortOrder);
          if (byOrder != 0) {
            return byOrder;
          }
          return left.id.compareTo(right.id);
        });
  return merged;
});

final adminUserOverridesProvider =
    StateNotifierProvider<
      AdminUserOverridesController,
      Map<String, AdminUserRecord>
    >((ref) => AdminUserOverridesController());

final adminPublishOverridesProvider =
    StateNotifierProvider<AdminPublishOverridesController, Map<String, bool>>(
      (ref) => AdminPublishOverridesController(),
    );

final adminAuditOverridesProvider =
    StateNotifierProvider<AdminAuditLogController, List<AdminAuditRecord>>(
      (ref) => AdminAuditLogController(),
    );

final adminUsersProvider = FutureProvider<List<AdminUserRecord>>((ref) async {
  final overrides = ref.watch(adminUserOverridesProvider);
  final baseUsers = await _loadAdminUsers(ref.watch(adminAppConfigProvider));
  return baseUsers
      .map((user) => overrides[user.id] ?? user)
      .toList(growable: false);
});

final adminAuditLogProvider = FutureProvider<List<AdminAuditRecord>>((
  ref,
) async {
  final remote = await _loadAdminAuditLogs(ref.watch(adminAppConfigProvider));
  final local = ref.watch(adminAuditOverridesProvider);
  return <AdminAuditRecord>[...local, ...remote];
});

final adminDashboardSummaryProvider = FutureProvider<AdminDashboardSummary>((
  ref,
) async {
  final users = await ref.watch(adminUsersProvider.future);
  final words = await ref.watch(adminWordEntriesProvider.future);
  final readings = await ref.watch(adminReadingsProvider.future);
  final grammar = await ref.watch(adminGrammarModulesProvider.future);
  final audits = await ref.watch(adminAuditLogProvider.future);

  return AdminDashboardSummary(
    userCount: users.length,
    proUserCount: users
        .where((item) => item.plan == EntitlementPlan.pro)
        .length,
    wordCount: words.length,
    readingCount: readings.length,
    grammarCount: grammar.length,
    auditCount: audits.length,
  );
});

final adminBootstrapProvider = FutureProvider<void>((ref) async {
  await ref.read(adminAccessProvider.notifier).restoreSession();
});

Future<List<AdminUserRecord>> _loadAdminUsers(AppConfig config) async {
  if (!config.supabaseEnabled) {
    return _fallbackAdminUsers;
  }

  await SupabaseBootstrap.initialize(config);
  final session = Supabase.instance.client.auth.currentSession;
  if (session == null) {
    return _fallbackAdminUsers;
  }

  try {
    final rows =
        (await Supabase.instance.client.rpc<dynamic>('admin_list_users'))
            as List<dynamic>;

    return rows
        .whereType<Map<String, dynamic>>()
        .map(
          (row) => AdminUserRecord(
            id: row['user_id']?.toString() ?? '',
            email: row['email']?.toString() ?? '',
            role: _parseRole(row['app_role']?.toString()),
            plan: _parsePlan(row['plan']?.toString()),
            statusLabel: (row['is_anonymous'] as bool? ?? false)
                ? 'anonymous'
                : 'active',
            lastSeenLabel: _formatLastSeen(row['last_seen_at']),
          ),
        )
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  } catch (_) {
    return _fallbackAdminUsers;
  }
}

Future<List<AdminPackRecord>> _loadAdminPacks(
  AppConfig config, {
  required PackRepository previewRepository,
}) async {
  if (config.supabaseEnabled) {
    await SupabaseBootstrap.initialize(config);
    if (Supabase.instance.client.auth.currentSession != null) {
      try {
        final rows =
            (await Supabase.instance.client.rpc<dynamic>('admin_list_packs'))
                as List<dynamic>;
        return rows
            .whereType<Map<String, dynamic>>()
            .map(
              (row) => AdminPackRecord(
                id: row['id']?.toString() ?? '',
                name: row['name']?.toString() ?? '',
                wordCount: 0,
                isPublished: row['is_published'] as bool? ?? false,
                updatedAtLabel: _formatLastSeen(row['updated_at']),
              ),
            )
            .where((item) => item.id.isNotEmpty)
            .toList(growable: false);
      } catch (_) {}
    }
  }

  final packs = await previewRepository.fetchPacks();
  return packs
      .map(
        (item) => AdminPackRecord(
          id: item.id,
          name: item.name,
          wordCount: item.wordCount,
          isPublished: true,
          updatedAtLabel: 'preview',
        ),
      )
      .toList(growable: false);
}

Future<List<AdminWordRecord>> _loadAdminWords(
  AppConfig config, {
  required WordRepository previewRepository,
}) async {
  if (config.supabaseEnabled) {
    await SupabaseBootstrap.initialize(config);
    if (Supabase.instance.client.auth.currentSession != null) {
      try {
        final rows =
            (await Supabase.instance.client.rpc<dynamic>('admin_list_words'))
                as List<dynamic>;
        return rows
            .whereType<Map<String, dynamic>>()
            .map(
              (row) => AdminWordRecord(
                id: row['id']?.toString() ?? '',
                packId: row['pack_id']?.toString() ?? '',
                enWord: row['en_word']?.toString() ?? '',
                trMeaning: row['tr_meaning']?.toString() ?? '',
                pos: row['pos']?.toString() ?? '',
                exampleEn: row['example_en']?.toString() ?? '',
                exampleTr: row['example_tr']?.toString(),
                level: row['level']?.toString(),
                notes: row['notes']?.toString(),
                isPublished: row['is_published'] as bool? ?? false,
                updatedAtLabel: _formatLastSeen(row['updated_at']),
              ),
            )
            .where((item) => item.id.isNotEmpty)
            .toList(growable: false);
      } catch (_) {}
    }
  }

  final words = await previewRepository.fetchWords();
  return words
      .map(
        (item) => AdminWordRecord(
          id: item.id,
          packId: item.packId,
          enWord: item.enWord,
          trMeaning: item.trMeaning,
          pos: item.pos,
          exampleEn: '${item.enWord} example',
          exampleTr: null,
          level: null,
          notes: null,
          isPublished: true,
          updatedAtLabel: 'preview',
        ),
      )
      .toList(growable: false);
}

Future<List<AdminReadingRecord>> _loadAdminReadings(
  AppConfig config, {
  required ReadingRepository previewRepository,
}) async {
  if (config.supabaseEnabled) {
    await SupabaseBootstrap.initialize(config);
    if (Supabase.instance.client.auth.currentSession != null) {
      try {
        final rows =
            (await Supabase.instance.client.rpc<dynamic>(
                  'admin_list_reading_passages',
                ))
                as List<dynamic>;
        return rows
            .whereType<Map<String, dynamic>>()
            .map(
              (row) => AdminReadingRecord(
                id: row['id']?.toString() ?? '',
                packId: row['pack_id']?.toString(),
                packName: row['pack_name']?.toString(),
                title: row['title']?.toString() ?? '',
                level: row['level']?.toString(),
                category: row['category']?.toString(),
                tagsRaw: row['tags_raw']?.toString(),
                isPublished: row['is_published'] as bool? ?? false,
                updatedAtLabel: _formatLastSeen(row['updated_at']),
              ),
            )
            .where((item) => item.id.isNotEmpty)
            .toList(growable: false);
      } catch (_) {}
    }
  }

  final readings = await previewRepository.fetchReadings();
  return readings
      .map(
        (item) => AdminReadingRecord(
          id: item.id,
          packId: null,
          packName: null,
          title: item.title,
          level: item.level,
          category: item.category,
          tagsRaw: null,
          isPublished: true,
          updatedAtLabel: 'preview',
        ),
      )
      .toList(growable: false);
}

Future<List<AdminGrammarRecord>> _loadAdminGrammarModules(
  AppConfig config, {
  required GrammarRepository previewRepository,
}) async {
  if (config.supabaseEnabled) {
    await SupabaseBootstrap.initialize(config);
    if (Supabase.instance.client.auth.currentSession != null) {
      try {
        final rows =
            (await Supabase.instance.client.rpc<dynamic>(
                  'admin_list_grammar_modules',
                ))
                as List<dynamic>;
        return rows
            .whereType<Map<String, dynamic>>()
            .map(
              (row) => AdminGrammarRecord(
                id: (row['id'] as num?)?.toInt() ?? 0,
                sortOrder: (row['sira'] as num?)?.toInt() ?? 0,
                title: row['baslik']?.toString() ?? '',
                fileName: row['dosya_adi']?.toString() ?? '',
                pageCount: (row['toplam_sayfa'] as num?)?.toInt() ?? 0,
                icon: row['icon']?.toString() ?? '📘',
                color: row['renk']?.toString() ?? '#4776E6',
                isPublished: row['is_published'] as bool? ?? false,
                updatedAtLabel: _formatLastSeen(row['updated_at']),
              ),
            )
            .where((item) => item.id > 0)
            .toList(growable: false);
      } catch (_) {}
    }
  }

  final modules = await previewRepository.fetchModules();
  return modules
      .map(
        (item) => AdminGrammarRecord(
          id: item.id,
          sortOrder: item.id,
          title: item.title,
          fileName: 'module-${item.id}',
          pageCount: item.pageCount,
          icon: '📘',
          color: '#4776E6',
          isPublished: true,
          updatedAtLabel: 'preview',
        ),
      )
      .toList(growable: false);
}

Future<List<AdminAuditRecord>> _loadAdminAuditLogs(AppConfig config) async {
  if (!config.supabaseEnabled) {
    return const <AdminAuditRecord>[];
  }

  await SupabaseBootstrap.initialize(config);
  if (Supabase.instance.client.auth.currentSession == null) {
    return const <AdminAuditRecord>[];
  }

  try {
    final rows =
        (await Supabase.instance.client
                .from('audit_logs')
                .select('id,action,target_type,target_id,created_at')
                .order('created_at', ascending: false)
                .limit(8))
            as List<dynamic>;

    return rows
        .whereType<Map<String, dynamic>>()
        .map(
          (row) => AdminAuditRecord(
            id: row['id']?.toString() ?? '',
            title: row['action']?.toString() ?? 'audit',
            subtitle:
                '${row['target_type'] ?? '-'} / ${row['target_id'] ?? '-'}',
            timestampLabel: _formatLastSeen(row['created_at']),
          ),
        )
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  } catch (_) {
    return const <AdminAuditRecord>[];
  }
}

List<T> _mergeCollection<T>(
  List<T> baseItems,
  AdminCollectionState<T> changes, {
  required String Function(T item) idOf,
}) {
  final merged = <String, T>{};
  for (final item in baseItems) {
    final id = idOf(item);
    if (changes.deletedIds.contains(id)) {
      continue;
    }
    merged[id] = item;
  }

  for (final entry in changes.upserts.entries) {
    if (changes.deletedIds.contains(entry.key)) {
      continue;
    }
    merged[entry.key] = entry.value;
  }

  return merged.values.toList(growable: false);
}

AppRole _parseRole(String? value) {
  return AppRole.values.firstWhere(
    (item) => item.value == value,
    orElse: () => AppRole.user,
  );
}

EntitlementPlan _parsePlan(String? value) {
  return EntitlementPlan.values.firstWhere(
    (item) => item.value == value,
    orElse: () => EntitlementPlan.free,
  );
}

String _formatLastSeen(Object? rawValue) {
  final value = rawValue?.toString();
  if (value == null || value.isEmpty) {
    return '-';
  }

  final parsed = DateTime.tryParse(value)?.toLocal();
  if (parsed == null) {
    return value;
  }

  final delta = DateTime.now().difference(parsed);
  if (delta.inMinutes < 1) {
    return 'az once';
  }
  if (delta.inHours < 1) {
    return '${delta.inMinutes} dk once';
  }
  if (delta.inDays < 1) {
    return '${delta.inHours} saat once';
  }
  if (delta.inDays < 30) {
    return '${delta.inDays} gun once';
  }

  return '${parsed.day.toString().padLeft(2, '0')}.${parsed.month.toString().padLeft(2, '0')}.${parsed.year}';
}

const _fallbackAdminUsers = <AdminUserRecord>[
  AdminUserRecord(
    id: 'phase1-free',
    email: 'phase1.free@passagetr.dev',
    role: AppRole.user,
    plan: EntitlementPlan.free,
    statusLabel: 'active',
    lastSeenLabel: 'bugun',
  ),
  AdminUserRecord(
    id: 'phase1-pro',
    email: 'phase1.pro@passagetr.dev',
    role: AppRole.user,
    plan: EntitlementPlan.pro,
    statusLabel: 'active',
    lastSeenLabel: 'bugun',
  ),
  AdminUserRecord(
    id: 'phase1-admin',
    email: 'phase1.admin@passagetr.dev',
    role: AppRole.admin,
    plan: EntitlementPlan.pro,
    statusLabel: 'staff',
    lastSeenLabel: '5 dk once',
  ),
  AdminUserRecord(
    id: 'phase1-dev',
    email: 'phase1.developer@passagetr.dev',
    role: AppRole.developer,
    plan: EntitlementPlan.pro,
    statusLabel: 'staff',
    lastSeenLabel: 'az once',
  ),
];
