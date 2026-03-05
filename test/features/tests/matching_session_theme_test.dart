import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('matching session does not use hardcoded green colors', () {
    final String source = File(
      'lib/features/tests/matching_session_page.dart',
    ).readAsStringSync();

    expect(source.contains('Colors.green'), isFalse);
  });

  test('matching session uses theme color scheme for matched tint', () {
    final String source = File(
      'lib/features/tests/matching_session_page.dart',
    ).readAsStringSync();

    expect(source.contains('secondaryContainer'), isTrue);
    expect(source.contains('Theme.of(context)'), isTrue);
  });
}
