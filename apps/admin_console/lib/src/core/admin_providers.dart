import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_data/shared_data.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_access_controller.dart';
import 'admin_ai_assistant_controller.dart';
import 'admin_cms_controller.dart';
import 'admin_console_models.dart';
import 'admin_settings_controller.dart';
import 'admin_user_management_controller.dart';

final adminAppConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment(
    appName: 'PASSAGETR Admin Console',
    platformMode: kIsWeb ? PlatformMode.web : PlatformMode.mobile,
    adminPreviewEnabled: true,
  );
});

final adminAuthStateProvider =
    StateNotifierProvider<AdminAccessController, AdminAuthState>(
      (ref) => AdminAccessController(
        authRepository: ref.watch(adminAuthRepositoryProvider),
      ),
    );

final adminAccessProvider = Provider<AccessContext>((ref) {
  return ref.watch(adminAuthStateProvider).accessContext;
});

final adminAuthRepositoryProvider = Provider<FoundationAuthRepository>((ref) {
  final config = ref.watch(adminAppConfigProvider);
  final repository = FoundationAuthRepository(
    config: config,
    fallbackAccessContext: config.supabaseEnabled
        ? AccessContext.anonymous()
        : AccessContext.preview(
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
    authRepository: ref.watch(adminAuthRepositoryProvider),
  ),
);

final adminAiReadingRepositoryProvider = Provider<AdminAiReadingRepository>(
  (ref) => FoundationAdminAiReadingRepository(
    config: ref.watch(adminAppConfigProvider),
    authRepository: ref.watch(adminAuthRepositoryProvider),
  ),
);

final adminUserManagementRepositoryProvider =
    Provider<AdminUserManagementRepository>(
      (ref) => FoundationAdminUserManagementRepository(
        _config: ref.watch(adminAppConfigProvider),
        authRepository: ref.watch(adminAuthRepositoryProvider),
      ),
    );

final adminSettingsRepositoryProvider = Provider<AdminSettingsRepository>(
  (ref) => FoundationAdminSettingsRepository(
    config: ref.watch(adminAppConfigProvider),
    authRepository: ref.watch(adminAuthRepositoryProvider),
  ),
);

final adminAnalyticsRepositoryProvider = Provider<AdminAnalyticsRepository>(
  (ref) => FoundationAdminAnalyticsRepository(
    config: ref.watch(adminAppConfigProvider),
    authRepository: ref.watch(adminAuthRepositoryProvider),
  ),
);

final adminUserAccessServiceProvider = Provider<AdminUserAccessService>(
  (ref) => AdminUserAccessService(config: ref.watch(adminAppConfigProvider)),
);

final adminSettingsStateProvider =
    StateNotifierProvider<AdminSettingsController, AdminSettingsState>(
      (ref) => AdminSettingsController(
        repository: ref.watch(adminSettingsRepositoryProvider),
      ),
    );

final adminAiAssistantControllerProvider =
    StateNotifierProvider<AdminAiAssistantController, AdminAiAssistantState>((
      ref,
    ) {
      return AdminAiAssistantController(
        aiRepository: ref.watch(adminAiReadingRepositoryProvider),
        contentRepository: ref.watch(adminContentRepositoryProvider),
      );
    });

final adminActiveSettingsProvider = Provider<AdminSettingsSnapshot>((ref) {
  return ref.watch(adminSettingsStateProvider).draft;
});

final adminAiCoverPoolStatusProvider = FutureProvider<AdminAiCoverPoolStatus>((
  ref,
) async {
  final repository = ref.watch(adminAiReadingRepositoryProvider);
  final result = await repository.fetchAiCoverPoolStatus();
  if (result case AppSuccess<AdminAiCoverPoolStatus>()) {
    return result.value;
  }
  throw Exception((result as AppFailure<AdminAiCoverPoolStatus>).message);
});

final adminDefaultListPageSizeProvider = Provider<int>((ref) {
  final size = ref
      .watch(adminActiveSettingsProvider)
      .dataManagement
      .defaultListPageSize;
  return size < 10 ? 10 : size;
});

final adminUserListQueryProvider =
    StateNotifierProvider<AdminUserListQueryController, AdminUserListQuery>(
      (ref) => AdminUserListQueryController(),
    );

final adminSelectedUserIdsProvider =
    StateNotifierProvider<AdminSelectedUsersController, Set<String>>(
      (ref) => AdminSelectedUsersController(),
    );

final adminUserListOverridesProvider =
    StateNotifierProvider<
      AdminUserListOverridesController,
      Map<String, AdminUserListItem>
    >((ref) => AdminUserListOverridesController());

final adminDeletedUserIdsProvider =
    StateNotifierProvider<AdminDeletedUsersController, Set<String>>(
      (ref) => AdminDeletedUsersController(),
    );

final adminUsersPageProvider = FutureProvider<AdminPage<AdminUserListItem>>((
  ref,
) async {
  final repository = ref.watch(adminUserManagementRepositoryProvider);
  final query = ref.watch(adminUserListQueryProvider);
  final overrides = ref.watch(adminUserListOverridesProvider);
  final deletedIds = ref.watch(adminDeletedUserIdsProvider);
  final result = await repository.listUsers(query);
  if (result case AppSuccess<AdminPage<AdminUserListItem>>()) {
    final page = result.value;
    final items = <AdminUserListItem>[
      for (final item in page.items)
        if (!deletedIds.contains(item.id)) overrides[item.id] ?? item,
    ];
    if (query.offset == 0) {
      for (final override in overrides.values) {
        final alreadyIncluded = items.any((item) => item.id == override.id);
        if (alreadyIncluded || !_matchesUserQuery(override, query)) {
          continue;
        }
        if (deletedIds.contains(override.id)) {
          continue;
        }
        items.insert(0, override);
      }
    }
    final removedOnPage = page.items
        .where((item) => deletedIds.contains(item.id))
        .length;
    final totalCount =
        (page.totalCount - removedOnPage) +
        _countInjectedUserOverrides(page.items, overrides, query) -
        overrides.values.where((item) => deletedIds.contains(item.id)).length;
    return AdminPage<AdminUserListItem>(
      items: items,
      totalCount: totalCount < 0 ? 0 : totalCount,
      offset: page.offset,
      limit: page.limit,
    );
  }
  throw Exception((result as AppFailure<AdminPage<AdminUserListItem>>).message);
});

final adminDashboardWindowProvider = StateProvider<int>((ref) => 7);

final adminDashboardSnapshotProvider = FutureProvider<AdminDashboardSnapshot>((
  ref,
) async {
  final repository = ref.watch(adminAnalyticsRepositoryProvider);
  final result = await repository.fetchDashboardSnapshot(
    days: ref.watch(adminDashboardWindowProvider),
  );
  if (result case AppSuccess<AdminDashboardSnapshot>()) {
    return result.value;
  }
  throw Exception((result as AppFailure<AdminDashboardSnapshot>).message);
});

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
  final merged = _mergeCollection(baseItems, changes, idOf: (item) => item.id)
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

final adminWordPageProvider =
    FutureProvider.family<AdminPage<AdminWordRecord>, AdminWordPageRequest>((
      ref,
      request,
    ) async {
      return _loadAdminWordPage(
        ref.watch(adminAppConfigProvider),
        request: request,
        previewRepository: ref.watch(_previewWordRepositoryProvider),
        changes: ref.watch(adminWordChangesProvider),
      );
    });

final adminReadingPageProvider =
    FutureProvider.family<
      AdminPage<AdminReadingRecord>,
      AdminReadingPageRequest
    >((ref, request) async {
      return _loadAdminReadingPage(
        ref.watch(adminAppConfigProvider),
        request: request,
        previewRepository: ref.watch(_previewReadingRepositoryProvider),
        changes: ref.watch(adminReadingChangesProvider),
      );
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

final adminAuditFeedProvider = FutureProvider<AdminAuditFeed>((ref) async {
  final local = ref.watch(adminAuditOverridesProvider);
  final config = ref.watch(adminAppConfigProvider);
  if (!config.supabaseEnabled) {
    return local.isNotEmpty
        ? AdminAuditFeed.ready(local)
        : const AdminAuditFeed.unavailable(
            'Supabase bağlantısı kapalı. Audit akışı preview modunda görüntülenemiyor.',
          );
  }

  await SupabaseBootstrap.initialize(config);
  if (Supabase.instance.client.auth.currentSession == null) {
    return local.isNotEmpty
        ? AdminAuditFeed.ready(local)
        : const AdminAuditFeed.unavailable(
            'Audit kayıtlarını görmek için admin oturumu açın.',
          );
  }

  try {
    final rows =
        (await Supabase.instance.client
                .from('audit_logs')
                .select('id,action,target_type,target_id,created_at')
                .order('created_at', ascending: false)
                .limit(8))
            as List<dynamic>;
    final remote = rows
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
    final records = <AdminAuditRecord>[...local, ...remote];
    if (records.isEmpty) {
      return const AdminAuditFeed.empty(
        'Henüz audit kaydı oluşmadı. İlk yönetim işlemi burada görünecek.',
      );
    }

    return AdminAuditFeed.ready(records);
  } catch (_) {
    return local.isNotEmpty
        ? AdminAuditFeed.ready(local)
        : const AdminAuditFeed.unavailable(
            'Audit kayıtları şu anda yüklenemiyor. Supabase erişimini ve yetkileri doğrulayın.',
          );
  }
});

final adminAuditLogProvider = FutureProvider<List<AdminAuditRecord>>((
  ref,
) async {
  final feed = await ref.watch(adminAuditFeedProvider.future);
  return feed.records;
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
  await ref.read(adminAuthStateProvider.notifier).restoreSession();
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
    if (Supabase.instance.client.auth.currentSession == null) {
      throw Exception('Admin oturumu bulunamadi.');
    }
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
              wordCount: (row['word_count'] as num?)?.toInt() ?? 0,
              isPublished: row['is_published'] as bool? ?? false,
              updatedAtLabel: _formatLastSeen(row['updated_at']),
              createdAtLabel: _formatLastSeen(row['created_at']),
              updatedByLabel: row['updated_by_email']?.toString(),
            ),
          )
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
    } catch (error) {
      throw Exception('Paket listesi yuklenemedi: $error');
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
          createdAtLabel: 'preview',
          updatedByLabel: 'preview',
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
    if (Supabase.instance.client.auth.currentSession == null) {
      throw Exception('Admin oturumu bulunamadi.');
    }
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
              createdAtLabel: _formatLastSeen(row['created_at']),
              updatedByLabel: row['updated_by_email']?.toString(),
            ),
          )
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
    } catch (error) {
      throw Exception('Kelime listesi yuklenemedi: $error');
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
          createdAtLabel: 'preview',
          updatedByLabel: 'preview',
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
    if (Supabase.instance.client.auth.currentSession == null) {
      throw Exception('Admin oturumu bulunamadi.');
    }
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
              isPro: row['is_pro'] as bool? ?? false,
              isPublished: row['is_published'] as bool? ?? false,
              linkedWordCount: (row['linked_word_count'] as num?)?.toInt() ?? 0,
              questionCount: (row['question_count'] as num?)?.toInt() ?? 0,
              hasCover: row['has_cover'] as bool? ?? false,
              linkedWordsPreview: _coerceStringList(
                row['linked_words_preview'],
              ),
              updatedAtLabel: _formatLastSeen(row['updated_at']),
              createdAtLabel: _formatLastSeen(row['created_at']),
              updatedByLabel: row['updated_by_email']?.toString(),
            ),
          )
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
    } catch (error) {
      throw Exception('Okuma listesi yuklenemedi: $error');
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
          isPro: item.isPro,
          isPublished: true,
          linkedWordCount: 0,
          questionCount: item.questionCount,
          hasCover:
              (item.coverUrl?.trim().isNotEmpty ?? false) ||
              ((item.coverBucketName?.trim().isNotEmpty ?? false) &&
                  (item.coverStoragePath?.trim().isNotEmpty ?? false)),
          linkedWordsPreview: const <String>[],
          updatedAtLabel: 'preview',
          createdAtLabel: 'preview',
          updatedByLabel: 'preview',
        ),
      )
      .toList(growable: false);
}

Future<AdminPage<AdminWordRecord>> _loadAdminWordPage(
  AppConfig config, {
  required AdminWordPageRequest request,
  required WordRepository previewRepository,
  required AdminCollectionState<AdminWordRecord> changes,
}) async {
  if (config.supabaseEnabled) {
    await SupabaseBootstrap.initialize(config);
    if (Supabase.instance.client.auth.currentSession == null) {
      throw Exception('Admin oturumu bulunamadi.');
    }
    try {
      final response = await Supabase.instance.client.rpc<dynamic>(
        'admin_list_words_paged',
        params: <String, dynamic>{
          'p_pack_id': request.packId,
          'p_query': request.query.isEmpty ? null : request.query,
          'p_status': _statusFilterValue(request.isPublished),
          'p_offset': request.offset,
          'p_limit': request.limit,
        },
      );
      final payload = _coerceMap(response);
      return AdminPage<AdminWordRecord>(
        items: _coerceList(payload['items'])
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
                createdAtLabel: _formatLastSeen(row['created_at']),
                updatedByLabel: row['updated_by_email']?.toString(),
              ),
            )
            .where((item) => item.id.isNotEmpty)
            .toList(growable: false),
        totalCount: (payload['total_count'] as num?)?.toInt() ?? 0,
        offset: (payload['offset'] as num?)?.toInt() ?? request.offset,
        limit: (payload['limit'] as num?)?.toInt() ?? request.limit,
      );
    } catch (error) {
      throw Exception('Kelime sayfasi yuklenemedi: $error');
    }
  }

  final previewWords = await previewRepository.fetchWords();
  final baseItems = previewWords
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
          createdAtLabel: 'preview',
          updatedByLabel: 'preview',
        ),
      )
      .toList(growable: false);
  final merged =
      _mergeCollection(baseItems, changes, idOf: (item) => item.id)
          .where(
            (item) => request.packId == null || item.packId == request.packId,
          )
          .where((item) {
            if (request.isPublished == null) {
              return true;
            }
            return item.isPublished == request.isPublished;
          })
          .where((item) {
            if (request.query.isEmpty) {
              return true;
            }
            final haystack =
                '${item.enWord} ${item.trMeaning} ${item.pos} ${item.level ?? ''}'
                    .toLowerCase();
            return haystack.contains(request.query.toLowerCase());
          })
          .toList(growable: false)
        ..sort((left, right) => left.enWord.compareTo(right.enWord));
  return _slicePage(merged, offset: request.offset, limit: request.limit);
}

Future<AdminPage<AdminReadingRecord>> _loadAdminReadingPage(
  AppConfig config, {
  required AdminReadingPageRequest request,
  required ReadingRepository previewRepository,
  required AdminCollectionState<AdminReadingRecord> changes,
}) async {
  if (config.supabaseEnabled) {
    await SupabaseBootstrap.initialize(config);
    if (Supabase.instance.client.auth.currentSession == null) {
      throw Exception('Admin oturumu bulunamadi.');
    }
    try {
      final response = await Supabase.instance.client.rpc<dynamic>(
        'admin_list_reading_passages_paged',
        params: <String, dynamic>{
          'p_query': request.query.isEmpty ? null : request.query,
          'p_level': request.level,
          'p_status': _statusFilterValue(request.isPublished),
          'p_has_questions': request.hasQuestions,
          'p_has_cover': request.hasCover,
          'p_offset': request.offset,
          'p_limit': request.limit,
        },
      );
      final payload = _coerceMap(response);
      return AdminPage<AdminReadingRecord>(
        items: _coerceList(payload['items'])
            .map(
              (row) => AdminReadingRecord(
                id: row['id']?.toString() ?? '',
                packId: row['pack_id']?.toString(),
                packName: row['pack_name']?.toString(),
                title: row['title']?.toString() ?? '',
                level: row['level']?.toString(),
                category: row['category']?.toString(),
                tagsRaw: row['tags_raw']?.toString(),
                isPro: row['is_pro'] as bool? ?? false,
                isPublished: row['is_published'] as bool? ?? false,
                linkedWordCount:
                    (row['linked_word_count'] as num?)?.toInt() ?? 0,
                questionCount: (row['question_count'] as num?)?.toInt() ?? 0,
                hasCover: row['has_cover'] as bool? ?? false,
                linkedWordsPreview: _coerceStringList(
                  row['linked_words_preview'],
                ),
                updatedAtLabel: _formatLastSeen(row['updated_at']),
                createdAtLabel: _formatLastSeen(row['created_at']),
                updatedByLabel: row['updated_by_email']?.toString(),
              ),
            )
            .where((item) => item.id.isNotEmpty)
            .toList(growable: false),
        totalCount: (payload['total_count'] as num?)?.toInt() ?? 0,
        offset: (payload['offset'] as num?)?.toInt() ?? request.offset,
        limit: (payload['limit'] as num?)?.toInt() ?? request.limit,
      );
    } catch (error) {
      throw Exception('Okuma sayfasi yuklenemedi: $error');
    }
  }

  final previewReadings = await previewRepository.fetchReadings();
  final baseItems = previewReadings
      .map(
        (item) => AdminReadingRecord(
          id: item.id,
          packId: null,
          packName: null,
          title: item.title,
          level: item.level,
          category: item.category,
          tagsRaw: null,
          isPro: item.isPro,
          isPublished: true,
          linkedWordCount: 0,
          questionCount: item.questionCount,
          hasCover:
              (item.coverUrl?.trim().isNotEmpty ?? false) ||
              ((item.coverBucketName?.trim().isNotEmpty ?? false) &&
                  (item.coverStoragePath?.trim().isNotEmpty ?? false)),
          linkedWordsPreview: const <String>[],
          updatedAtLabel: 'preview',
          createdAtLabel: 'preview',
          updatedByLabel: 'preview',
        ),
      )
      .toList(growable: false);
  final merged =
      _mergeCollection(baseItems, changes, idOf: (item) => item.id)
          .where((item) => request.level == null || item.level == request.level)
          .where((item) {
            if (request.isPublished == null) {
              return true;
            }
            return item.isPublished == request.isPublished;
          })
          .where((item) {
            if (request.hasQuestions == null) {
              return true;
            }
            return request.hasQuestions!
                ? item.questionCount > 0
                : item.questionCount == 0;
          })
          .where((item) {
            if (request.hasCover == null) {
              return true;
            }
            return item.hasCover == request.hasCover;
          })
          .where((item) {
            if (request.query.isEmpty) {
              return true;
            }
            final haystack =
                '${item.title} ${item.category ?? ''} ${item.level ?? ''} ${item.tagsRaw ?? ''}'
                    .toLowerCase();
            return haystack.contains(request.query.toLowerCase());
          })
          .toList(growable: false)
        ..sort((left, right) => left.title.compareTo(right.title));
  return _slicePage(merged, offset: request.offset, limit: request.limit);
}

Future<List<AdminGrammarRecord>> _loadAdminGrammarModules(
  AppConfig config, {
  required GrammarRepository previewRepository,
}) async {
  if (config.supabaseEnabled) {
    await SupabaseBootstrap.initialize(config);
    if (Supabase.instance.client.auth.currentSession == null) {
      throw Exception('Admin oturumu bulunamadi.');
    }
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
    } catch (error) {
      throw Exception('Gramer listesi yuklenemedi: $error');
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
          createdAtLabel: 'preview',
          updatedByLabel: 'preview',
        ),
      )
      .toList(growable: false);
}

AdminPage<T> _slicePage<T>(
  List<T> items, {
  required int offset,
  required int limit,
}) {
  final safeOffset = offset.clamp(0, items.length);
  final end = (safeOffset + limit).clamp(0, items.length);
  return AdminPage<T>(
    items: items.sublist(safeOffset, end),
    totalCount: items.length,
    offset: offset,
    limit: limit,
  );
}

Map<String, dynamic> _coerceMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _coerceList(dynamic value) {
  if (value is List<dynamic>) {
    return value
        .whereType<Map>()
        .map(
          (item) => item.map((key, value) => MapEntry(key.toString(), value)),
        )
        .toList(growable: false);
  }
  return const <Map<String, dynamic>>[];
}

List<String> _coerceStringList(dynamic value) {
  if (value is List<dynamic>) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return const <String>[];
}

String? _statusFilterValue(bool? isPublished) {
  if (isPublished == null) {
    return null;
  }
  return isPublished ? 'published' : 'draft';
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

bool _matchesUserQuery(AdminUserListItem item, AdminUserListQuery query) {
  final loweredQuery = query.query.toLowerCase();
  final matchesQuery =
      loweredQuery.isEmpty ||
      item.email.toLowerCase().contains(loweredQuery) ||
      item.displayName.toLowerCase().contains(loweredQuery);
  final matchesRole = query.role == null || item.role == query.role;
  final matchesPlan = query.plan == null || item.plan == query.plan;
  final matchesStatus =
      query.status == null ||
      query.status == AdminUserStatusFilter.all ||
      item.statusLabel == query.status!.value;
  return matchesQuery && matchesRole && matchesPlan && matchesStatus;
}

int _countInjectedUserOverrides(
  List<AdminUserListItem> baseItems,
  Map<String, AdminUserListItem> overrides,
  AdminUserListQuery query,
) {
  final baseIds = baseItems.map((item) => item.id).toSet();
  var count = 0;
  for (final item in overrides.values) {
    if (!baseIds.contains(item.id) && _matchesUserQuery(item, query)) {
      count += 1;
    }
  }
  return count;
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
