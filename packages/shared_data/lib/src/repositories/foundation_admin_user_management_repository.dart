import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bootstrap/supabase_bootstrap.dart';

class AdminUserManagementFunctionResponse {
  const AdminUserManagementFunctionResponse({
    required this.status,
    required this.data,
  });

  final int status;
  final Object? data;
}

class FoundationAdminUserManagementRepository
    implements AdminUserManagementRepository {
  const FoundationAdminUserManagementRepository({
    required AppConfig config,
    Future<AdminUserManagementFunctionResponse> Function(
      Map<String, dynamic> body,
    )?
    manageUsersInvoker,
  }) : _config = config,
       _manageUsersInvoker = manageUsersInvoker;

  final AppConfig _config;
  final Future<AdminUserManagementFunctionResponse> Function(
    Map<String, dynamic> body,
  )?
  _manageUsersInvoker;

  @override
  Future<AppResult<AdminPage<AdminUserListItem>>> listUsers(
    AdminUserListQuery query,
  ) async {
    if (!_config.supabaseEnabled) {
      final items = _previewUsers
          .where((item) {
            final matchesQuery =
                query.query.isEmpty ||
                item.email.toLowerCase().contains(query.query.toLowerCase()) ||
                item.displayName.toLowerCase().contains(
                  query.query.toLowerCase(),
                );
            final matchesRole = query.role == null || item.role == query.role;
            final matchesPlan = query.plan == null || item.plan == query.plan;
            final matchesStatus =
                query.status == null || item.statusLabel == query.status!.value;
            return matchesQuery && matchesRole && matchesPlan && matchesStatus;
          })
          .toList(growable: false);
      final start = query.offset.clamp(0, items.length);
      final end = (start + query.limit).clamp(0, items.length);
      return AppSuccess<AdminPage<AdminUserListItem>>(
        AdminPage<AdminUserListItem>(
          items: items.sublist(start, end),
          totalCount: items.length,
          offset: query.offset,
          limit: query.limit,
        ),
      );
    }

    try {
      await SupabaseBootstrap.initialize(_config);
      final response = await Supabase.instance.client.rpc<dynamic>(
        'admin_list_users_paged',
        params: <String, dynamic>{
          'p_query': query.query.trim().isEmpty ? null : query.query.trim(),
          'p_role': query.role?.value,
          'p_plan': query.plan?.value,
          'p_status': query.status?.value,
          'p_offset': query.offset,
          'p_limit': query.limit,
        },
      );
      final payload = _asMap(response);
      final items = _asList(
        payload['items'],
      ).map(_toUserListItem).toList(growable: false);
      return AppSuccess<AdminPage<AdminUserListItem>>(
        AdminPage<AdminUserListItem>(
          items: items,
          totalCount: _toInt(payload['total_count']),
          offset: _toInt(payload['offset'], fallback: query.offset),
          limit: _toInt(payload['limit'], fallback: query.limit),
        ),
      );
    } catch (error) {
      return AppFailure<AdminPage<AdminUserListItem>>(
        'Kullanici listesi yuklenemedi: $error',
      );
    }
  }

  @override
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

  @override
  Future<AppResult<void>> bulkSetUserAccess(AdminBulkUserUpdate update) async {
    if (update.userIds.isEmpty) {
      return const AppFailure<void>('En az bir kullanici secilmeli.');
    }
    if (update.role == null && update.plan == null) {
      return const AppFailure<void>('Toplu islem icin rol veya plan gerekli.');
    }
    if (!_config.supabaseEnabled) {
      return const AppSuccess<void>(null);
    }

    try {
      await SupabaseBootstrap.initialize(_config);
      await Supabase.instance.client.rpc<void>(
        'admin_bulk_set_user_access',
        params: <String, dynamic>{
          'p_user_ids': update.userIds,
          'p_role': update.role?.value,
          'p_plan': update.plan?.value,
        },
      );
      return const AppSuccess<void>(null);
    } catch (error) {
      return AppFailure<void>('Toplu kullanici guncellemesi basarisiz: $error');
    }
  }

  @override
  Future<AppResult<AdminUserListItem>> updateUser(
    AdminUserUpdateRequest request,
  ) async {
    if (!_config.supabaseEnabled) {
      return AppSuccess<AdminUserListItem>(
        AdminUserListItem(
          id: request.userId,
          email: request.email,
          displayName: request.displayName,
          role: request.role,
          plan: request.plan,
          statusLabel: request.role == AppRole.user ? 'active' : 'staff',
          lastSeenAt: null,
          updatedAt: DateTime.now(),
        ),
      );
    }

    try {
      await SupabaseBootstrap.initialize(_config);
      final response = await Supabase.instance.client.functions.invoke(
        'admin_manage_users',
        method: HttpMethod.post,
        body: <String, dynamic>{'action': 'update', ...request.toJson()},
      );
      final payload = _asMap(response.data);
      if (response.status >= 400) {
        return AppFailure<AdminUserListItem>(
          payload['message']?.toString() ?? 'Kullanici guncellenemedi.',
        );
      }

      final user = _asMap(payload['user']);
      return AppSuccess<AdminUserListItem>(
        AdminUserListItem(
          id: user['user_id']?.toString() ?? request.userId,
          email: user['email']?.toString() ?? request.email,
          displayName: user['display_name']?.toString() ?? request.displayName,
          role: _parseRole(user['app_role']?.toString() ?? request.role.value),
          plan: _parsePlan(user['plan']?.toString() ?? request.plan.value),
          statusLabel: user['status_label']?.toString() ?? 'active',
          lastSeenAt: _parseDateTime(user['last_seen_at']),
          updatedAt: _parseDateTime(user['updated_at']) ?? DateTime.now(),
        ),
      );
    } catch (error) {
      return AppFailure<AdminUserListItem>('Kullanici guncellenemedi: $error');
    }
  }

  @override
  Future<AppResult<void>> deleteUser({required String userId}) async {
    if (!_config.supabaseEnabled) {
      return const AppSuccess<void>(null);
    }

    try {
      final response = await _invokeManageUsers(<String, dynamic>{
        'action': 'delete',
        'user_id': userId,
      });
      final payload = _asMap(response.data);
      if (response.status >= 400) {
        return AppFailure<void>(
          payload['message']?.toString() ?? 'Kullanici silinemedi.',
        );
      }
      return const AppSuccess<void>(null);
    } catch (error) {
      return AppFailure<void>('Kullanici silinemedi: $error');
    }
  }

  @override
  Future<AppResult<AdminBulkUserDeleteResult>> bulkDeleteUsers({
    required List<String> userIds,
  }) async {
    if (userIds.isEmpty) {
      return const AppFailure<AdminBulkUserDeleteResult>(
        'En az bir kullanici secilmeli.',
      );
    }

    if (!_config.supabaseEnabled) {
      return AppSuccess<AdminBulkUserDeleteResult>(
        AdminBulkUserDeleteResult(
          requestedCount: userIds.length,
          deletedCount: userIds.length,
          skippedCount: 0,
          failedCount: 0,
          results: userIds
              .map(
                (userId) => AdminBulkUserDeleteItemResult(
                  userId: userId,
                  status: AdminBulkUserDeleteItemStatus.deleted,
                ),
              )
              .toList(growable: false),
        ),
      );
    }

    try {
      final response = await _invokeManageUsers(<String, dynamic>{
        'action': 'delete_many',
        'user_ids': userIds,
      });
      final payload = _asMap(response.data);
      if (response.status >= 400) {
        return AppFailure<AdminBulkUserDeleteResult>(
          payload['message']?.toString() ?? 'Toplu kullanici silme basarisiz.',
        );
      }
      return AppSuccess<AdminBulkUserDeleteResult>(
        AdminBulkUserDeleteResult.fromJson(payload),
      );
    } catch (error) {
      return AppFailure<AdminBulkUserDeleteResult>(
        'Toplu kullanici silme basarisiz: $error',
      );
    }
  }

  @override
  Future<AppResult<AdminInviteResult>> inviteUser(
    AdminInviteRequest request,
  ) async {
    return _submitInvite(request, retryCount: 0);
  }

  @override
  Future<AppResult<AdminInviteResult>> retryInvite(
    AdminInviteRequest request,
  ) async {
    return _submitInvite(request, retryCount: 1);
  }

  Future<AppResult<AdminInviteResult>> _submitInvite(
    AdminInviteRequest request, {
    required int retryCount,
  }) async {
    if (!_config.supabaseEnabled) {
      return AppSuccess<AdminInviteResult>(
        AdminInviteResult(
          accepted: true,
          email: request.email,
          role: request.role,
          plan: request.plan,
          invitedUserId: 'preview-invite',
          retryCount: retryCount,
        ),
      );
    }

    try {
      await SupabaseBootstrap.initialize(_config);
      final response = await Supabase.instance.client.functions.invoke(
        'admin_invite_users',
        method: HttpMethod.post,
        body: <String, dynamic>{
          'invites': <Map<String, dynamic>>[
            <String, dynamic>{
              'email': request.email,
              'role': request.role.value,
              'plan': request.plan.value,
              'invite_expiry_hours': request.inviteExpiryHours,
              'retry_count': retryCount,
            },
          ],
        },
      );

      final payload = _asMap(response.data);
      final results = _asList(payload['results']);
      if (response.status >= 400 || results.isEmpty) {
        final failedResult = AdminInviteResult(
          accepted: false,
          email: request.email,
          role: request.role,
          plan: request.plan,
          errorCode: payload['error']?.toString(),
          errorMessage:
              payload['message']?.toString() ?? 'Davet sonucu alinamadi.',
          retryCount: retryCount,
        );
        return AppSuccess<AdminInviteResult>(failedResult);
      }

      final firstResult = _asMap(results.first);
      final parsed = AdminInviteResult.fromJson(<String, dynamic>{
        'accepted': firstResult['accepted'] ?? true,
        'email': firstResult['email'] ?? request.email,
        'role': firstResult['role'] ?? request.role.value,
        'plan': firstResult['plan'] ?? request.plan.value,
        'invited_user_id':
            firstResult['invited_user_id'] ?? firstResult['user_id'],
        'error_code': firstResult['error_code'],
        'error_message': firstResult['error_message'],
        'retry_count': retryCount,
      });
      return AppSuccess<AdminInviteResult>(parsed);
    } catch (error) {
      return AppFailure<AdminInviteResult>('Davet gonderilemedi: $error');
    }
  }

  AdminUserListItem _toUserListItem(Map<String, dynamic> json) {
    return AdminUserListItem(
      id: json['user_id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      role: _parseRole(json['app_role']?.toString()),
      plan: _parsePlan(json['plan']?.toString()),
      statusLabel: json['status_label']?.toString() ?? 'active',
      lastSeenAt: _parseDateTime(json['last_seen_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Future<AdminUserManagementFunctionResponse> _invokeManageUsers(
    Map<String, dynamic> body,
  ) async {
    if (_manageUsersInvoker != null) {
      return _manageUsersInvoker(body);
    }

    await SupabaseBootstrap.initialize(_config);
    final response = await Supabase.instance.client.functions.invoke(
      'admin_manage_users',
      method: HttpMethod.post,
      body: body,
    );
    return AdminUserManagementFunctionResponse(
      status: response.status,
      data: response.data,
    );
  }
}

final List<AdminUserListItem> _previewUsers = <AdminUserListItem>[
  AdminUserListItem(
    id: 'preview-admin',
    email: 'phase1.admin@passagetr.dev',
    displayName: 'Phase Admin',
    role: AppRole.admin,
    plan: EntitlementPlan.pro,
    statusLabel: 'active',
    lastSeenAt: DateTime.utc(2026, 3, 10, 9),
    updatedAt: DateTime.utc(2026, 3, 10, 9),
  ),
  AdminUserListItem(
    id: 'preview-user',
    email: 'preview.user@passagetr.dev',
    displayName: 'Preview User',
    role: AppRole.user,
    plan: EntitlementPlan.free,
    statusLabel: 'active',
    lastSeenAt: DateTime.utc(2026, 3, 8, 13),
    updatedAt: DateTime.utc(2026, 3, 8, 13),
  ),
  AdminUserListItem(
    id: 'preview-dev',
    email: 'preview.dev@passagetr.dev',
    displayName: 'Preview Developer',
    role: AppRole.developer,
    plan: EntitlementPlan.pro,
    statusLabel: 'staff',
    lastSeenAt: DateTime.utc(2026, 3, 11, 7),
    updatedAt: DateTime.utc(2026, 3, 11, 7),
  ),
];

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _asList(dynamic value) {
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

int _toInt(Object? value, {int fallback = 0}) {
  return switch (value) {
    int() => value,
    num() => value.toInt(),
    String() => int.tryParse(value) ?? fallback,
    _ => fallback,
  };
}

DateTime? _parseDateTime(Object? value) {
  final raw = value?.toString();
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw)?.toLocal();
}

AppRole _parseRole(String? value) {
  for (final item in AppRole.values) {
    if (item.value == value) {
      return item;
    }
  }
  return AppRole.user;
}

EntitlementPlan _parsePlan(String? value) {
  for (final item in EntitlementPlan.values) {
    if (item.value == value) {
      return item;
    }
  }
  return EntitlementPlan.free;
}
