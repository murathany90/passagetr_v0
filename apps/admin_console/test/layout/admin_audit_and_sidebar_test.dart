import 'package:admin_console/src/core/admin_console_models.dart';
import 'package:admin_console/src/core/admin_providers.dart';
import 'package:admin_console/src/features/common/admin_page_parts.dart';
import 'package:admin_console/src/features/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_ui/shared_ui.dart';

void main() {
  testWidgets('sidebar email uses single-line ellipsis', (tester) async {
    const longEmail =
        'very.long.admin.account.email.for.sidebar.testing@passagetr.dev';

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: AdminShellFrame(
            destination: AdminDestination.dashboard,
            title: 'Sidebar Test',
            subtitle: 'Email overflow',
            accessContext: AccessContext(
              session: const AuthSession(
                user: AuthUser(
                  id: 'admin-test',
                  email: longEmail,
                  isAnonymous: false,
                ),
                claims: <String, String>{'app_role': 'admin', 'plan': 'pro'},
              ),
              role: AppRole.admin,
              plan: EntitlementPlan.pro,
            ),
            body: const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final emailText = tester.widget<Text>(find.text(longEmail));
    expect(emailText.maxLines, 1);
    expect(emailText.overflow, TextOverflow.ellipsis);
  });

  testWidgets('settings page renders audit empty state copy', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminAuditFeedProvider.overrideWith(
            (ref) async => const AdminAuditFeed.empty(
              'Henuz audit kaydi olusmadi. Ilk yonetim islemi burada gorunecek.',
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AdminSettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Henuz audit kaydi yok'), findsOneWidget);
    expect(
      find.textContaining('Ilk yonetim islemi burada gorunecek'),
      findsOneWidget,
    );
  });
}
