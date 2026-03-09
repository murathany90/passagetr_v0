import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';

void main() {
  group('AccessContext', () {
    test('derives role and plan from auth session claims', () {
      const session = AuthSession(
        user: AuthUser(
          id: 'user-1',
          email: 'admin@passagetr.dev',
          isAnonymous: false,
          displayName: 'Admin User',
        ),
        claims: <String, String>{'app_role': 'admin', 'plan': 'pro'},
      );

      final context = AccessContext.fromSession(session);

      expect(context.role, AppRole.admin);
      expect(context.plan, EntitlementPlan.pro);
      expect(context.canAccessAdmin, isTrue);
      expect(context.canViewPremium, isTrue);
      expect(context.email, 'admin@passagetr.dev');
    });

    test('anonymous factory uses user/free defaults', () {
      final context = AccessContext.anonymous();

      expect(context.role, AppRole.user);
      expect(context.plan, EntitlementPlan.free);
      expect(context.isAnonymous, isTrue);
      expect(context.isAuthenticated, isFalse);
    });
  });
}
