import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_console/main.dart';

void main() {
  testWidgets('admin foundation shell renders', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AdminConsoleApp()));
    await tester.pumpAndSettle();

    expect(find.text('PASSAGETR Admin Console'), findsWidgets);
    expect(find.text('v2 foundation admin shell'), findsOneWidget);
  });
}
