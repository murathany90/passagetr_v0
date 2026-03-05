import 'package:flutter_test/flutter_test.dart';
import 'package:passagetr/core/utils/text_normalizer.dart';

void main() {
  test('normalizeTypingAnswer should lowercase and collapse spaces', () {
    final String result = normalizeTypingAnswer('  AbC   Def  ');
    expect(result, 'abc def');
  });
}

