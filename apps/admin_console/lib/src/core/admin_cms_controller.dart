import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_data/shared_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_console_models.dart';

class AdminCollectionState<T> {
  AdminCollectionState({Map<String, T>? upserts, Set<String>? deletedIds})
    : upserts = upserts ?? <String, T>{},
      deletedIds = deletedIds ?? <String>{};

  final Map<String, T> upserts;
  final Set<String> deletedIds;

  AdminCollectionState<T> copyWith({
    Map<String, T>? upserts,
    Set<String>? deletedIds,
  }) {
    return AdminCollectionState<T>(
      upserts: upserts ?? this.upserts,
      deletedIds: deletedIds ?? this.deletedIds,
    );
  }
}

class AdminCollectionController<T>
    extends StateNotifier<AdminCollectionState<T>> {
  AdminCollectionController({required String Function(T item) idOf})
    : _idOf = idOf,
      super(AdminCollectionState<T>());

  final String Function(T item) _idOf;

  void upsert(T item) {
    final id = _idOf(item);
    final nextUpserts = <String, T>{...state.upserts, id: item};
    final nextDeleted = Set<String>.from(state.deletedIds)..remove(id);
    state = state.copyWith(upserts: nextUpserts, deletedIds: nextDeleted);
  }

  void remove(String id) {
    final nextUpserts = <String, T>{...state.upserts}..remove(id);
    final nextDeleted = Set<String>.from(state.deletedIds)..add(id);
    state = state.copyWith(upserts: nextUpserts, deletedIds: nextDeleted);
  }

  void clear() {
    state = AdminCollectionState<T>();
  }
}

class AdminUserOverridesController
    extends StateNotifier<Map<String, AdminUserRecord>> {
  AdminUserOverridesController() : super(const <String, AdminUserRecord>{});

  void updateUser(AdminUserRecord user) {
    state = <String, AdminUserRecord>{...state, user.id: user};
  }
}

class AdminPublishOverridesController extends StateNotifier<Map<String, bool>> {
  AdminPublishOverridesController() : super(const <String, bool>{});

  void setPublished({
    required String entityType,
    required String entityId,
    required bool isPublished,
  }) {
    state = <String, bool>{...state, '$entityType::$entityId': isPublished};
  }

  bool? publishedFor({required String entityType, required String entityId}) {
    return state['$entityType::$entityId'];
  }
}

class AdminAuditLogController extends StateNotifier<List<AdminAuditRecord>> {
  AdminAuditLogController() : super(const <AdminAuditRecord>[]);

  void push(AdminAuditRecord record) {
    state = <AdminAuditRecord>[record, ...state];
  }
}

String formatRoleLabel(AppRole role) => switch (role) {
  AppRole.user => 'user',
  AppRole.admin => 'admin',
  AppRole.superAdmin => 'super_admin',
  AppRole.developer => 'developer',
};

class AdminUserAccessService {
  const AdminUserAccessService({required AppConfig config}) : _config = config;

  final AppConfig _config;

  Future<AppResult<void>> setUserAccess({
    required String userId,
    required AppRole role,
    required EntitlementPlan plan,
  }) async {
    if (!_config.supabaseEnabled) {
      return const AppSuccess<void>(null);
    }

    try {
      await SupabaseBootstrap.initialize(_config);
      await Supabase.instance.client.rpc<void>(
        'admin_set_user_access',
        params: <String, dynamic>{
          'p_user_id': userId,
          'p_role': role.value,
          'p_plan': plan.value,
        },
      );
      return const AppSuccess<void>(null);
    } catch (error) {
      return AppFailure<void>('Kullanici erisimi guncellenemedi: $error');
    }
  }
}
