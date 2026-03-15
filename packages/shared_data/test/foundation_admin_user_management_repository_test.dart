import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_data/shared_data.dart';
import 'package:shared_domain/shared_domain.dart';

void main() {
  const config = AppConfig(
    appName: 'PASSAGETR',
    environment: AppEnvironment.dev,
    platformMode: PlatformMode.web,
    supabaseUrl: 'https://example.supabase.co',
    supabaseAnonKey: 'anon-key',
    adminConsoleUrl: '',
    adminPreviewEnabled: true,
  );

  test('bulkDeleteUsers maps successful response payload', () async {
    final repository = FoundationAdminUserManagementRepository(
      config: config,
      manageUsersInvoker: (_) async =>
          const AdminUserManagementFunctionResponse(
            status: 200,
            data: <String, dynamic>{
              'requested_count': 3,
              'deleted_count': 2,
              'skipped_count': 1,
              'failed_count': 0,
              'results': [
                {'user_id': 'user-1', 'status': 'deleted'},
                {'user_id': 'user-2', 'status': 'deleted'},
                {
                  'user_id': 'user-3',
                  'status': 'skipped',
                  'message': 'You cannot delete the active admin session.',
                },
              ],
            },
          ),
    );

    final result = await repository.bulkDeleteUsers(
      userIds: const ['user-1', 'user-2', 'user-3'],
    );

    expect(result, isA<AppSuccess<AdminBulkUserDeleteResult>>());
    final value = (result as AppSuccess<AdminBulkUserDeleteResult>).value;
    expect(value.deletedCount, 2);
    expect(value.skippedCount, 1);
    expect(value.deletedUserIds, ['user-1', 'user-2']);
    expect(value.results.last.message, contains('active admin session'));
  });

  test('bulkDeleteUsers returns failure for empty selection', () async {
    final repository = FoundationAdminUserManagementRepository(config: config);

    final result = await repository.bulkDeleteUsers(userIds: const []);

    expect(result, isA<AppFailure<AdminBulkUserDeleteResult>>());
    expect(
      (result as AppFailure<AdminBulkUserDeleteResult>).message,
      'En az bir kullanici secilmeli.',
    );
  });

  test('bulkDeleteUsers surfaces function failure message', () async {
    final repository = FoundationAdminUserManagementRepository(
      config: config,
      manageUsersInvoker: (_) async =>
          const AdminUserManagementFunctionResponse(
            status: 400,
            data: <String, dynamic>{'message': 'Toplu silme desteklenmiyor.'},
          ),
    );

    final result = await repository.bulkDeleteUsers(userIds: const ['user-1']);

    expect(result, isA<AppFailure<AdminBulkUserDeleteResult>>());
    expect(
      (result as AppFailure<AdminBulkUserDeleteResult>).message,
      'Toplu silme desteklenmiyor.',
    );
  });
}
