import 'package:flutter_test/flutter_test.dart';

import 'package:ingilizce_app1/core/utils/word_selection_utils.dart';

void main() {
  test('normalizeSelectedWord trims punctuation and lowercases', () {
    expect(normalizeSelectedWord(' "Technology," '), equals('technology'));
  });

  test('dictionary url builders generate expected urls', () {
    expect(
      buildCambridgeDictionaryUrl('Technology').toString(),
      equals('https://dictionary.cambridge.org/dictionary/english/technology'),
    );
    expect(
      buildDictionaryDotComUrl('remote-work').toString(),
      equals('https://www.dictionary.com/browse/remote-work'),
    );
  });
}
