import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';
import 'package:student_app/src/app/student_app.dart';
import 'package:student_app/src/app/student_router.dart';
import 'package:student_app/src/core/student_providers.dart';

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

Finder _titleFinder(String value) {
  return find.byWidgetPredicate(
    (widget) => widget is Title && widget.title == value,
    description: value,
  );
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
  testWidgets('student routes render unique content and browser titles', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const StudentApp(),
      ),
    );
    await _pumpUntilFound(tester, find.textContaining('Hoş geldin'));

    expect(find.textContaining('Hoş geldin'), findsOneWidget);
    expect(_titleFinder('PASSAGETR | Ana Sayfa'), findsWidgets);

    await _navigateTo(
      tester,
      container,
      '/words',
      find.text('Kelime Paketleri'),
    );
    expect(find.text('Kelime Paketleri'), findsOneWidget);
    expect(_titleFinder('PASSAGETR | Kelimeler'), findsWidgets);

    await _navigateTo(
      tester,
      container,
      '/readings',
      find.textContaining('Okuma'),
    );
    expect(find.textContaining('Okuma'), findsWidgets);
    expect(_titleFinder('PASSAGETR | Okuma Odasi'), findsWidgets);

    await _navigateTo(
      tester,
      container,
      '/grammar',
      find.textContaining('Gramer'),
    );
    expect(find.textContaining('Gramer'), findsWidgets);
    expect(_titleFinder('PASSAGETR | Gramer Konulari'), findsWidgets);

    await _navigateTo(tester, container, '/profile', find.text('Misafir Modu'));
    expect(find.text('Misafir Modu'), findsOneWidget);
    expect(find.text('Hesap erisimi'), findsOneWidget);
    expect(find.text('UYGULAMA AYARLARI'), findsOneWidget);
    expect(find.text('PASSAGETR PRO'), findsNothing);
    expect(find.text('Ahmet Yılmaz'), findsNothing);
    expect(find.text('ahmet.yilmaz@example.com'), findsNothing);
    expect(_titleFinder('PASSAGETR | Giriş'), findsWidgets);

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('auth_sign_in_button')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('auth_sign_in_button')));
    await tester.pumpAndSettle();
    expect(find.text('E-posta zorunlu.'), findsOneWidget);
    expect(find.text('Sifre zorunlu.'), findsOneWidget);

    container.read(studentAccessProvider.notifier).setAnonymous(false);
    await tester.pump();

    await _navigateTo(
      tester,
      container,
      '/profile',
      find.text('PASSAGETR PRO'),
    );
    expect(find.text('PASSAGETR PRO'), findsOneWidget);
    expect(find.text('Hesap erisimi'), findsNothing);
    expect(_titleFinder('PASSAGETR | Profil'), findsWidgets);

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('profile_settings_button')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('profile_settings_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profil Ayarları'), findsOneWidget);
    expect(find.text('HIZLI İŞLEMLER'), findsOneWidget);
    expect(find.text('Planı Gör'), findsWidgets);
    expect(find.text('Oturumu Yenile'), findsWidgets);
    expect(
      find.byKey(const ValueKey<String>('profile_display_name_field')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('profile_display_name_field')),
      'Ada Lovelace',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('profile_save_display_name_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ada Lovelace'), findsWidgets);

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('settings_manage_account_button')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('settings_manage_account_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hesap Yönetimi'), findsOneWidget);
    expect(find.text('Kullanıcı Adı'), findsOneWidget);
  });

  testWidgets('dev access route is locked for users and open for admins', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const StudentApp(),
      ),
    );
    await _pumpUntilFound(tester, find.textContaining('Hoş geldin'));

    await _navigateTo(
      tester,
      container,
      '/dev-access',
      find.textContaining('yalnızca admin veya developer'),
    );
    expect(
      find.textContaining('yalnızca admin veya developer'),
      findsOneWidget,
    );

    container.read(studentAccessProvider.notifier).setRole(AppRole.admin);
    await tester.pump();

    await _navigateTo(
      tester,
      container,
      '/dev-access',
      find.text('Geliştirici erişimi'),
    );
    expect(find.text('Geliştirici erişimi'), findsOneWidget);
    expect(find.text('DEV ACCESS PANEL'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
    expect(_titleFinder('PASSAGETR | Dev Access'), findsWidgets);
  });
}
