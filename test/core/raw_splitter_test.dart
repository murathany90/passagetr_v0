import 'package:flutter_test/flutter_test.dart';
import 'package:ingilizce_app1/core/utils/raw_splitter.dart';

void main() {
  group('parseRawList', () {
    test('splits with semicolon and trims', () {
      final List<String> result = parseRawList('  leave; desert ; ;keep ');
      expect(result, <String>['leave', 'desert', 'keep']);
    });

    test('returns empty for null or blank', () {
      expect(parseRawList(null), isEmpty);
      expect(parseRawList('   '), isEmpty);
    });
  });
}
