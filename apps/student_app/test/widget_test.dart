import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/src/app/student_app.dart';
import 'package:student_app/src/app/student_router.dart';

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 20,
}) async {
  for (var index = 0; index < maxPumps; index++) {
    await tester.pump(const Duration(milliseconds: 150));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
}

Future<void> _navigateTo(
  WidgetTester tester,
  ProviderContainer container,
  String location,
  Finder finder,
) async {
  container.read(studentRouterProvider).go(location);
  await tester.pump();
  await _pumpUntilFound(tester, finder);
}

void main() {
  testWidgets('student foundation shell renders', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const StudentApp(),
      ),
    );
    await _pumpUntilFound(tester, find.textContaining('Hoş geldin, Ahmet!'));

    expect(find.textContaining('Hoş geldin, Ahmet!'), findsOneWidget);
    expect(find.textContaining('Gün'), findsWidgets);

    await _navigateTo(
      tester,
      container,
      '/words',
      find.text('Kelime Paketleri'),
    );
    expect(find.text('Kelime Paketleri'), findsOneWidget);
    expect(
      find.textContaining('Kelime havuzunda veya sözlükte ara'),
      findsOneWidget,
    );

    await _navigateTo(
      tester,
      container,
      '/profile',
      find.text('PASSAGETR PRO'),
    );
    expect(find.text('PASSAGETR PRO'), findsOneWidget);
    expect(find.text('UYGULAMA AYARLARI'), findsOneWidget);
    await tester.ensureVisible(find.text('Giriş Yap').first);
    expect(find.text('Giriş Yap'), findsOneWidget);
    await tester.tap(find.text('Giriş Yap').first);
    await _pumpUntilFound(tester, find.text('Hesap erişimi'));
    expect(find.text('Hesap erişimi'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
  });
}
