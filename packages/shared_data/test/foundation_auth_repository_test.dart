import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_data/shared_data.dart';

void main() {
  group('FoundationAuthRepository', () {
    test(
      'restoreSession returns fallback context when Supabase is disabled',
      () async {
        final repository = FoundationAuthRepository(
          config: const AppConfig(
            appName: 'PASSAGETR Test',
            environment: AppEnvironment.dev,
            platformMode: PlatformMode.mobile,
            supabaseUrl: '',
            supabaseAnonKey: '',
            adminConsoleUrl: '',
            adminPreviewEnabled: false,
          ),
          fallbackAccessContext: AccessContext.preview(
            role: AppRole.user,
            plan: EntitlementPlan.free,
            isAnonymous: true,
          ),
        );

        final session = await repository.restoreSession();

        expect(session.isAnonymous, isTrue);
        expect(session.claims['app_role'], 'user');
        expect(session.claims['plan'], 'free');
        repository.dispose();
      },
    );

    test(
      'signInAnonymously uses preview fallback when Supabase is disabled',
      () async {
        final repository = FoundationAuthRepository(
          config: const AppConfig(
            appName: 'PASSAGETR Test',
            environment: AppEnvironment.dev,
            platformMode: PlatformMode.mobile,
            supabaseUrl: '',
            supabaseAnonKey: '',
            adminConsoleUrl: '',
            adminPreviewEnabled: false,
          ),
          fallbackAccessContext: AccessContext.anonymous(),
        );

        final result = await repository.signInAnonymously();

        expect(result, isA<AppSuccess<AuthSession>>());
        final session = (result as AppSuccess<AuthSession>).value;
        expect(session.isAnonymous, isTrue);
        expect(session.claims['app_role'], 'user');
        repository.dispose();
      },
    );

    test(
      'refreshSession preserves current preview context when Supabase is disabled',
      () async {
        final repository = FoundationAuthRepository(
          config: const AppConfig(
            appName: 'PASSAGETR Test',
            environment: AppEnvironment.dev,
            platformMode: PlatformMode.mobile,
            supabaseUrl: '',
            supabaseAnonKey: '',
            adminConsoleUrl: '',
            adminPreviewEnabled: false,
          ),
          fallbackAccessContext: AccessContext.preview(
            role: AppRole.admin,
            plan: EntitlementPlan.pro,
            isAnonymous: false,
          ),
        );

        await repository.restoreSession();
        final result = await repository.refreshSession();

        expect(result, isA<AppSuccess<AuthSession>>());
        final session = (result as AppSuccess<AuthSession>).value;
        expect(session.isAuthenticated, isTrue);
        expect(session.claims['app_role'], 'admin');
        expect(session.claims['plan'], 'pro');
        repository.dispose();
      },
    );
  });
}
