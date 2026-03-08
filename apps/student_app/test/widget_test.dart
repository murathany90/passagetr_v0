import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/main.dart';

void main() {
  testWidgets('student foundation shell renders', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: StudentApp()));
    await tester.pumpAndSettle();

    expect(find.text('PASSAGETR Student App'), findsWidgets);
    expect(find.text('v2 foundation student shell'), findsOneWidget);
  });
}
