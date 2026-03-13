import 'package:shared_core/shared_core.dart';

import '../entities/admin_console_contracts.dart';

abstract interface class AdminUserManagementRepository {
  Future<AppResult<AdminPage<AdminUserListItem>>> listUsers(
    AdminUserListQuery query,
  );

  Future<AppResult<void>> setUserAccess({
    required String userId,
    required AppRole role,
    required EntitlementPlan plan,
  });

  Future<AppResult<void>> bulkSetUserAccess(AdminBulkUserUpdate update);

  Future<AppResult<AdminUserListItem>> updateUser(
    AdminUserUpdateRequest request,
  );

  Future<AppResult<void>> deleteUser({required String userId});

  Future<AppResult<AdminInviteResult>> inviteUser(AdminInviteRequest request);

  Future<AppResult<AdminInviteResult>> retryInvite(AdminInviteRequest request);
}
