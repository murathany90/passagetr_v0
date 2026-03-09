import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:student_app/src/features/common/page_parts.dart';

void main() {
  Future<void> pumpShell(WidgetTester tester, {required Size size}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: StudentShellFrame(
          destination: StudentDestination.home,
          title: 'Responsive Test',
          subtitle: 'Layout behavior',
          accessContext: AccessContext.preview(
            role: AppRole.user,
            plan: EntitlementPlan.free,
            isAnonymous: true,
          ),
          body: const SizedBox(height: 120, child: Text('Body')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('uses bottom navigation on narrow layouts', (tester) async {
    await pumpShell(tester, size: const Size(390, 844));

    expect(find.text('Ana Sayfa'), findsOneWidget);
    expect(find.text(WorkspaceInfo.branchName), findsNothing);
  });

  testWidgets('uses sidebar rail on wide layouts', (tester) async {
    await pumpShell(tester, size: const Size(1280, 900));

    expect(find.text(WorkspaceInfo.branchName), findsOneWidget);
    expect(find.text('Ana Sayfa'), findsOneWidget);
  });
}
