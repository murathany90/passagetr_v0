import '../auth/app_role.dart';
import '../auth/auth_session.dart';
import '../auth/auth_user.dart';
import '../auth/entitlement_plan.dart';

class AccessContext {
  const AccessContext({
    required this.session,
    required this.role,
    required this.plan,
  });

  final AuthSession session;
  final AppRole role;
  final EntitlementPlan plan;

  bool get isAnonymous => session.user?.isAnonymous ?? true;
  bool get isAuthenticated => session.isAuthenticated;
  String? get userId => session.user?.id;
  String? get email => session.user?.email;
  bool get canAccessAdmin => role == AppRole.admin || role == AppRole.developer;
  bool get canManageRoles => role == AppRole.developer;
  bool get canViewPremium =>
      plan == EntitlementPlan.pro ||
      role == AppRole.admin ||
      role == AppRole.developer;

  factory AccessContext.anonymous({
    EntitlementPlan plan = EntitlementPlan.free,
  }) {
    return AccessContext(
      session: AuthSession.anonymous(
        claims: <String, String>{'app_role': 'user', 'plan': plan.value},
      ),
      role: AppRole.user,
      plan: plan,
    );
  }

  factory AccessContext.preview({
    required AppRole role,
    required EntitlementPlan plan,
    required bool isAnonymous,
  }) {
    return AccessContext(
      session: AuthSession(
        user: isAnonymous
            ? const AuthUser(
                id: 'preview-anonymous',
                email: null,
                isAnonymous: true,
              )
            : AuthUser(
                id: 'preview-${role.value}',
                email: '${role.value}@passagetr.dev',
                isAnonymous: false,
              ),
        claims: <String, String>{'app_role': role.value, 'plan': plan.value},
      ),
      role: role,
      plan: plan,
    );
  }

  factory AccessContext.fromSession(AuthSession session) {
    final role = AppRole.values.firstWhere(
      (item) => item.value == session.claims['app_role'],
      orElse: () => AppRole.user,
    );
    final plan = EntitlementPlan.values.firstWhere(
      (item) => item.value == session.claims['plan'],
      orElse: () => EntitlementPlan.free,
    );

    return AccessContext(session: session, role: role, plan: plan);
  }
}
